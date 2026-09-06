# jaid

A [V](https://vlang.io) CLI: journalctl triage with an LLM. It collects a systemd unit's journal and status, redacts secrets locally before anything leaves the machine, sends the redacted text to an LLM, and prints back a diagnosis with suggested next steps. It never executes anything itself.

Built on [`vai`](https://github.com/Esl1h/vai) (the LLM client) and [`redact`](https://github.com/Esl1h/redact) (the redaction pipeline), this is mostly the glue between the two, plus `journalctl`/`systemctl`.

## Install

```sh
v install https://github.com/Esl1h/vai      # dependency
v install https://github.com/Esl1h/redact   # dependency
git clone https://github.com/Esl1h/jaid
cd jaid
make build
```

## Usage

```sh
jaid --unit nginx --since 1h
```

```sh
jaid --unit nginx --since 30m --show-payload   # audit exactly what would be sent
jaid --unit nginx --since 1h --offline         # redact and stop, never call the LLM
jaid --unit nginx --since 1h --markdown        # format the diagnosis for pasting into an incident
```

Picks Anthropic (`claude-sonnet-5`, if `ANTHROPIC_API_KEY` is set) or the first Ollama model found locally, same provider selection as `toklen` and `llmbench`.

## Why the redaction matters more than the prompt

Without it, this is a wrapper around `curl`. `jaid` runs everything collected from `journalctl`/`systemctl` through [`redact`](https://github.com/Esl1h/redact) before it's sent anywhere: known secret formats (AWS keys, GitHub/Slack tokens, JWTs, Bearer headers) are masked by regex, IPv4 addresses are masked too, the run above shows a real IP turning into `<IPV4_1>` before the LLM ever sees it. `--show-payload` prints the exact redacted text that would be sent (or was sent), so nothing about what leaves the machine is a black box.

`jaid` never runs a command itself, only journalctl/systemctl in read-only modes to gather context, and suggests, in its output, what a human might run next, it does not run those either.

## What's not covered yet

- MAC addresses aren't in `redact`'s pattern list, so they pass through unredacted (visible in the real example this tool was tested against). Worth adding to `redact` if this becomes a real concern, not something to patch around here.
- `--explain` (boot-failure analysis via `systemd-analyze`) and `coredumpctl` integration, both mentioned in this project's original design, aren't built. `--since` plus `journalctl`/`systemctl status` covers the common case; these are natural v2 additions once the basic flow has seen real use.
- No retry, no streaming: `diagnose()` is a single non-streaming `Provider.complete()` call. A triage tool doesn't need the complexity of `llmbench`'s streaming path.

## Development

```sh
make check   # fmt-check + vet + test
make test
make fmt
```

`v test .` can fail here with confusing `unknown type vai.anthropic.Provider` errors if a checkout of `vai` happens to sit next to this repo, a real, reproduced V compiler bug, not a code problem. See `toklen`'s AGENTS.md for the full diagnosis. `make build` plus a manual run is the reliable check.

## License

MIT
