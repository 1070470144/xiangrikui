#!/usr/bin/env python3
"""Validate and expand MM feature art manifests."""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Any


VALID_KINDS = {"background", "portrait", "illustration", "panel", "button", "icon", "bar", "decoration", "text"}
UI_KINDS = {"panel", "button", "icon", "bar", "decoration"}
PROJECT_EVIDENCE_KINDS = {
    "art_guide", "design_system", "runtime_screenshot", "runtime_asset", "accepted_manifest"
}
VALID_EVIDENCE_KINDS = PROJECT_EVIDENCE_KINDS | {"external_reference"}
ID_PATTERN = re.compile(r"^[a-z][a-z0-9_]*$")


def _generated_assets(manifest: dict[str, Any]) -> list[dict[str, Any]]:
    return [
        asset for asset in manifest.get("assets", [])
        if isinstance(asset, dict)
        and isinstance(asset.get("generation"), dict)
        and asset["generation"].get("enabled") is True
    ]


def load_manifest(path: Path | str) -> dict[str, Any]:
    with Path(path).open("r", encoding="utf-8") as handle:
        value = json.load(handle)
    if not isinstance(value, dict):
        raise ValueError("manifest root must be an object")
    return value


def resolve_project_path(value: str, project_root: Path) -> Path:
    if not value.startswith("res://"):
        raise ValueError(f"path must use res:// and remain inside project: {value}")
    root = project_root.resolve()
    result = (root / value.removeprefix("res://")).resolve()
    if result != root and root not in result.parents:
        raise ValueError(f"path escapes project: {value}")
    return result


def _expanded_outputs(asset: dict[str, Any]) -> list[tuple[str | None, str]]:
    output = asset.get("output", {})
    if "path" in output:
        return [(None, output["path"])]
    pattern = output.get("path_pattern", "")
    states = asset.get("states", [])
    return [(state, pattern.replace("{state}", state)) for state in states]


def validate_manifest(manifest: dict[str, Any], project_root: Path) -> list[str]:
    errors: list[str] = []
    required = ("schema_version", "feature", "scene", "root_node", "style", "assets")
    for field in required:
        if field not in manifest:
            errors.append(f"missing top-level field: {field}")
    if manifest.get("schema_version") != 1:
        errors.append("unsupported schema_version; expected 1")
    feature = manifest.get("feature")
    if not isinstance(feature, str) or not ID_PATTERN.fullmatch(feature):
        errors.append("feature must be lowercase snake_case")
    assets = manifest.get("assets", [])
    if not isinstance(assets, list):
        return errors + ["assets must be an array"]
    style = manifest.get("style", {})
    generated_assets = _generated_assets(manifest)
    if generated_assets and not isinstance(style, dict):
        errors.append("style must be an object when generation is enabled")
    elif generated_assets and (
        not isinstance(style.get("prompt_prefix"), str)
        or not style["prompt_prefix"].strip()
    ):
        errors.append("style.prompt_prefix must be a nonempty string when generation is enabled")
    strict_ui_contract = isinstance(style, dict) and any(
        field in style
        for field in (
            "evidence", "sprite_gen_contract", "visual_anchor",
            "comfort_constraints", "avoid",
        )
    )
    if generated_assets and strict_ui_contract:
        if not isinstance(style, dict):
            errors.append("style must be an object when generation is enabled")
        for field in ("prompt_prefix", "visual_anchor", "sprite_gen_contract"):
            if not isinstance(style, dict) or not isinstance(style.get(field), str) or not style[field].strip():
                errors.append(f"style.{field} must be a nonempty string when generation is enabled")
        evidence = style.get("evidence", []) if isinstance(style, dict) else []
        if not isinstance(evidence, list) or not evidence:
            errors.append("style.evidence requires at least one project evidence source")
        elif not any(
            isinstance(item, dict) and item.get("kind") in PROJECT_EVIDENCE_KINDS
            for item in evidence
        ):
            errors.append("style.evidence requires at least one project evidence source")
        if isinstance(evidence, list):
            for evidence_index, item in enumerate(evidence):
                evidence_prefix = f"style.evidence[{evidence_index}]"
                if not isinstance(item, dict):
                    errors.append(f"{evidence_prefix} must be an object")
                    continue
                source = item.get("source")
                reason = item.get("reason")
                kind = item.get("kind")
                if kind not in VALID_EVIDENCE_KINDS:
                    errors.append(f"{evidence_prefix}.kind is unsupported")
                if not isinstance(source, str) or not source.strip():
                    errors.append(f"{evidence_prefix}.source must be nonempty")
                if not isinstance(reason, str) or not reason.strip():
                    errors.append(f"{evidence_prefix}.reason must be nonempty")
                if item.get("kind") in PROJECT_EVIDENCE_KINDS and isinstance(source, str) and source.strip():
                    try:
                        evidence_path = resolve_project_path(source, project_root)
                    except ValueError as exc:
                        errors.append(f"{evidence_prefix}.source {exc}")
                    else:
                        if not evidence_path.exists():
                            errors.append(f"{evidence_prefix}.source does not exist: {source}")
        for field in ("comfort_constraints", "avoid"):
            value = style.get(field) if isinstance(style, dict) else None
            if not isinstance(value, list) or not value or not all(
                isinstance(item, str) and item.strip() for item in value
            ):
                errors.append(f"style.{field} must be a nonempty list when generation is enabled")
    seen_ids: set[str] = set()
    seen_outputs: set[str] = set()
    for index, asset in enumerate(assets):
        prefix = f"assets[{index}]"
        if not isinstance(asset, dict):
            errors.append(f"{prefix} must be an object")
            continue
        asset_id = asset.get("id")
        if not isinstance(asset_id, str) or not ID_PATTERN.fullmatch(asset_id):
            errors.append(f"{prefix}.id must be lowercase snake_case")
        elif asset_id in seen_ids:
            errors.append(f"duplicate asset id: {asset_id}")
        else:
            seen_ids.add(asset_id)
        if asset.get("kind") not in VALID_KINDS:
            errors.append(f"{prefix}.kind is unsupported")
        bindings = asset.get("bindings")
        if isinstance(bindings, list):
            for binding_index, binding in enumerate(bindings):
                if not isinstance(binding, dict):
                    continue
                scope = binding.get("scope", "scene")
                if scope not in {"scene", "component"}:
                    errors.append(f"{prefix}.bindings[{binding_index}].scope is unsupported")
        generation = asset.get("generation")
        if not isinstance(generation, dict) or not isinstance(generation.get("enabled"), bool):
            errors.append(f"{prefix}.generation.enabled must be boolean")
            continue
        if not generation["enabled"]:
            continue
        if not isinstance(asset.get("role"), str) or not asset["role"].strip():
            errors.append(f"{prefix}.role must be a nonempty string")
        if asset.get("kind") in UI_KINDS and strict_ui_contract:
            ui_spec = asset.get("ui_spec")
            if not isinstance(ui_spec, dict):
                errors.append(f"{prefix}.ui_spec is required for generated UI")
            else:
                for field in ("purpose", "layout"):
                    if not isinstance(ui_spec.get(field), str) or not ui_spec[field].strip():
                        errors.append(f"{prefix}.ui_spec missing {field}")
                negative = ui_spec.get("negative")
                if not isinstance(negative, list) or not negative or not all(
                    isinstance(item, str) and item.strip() for item in negative
                ):
                    errors.append(f"{prefix}.ui_spec.negative must be a nonempty list")
                states = asset.get("states", [])
                if isinstance(states, list) and len(states) > 1 and (
                    not isinstance(ui_spec.get("state_contract"), str)
                    or not ui_spec["state_contract"].strip()
                ):
                    errors.append(f"{prefix}.ui_spec missing state_contract for multiple states")
                display_size = ui_spec.get("display_size")
                valid_display = (
                    isinstance(display_size, list) and len(display_size) == 2
                    and all(isinstance(value, int) and not isinstance(value, bool) and value > 0 for value in display_size)
                )
                if not valid_display:
                    errors.append(f"{prefix}.ui_spec.display_size must contain two positive integers")
                safe_area = ui_spec.get("content_safe_area")
                valid_safe = (
                    isinstance(safe_area, list) and len(safe_area) == 4
                    and all(isinstance(value, int) and not isinstance(value, bool) and value >= 0 for value in safe_area)
                )
                if not valid_safe:
                    errors.append(f"{prefix}.ui_spec.content_safe_area must contain four nonnegative integers")
                elif valid_display:
                    left, top, right, bottom = safe_area
                    width, height = display_size
                    if left + right >= width or top + bottom >= height:
                        errors.append(f"{prefix}.ui_spec.content_safe_area must not consume the full display dimensions")
        if not isinstance(generation.get("prompt"), str) or not generation["prompt"].strip():
            errors.append(f"{prefix}.generation.prompt must be a nonempty string")
        if not isinstance(generation.get("transparent"), bool):
            errors.append(f"{prefix}.generation.transparent must be boolean")
        output = asset.get("output")
        if not isinstance(output, dict):
            errors.append(f"{prefix}.output is required for generated assets")
            continue
        size = output.get("size")
        if not (isinstance(size, list) and len(size) == 2 and all(isinstance(value, int) and not isinstance(value, bool) and value > 0 for value in size)):
            errors.append(f"{prefix}.output.size must contain two positive integers")
        content_margin = output.get("content_margin")
        if content_margin is not None and not (
            isinstance(content_margin, list)
            and len(content_margin) == 4
            and all(isinstance(value, int) and not isinstance(value, bool) and value >= 0 for value in content_margin)
        ):
            errors.append(f"{prefix}.output.content_margin must contain four nonnegative integers")
        states = asset.get("states", [])
        if not isinstance(states, list) or not all(isinstance(state, str) and state.strip() for state in states):
            errors.append(f"{prefix}.states must be a list of nonempty strings")
            states = []
        path = output.get("path")
        pattern = output.get("path_pattern")
        if "path_pattern" in output and (not isinstance(pattern, str) or not pattern.strip()):
            errors.append(f"{prefix}.output.path_pattern must be a nonempty string")
        if "path" in output and (not isinstance(path, str) or not path.strip()):
            errors.append(f"{prefix}.output.path must be a nonempty string")
        if "path_pattern" in output and isinstance(pattern, str) and "{state}" not in pattern:
            errors.append(f"{prefix}.output.path_pattern must contain {{state}}")
        if "path_pattern" in output and not states:
            errors.append(f"{prefix}.states are required for path_pattern")
        if "path" not in output and "path_pattern" not in output:
            errors.append(f"{prefix}.output requires path or path_pattern")
            continue
        if "path" in output and "path_pattern" in output:
            errors.append(f"{prefix}.output must use either path or path_pattern, not both")
            continue
        if not ((isinstance(path, str) and path.strip()) or (isinstance(pattern, str) and pattern.strip() and states)):
            continue
        for _, path in _expanded_outputs({**asset, "states": states}):
            try:
                resolved = resolve_project_path(path, project_root)
            except ValueError as exc:
                errors.append(str(exc))
                continue
            identity = str(resolved).casefold()
            if identity in seen_outputs:
                errors.append(f"duplicate output path: {path}")
            seen_outputs.add(identity)
    return errors


def compose_prompt(manifest: dict[str, Any], asset: dict[str, Any], state: str | None) -> str:
    style = manifest["style"]
    generation = asset["generation"]
    ui = asset.get("ui_spec")
    lines = [
        f"为 Godot 游戏生成一个可直接使用的{asset['kind']}图片资源。",
        f"资源功能：{asset['role']}。",
    ]
    if ui:
        lines.append(f"用途：{ui['purpose']}。")
        width, height = ui["display_size"]
        left, top, right, bottom = ui["content_safe_area"]
        lines.extend([
            f"游戏内实际显示尺寸：{width}x{height} 像素。",
            f"内容安全区：左 {left}px、上 {top}px、右 {right}px、下 {bottom}px。",
        ])
    lines.extend([
        f"项目风格：{style['prompt_prefix']}。",
        f"视觉锚点：{style['visual_anchor']}。",
        generation["prompt"].strip().rstrip("。") + "。",
    ])
    if ui:
        lines.append(f"布局：{ui['layout']}。")
        if ui.get("state_contract"):
            lines.append(f"状态一致性：{ui['state_contract']}。")
    if state is not None:
        lines.append(f"当前输出状态：{state}。")
    lines.append("舒适度约束：" + "；".join(style["comfort_constraints"]) + "。")
    forbidden = [*style["avoid"], *(ui.get("negative", []) if ui else [])]
    lines.append("不得生成：" + "、".join(dict.fromkeys(forbidden)) + "。")
    lines.append("禁止任何可读或伪造的文字、字母、数字、签名和水印；文字由 Godot 字体系统绘制。")
    if generation["transparent"]:
        lines.append("输出为真实透明 PNG；禁止棋盘格、白底、纯色背景和背景底板。")
    return "\n".join(lines)


def build_jobs(manifest: dict[str, Any], project_root: Path) -> list[dict[str, Any]]:
    errors = validate_manifest(manifest, project_root)
    if errors:
        raise ValueError("\n".join(errors))
    jobs: list[dict[str, Any]] = []
    for asset in manifest["assets"]:
        generation = asset["generation"]
        if not generation["enabled"]:
            continue
        for state, output in _expanded_outputs(asset):
            jobs.append({
                "asset_id": asset["id"],
                "state": state,
                "prompt": compose_prompt(manifest, asset, state),
                "output": output,
                "output_path": str(resolve_project_path(output, project_root)),
                "size": asset["output"]["size"],
                "transparent": generation["transparent"],
                "sprite_gen_contract": manifest["style"].get("sprite_gen_contract"),
                "style_evidence": manifest["style"].get("evidence", []),
                "ui_spec": asset.get("ui_spec"),
            })
    return jobs


def generate_jobs(
    manifest: dict[str, Any],
    project_root: Path,
    *,
    confirm: bool,
    runner=subprocess.run,
    sprite_gen_root: Path | None = None,
    api_base: str | None = None,
    python_executable: str | None = None,
) -> list[dict[str, Any]]:
    if not confirm:
        raise ValueError("generation requires explicit confirmation")
    if api_base is not None and sprite_gen_root is None:
        raise ValueError("gateway generation requires an explicit sprite_gen_root")
    if api_base is not None:
        from sprite_gen_gateway import normalize_api_base
        api_base = normalize_api_base(api_base)
    jobs = build_jobs(manifest, project_root)
    existing = [job["output_path"] for job in jobs if Path(job["output_path"]).exists()]
    if existing:
        raise FileExistsError("refusing to overwrite existing output: " + ", ".join(existing))
    for job in jobs:
        output = Path(job["output_path"])
        output.parent.mkdir(parents=True, exist_ok=True)
        report = output.with_suffix(".report.json")
        engine_root = sprite_gen_root or project_root / "sprite-gen"
        command = [python_executable or sys.executable]
        if api_base is not None:
            command.extend([
                str(Path(__file__).with_name("sprite_gen_gateway.py")),
                "--sprite-gen-root", str(engine_root), "--api-base", api_base, "--",
            ])
        else:
            command.extend(["-m", "sprite_gen.cli"])
        command.extend([
            "gen", "--provider", "openai" if api_base is not None else "mm-api",
            "--model", "gpt-image-2",
            "--prompt", job["prompt"],
            "--out", str(output),
            "--report", str(report),
        ])
        if api_base is not None:
            from math import gcd
            width, height = job["size"]
            divisor = gcd(width, height)
            command.extend(["--aspect-ratio", f"{width // divisor}:{height // divisor}"])
        if job["transparent"]:
            # mm-api supports native alpha; requesting chroma here can key out
            # the entire artwork because the provider does not paint a key field.
            command.extend(["--transparent", "--alpha-mode", "native"])
        config_path = project_root / "aiskill" / "mm-tools" / "config.json"
        env = os.environ.copy()
        if api_base is None:
            env["MM_API_CONFIG"] = str(config_path)
        result = runner(command, cwd=engine_root, env=env)
        if getattr(result, "returncode", 0) != 0:
            raise RuntimeError(f"sprite-gen failed for {job['asset_id']}")
        # Providers choose their native canvas size. Normalize to the explicit
        # manifest contract before verification and Godot import.
        if output.exists():
            from PIL import Image
            with Image.open(output) as image:
                if list(image.size) != job["size"]:
                    image = image.convert("RGBA" if job["transparent"] else "RGB")
                    image.resize(tuple(job["size"]), Image.Resampling.LANCZOS).save(output, format="PNG")
    return jobs


def verify_outputs(manifest: dict[str, Any], project_root: Path) -> list[str]:
    from PIL import Image

    errors: list[str] = []
    for job in build_jobs(manifest, project_root):
        path = Path(job["output_path"])
        if not path.exists():
            errors.append(f"missing output: {job['output']}")
            continue
        try:
            with Image.open(path) as image:
                if image.format != "PNG":
                    errors.append(f"output is not PNG: {job['output']}")
                if list(image.size) != job["size"]:
                    errors.append(f"wrong dimensions for {job['output']}: {image.size}, expected {tuple(job['size'])}")
                if job["transparent"] and "A" not in image.getbands():
                    errors.append(f"missing alpha channel: {job['output']}")
        except OSError as exc:
            errors.append(f"invalid image {job['output']}: {exc}")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("validate", "plan", "generate", "verify"))
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--confirm", action="store_true", help="confirm billable generation requests")
    parser.add_argument("--sprite-gen-root", type=Path, help="explicit sprite-gen installation root")
    parser.add_argument("--api-base", help="explicit HTTPS Images API gateway; uses openai provider")
    parser.add_argument("--sprite-gen-python", help="Python executable in that installation's venv")
    args = parser.parse_args(argv)
    project_root = Path.cwd()
    manifest = load_manifest(args.manifest)
    errors = validate_manifest(manifest, project_root)
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    if args.command == "plan":
        print(json.dumps(build_jobs(manifest, project_root), ensure_ascii=False, indent=2))
    elif args.command == "generate":
        generate_jobs(manifest, project_root, confirm=args.confirm,
                      sprite_gen_root=args.sprite_gen_root, api_base=args.api_base,
                      python_executable=args.sprite_gen_python)
        print(f"generated: {args.manifest}")
    elif args.command == "verify":
        verification_errors = verify_outputs(manifest, project_root)
        if verification_errors:
            print("\n".join(verification_errors), file=sys.stderr)
            return 1
        print(f"verified: {args.manifest}")
    else:
        print(f"valid: {args.manifest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
