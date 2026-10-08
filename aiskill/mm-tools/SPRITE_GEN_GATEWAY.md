# Installed sprite-gen and an Images API gateway

The legacy project uses a bundled `mm-api` provider. Installed sprite-gen 2.11
supports `openai` instead and hardcodes its API base. `sprite_gen_gateway.py`
changes that base only in the current process, then invokes the actual sprite-gen
CLI. All HTTP encoding, native alpha processing and verified PNG publication
remain owned by sprite-gen. The installed skill files are not changed.

Use the installed skill's virtual-environment Python. Provide `OPENAI_API_KEY` in
the process environment, never in command arguments or tracked project files.

```powershell
& "$skillRoot/.venv/Scripts/python.exe" aiskill/mm-tools/sprite_gen_gateway.py `
  --sprite-gen-root $skillRoot --api-base https://newapi.oairegbox.cc/ -- `
  gen --provider openai --model gpt-image-2 --prompt-file $promptFile `
  --out $output --report $report --transparent --alpha-mode native
```

Manifest generation also accepts `--sprite-gen-root`, `--sprite-gen-python` and
`--api-base`. Supplying an API base selects explicit `openai`; leaving it out
preserves the legacy `mm-api` behavior. Existing outputs are still protected.

Only HTTPS gateway roots and `/v1` bases are accepted; URL credentials, query
parameters and fragments are rejected. Failed requests are never retried or
redirected to a different provider by this wrapper.

Offline checks in `tests/test_sprite_gen_gateway.py` intercept the engine's
transport and verify the exact endpoint, model, alpha mode and manifest command
without calling an API or using a real credential.
