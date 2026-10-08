"""Run the installed sprite-gen engine against an explicit Images API gateway.

No credentials are accepted as arguments or read from project files. The engine
uses OPENAI_API_KEY from the process environment and owns the HTTP transport,
PNG validation, transparency cleanup, publication and generation reports.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path
from urllib.parse import urlsplit


def normalize_api_base(value: str) -> str:
    parsed = urlsplit(value)
    if (parsed.scheme != "https" or not parsed.hostname or parsed.username
            or parsed.password or parsed.query or parsed.fragment):
        raise ValueError("API base must be an HTTPS URL without credentials, query or fragment")
    path = parsed.path.rstrip("/")
    if path not in ("", "/v1"):
        raise ValueError("API base must be a gateway root or its /v1 base")
    return f"https://{parsed.netloc}/v1"


def configure_engine(root: Path, api_base: str):
    base = normalize_api_base(api_base)
    root = root.resolve()
    if not (root / "sprite_gen" / "gen" / "openai_provider.py").is_file():
        raise ValueError("sprite-gen root does not contain the OpenAI provider")
    sys.path.insert(0, str(root))
    from sprite_gen.gen import openai_provider
    if not Path(openai_provider.__file__).resolve().is_relative_to(root):
        raise ValueError("sprite-gen was already imported from a different installation")
    # Version 2.11 has no base-URL option. Change only the transport base of the
    # existing adapter in this process; never modify the installed skill.
    openai_provider.API_BASE = base
    return openai_provider


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sprite-gen-root", required=True, type=Path)
    parser.add_argument("--api-base", required=True)
    parser.add_argument("engine_args", nargs=argparse.REMAINDER)
    args = parser.parse_args(argv)
    forwarded = args.engine_args
    if forwarded and forwarded[0] == "--":
        forwarded = forwarded[1:]
    if not forwarded:
        parser.error("pass sprite-gen arguments after --")
    if forwarded[0] in ("gen", "gen-set", "anchor"):
        if "--provider" not in forwarded or forwarded[forwarded.index("--provider") + 1:] == []:
            parser.error("gateway generation requires explicit --provider openai")
        if forwarded[forwarded.index("--provider") + 1] != "openai":
            parser.error("gateway generation requires explicit --provider openai")
    try:
        configure_engine(args.sprite_gen_root, args.api_base)
    except ValueError as exc:
        parser.error(str(exc))
    from sprite_gen.cli import main as engine_main
    return engine_main(forwarded)


if __name__ == "__main__":
    raise SystemExit(main())
