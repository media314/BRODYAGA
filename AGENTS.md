# Repository guidance

This repository packages Open WebUI, Ollama, Qwen and Kimi Code configuration.

## Validate changes

Run `make test` after editing shell scripts, Compose files or documentation. The
test performs Bash syntax checks, optional ShellCheck, Compose rendering and a
basic secret scan. With services running, use `./scripts/smoke-test.sh` for the
OpenAI-compatible endpoint.

## Safety

- Keep network bindings on `127.0.0.1` by default.
- Never commit `.env`, `.runtime/`, API keys or generated user data.
- Preserve Docker volumes unless the user explicitly requests data deletion.
- Keep Kimi Code permission mode set to `manual` in shipped examples.
- Prefer pinned container versions and document upstream references when updating.

## Style

- Shell scripts target Bash and use `set -Eeuo pipefail` where failure is fatal.
- Documentation is primarily Russian, with exact commands and upstream links.
- Keep the CPU, NVIDIA and native-Ollama launch paths working independently.
