# AGENTS.md

Instructions for coding agents working in this repository.

## What this project is

`jaid` is a V CLI: it collects a systemd unit's `journalctl` window and
`systemctl status`, redacts secrets locally via `redact`, sends the
redacted text to an LLM via `vai`, and prints back a diagnosis. Read-only
by design, it never runs anything beyond `journalctl`/`systemctl status`
itself, and its output is suggestions, not executed commands. This is the
flagship of the whole `vai`/`redact`/`ccstat`/`toklen`/`llmbench`/`jaid`
family: the one meant to justify months of work, at the intersection of
SRE work, LLMs, and V.

## V is under-represented in your training data, verify, never guess

Same standing rule as every other project in this family. Compile after
every meaningful change. `make build` (`v -o jaid .`) is the reliable
check here, see the `v test .` caveat below.

## The same sibling-directory V compiler bug as `toklen`/`llmbench`

**`v test .` fails here for the identical reason it fails in `toklen` and
`llmbench`**, fully diagnosed there: this repo's `v.mod` depends on `vai`
via VPM install, and a real checkout of `vai` (with its own `v.mod`)
happens to sit right next to this repo on disk. V's per-`_test.v`-file
compilation gets confused between the VPM-installed copy and the
sibling, and silently fails to resolve `vai.anthropic`/`vai.openai`
(submodule imports) while `import vai` itself keeps working fine.
`redact` is unaffected either way, it has no submodules, and its own
sibling directory doesn't trigger the same confusion (only `vai`'s
submodule imports do). Read `toklen`'s `AGENTS.md` for the full
reproduction; it isn't repeated here.

Practical fallout: `journal_test.v` and `ollama_test.v` are fine on their
own, but `v test .` pulls `diagnose.v` (which imports
`vai.anthropic`/`vai.openai`) into the same compilation unit and the
whole run fails. Verified correct by `make build` succeeding and a live
run against a real unit (`NetworkManager`, with an IPv4 address correctly
turning into `<IPV4_1>` in the payload), not by `v test .` passing.

**Do not** try to "fix" this by restructuring imports or merging files ,
see `toklen`/`llmbench` for why that doesn't change anything.

## Gotchas found in this codebase

- **`os.exec(args []string) Result` is not `os.execute(cmd string)`.**
  `exec` runs argv directly, no shell, so a unit name or `--since` value
  containing shell metacharacters is just one literal argument, never
  interpreted, confirmed by a test that passes `nginx; rm -rf /` as a
  unit name and checks it lands as a single untouched array element.
  `execute` goes through a shell and would have been a real injection
  risk here, since `--unit` and `--since` are user-supplied. Also note
  `exec` returns a plain `Result`, not `!Result`, no `or {}` needed or
  accepted; check `res.exit_code` directly, including its own `-1`
  sentinel for "couldn't even start the process."
- `journalctl --since` rejects a bare relative value (`1h`, `30m`) with
  `Failed to parse timestamp`; systemd.time(7) needs the leading minus
  (`-1h`) or the `1 hour ago` form. The default was `1h` for a while and
  every default invocation exited 1. Any change to the default must be
  run against the real `journalctl` (`jaid --unit <x> --offline`), not
  just through `journalctl_args` tests, which only check the argv shape.
- `journalctl` exits `0` and prints `-- No entries --` for a unit with
  nothing in the time window, including a unit that doesn't exist at
  all. An empty-looking journal is a normal result to report to the
  model, not a command failure to error out on.
- `systemctl status` exits non-zero for a stopped or failed unit, which
  is exactly the interesting case, not an error to swallow. Its output is
  collected either way.

## Design decisions worth knowing before changing scope

- **The journal window is capped (`--lines`, default 500, `journalctl -n`).**
  Without it, a chatty unit over `--since` blew past Ollama's default
  4096-token context, which truncates silently, so the model saw a random
  prefix of the logs. The cap is the newest N entries, which is what a
  triage wants.
- **Redaction runs on the fully-assembled prompt (status + journal
  together), once, right before it's used.** Nothing downstream of
  `redact.apply()` in `main.v` ever touches the unredacted strings again
 , `status` and `journal` themselves aren't passed to `diagnose()`,
  only `redacted.text` is. Keep it that way: redacting each piece
  separately would be easy to get wrong (miss a secret that only forms
  once the pieces are concatenated) for no benefit.
- **`--show-payload` and the "redacted N finding(s)" note both go to
  stderr, never stdout.** stdout is reserved for the diagnosis itself
  (or nothing, in `--offline` mode), so `jaid ... > diagnosis.md` doesn't
  pick up audit noise.
- **No retry, no streaming.** `diagnose()` is a single
  `Provider.complete()` call. This is a triage tool run interactively by
  a human, not a benchmark or a long-running service; `llmbench`'s
  streaming/retry complexity doesn't belong here without a real reason.
- **Anything `redact` misses gets fixed in `redact`, never here.** MAC
  addresses went to the model unmasked in the first live run against
  `NetworkManager` (ten of them in one payload); the fix was a
  `mac_address` rule in `redact`'s `patterns.v`, and jaid picked it up by
  re-syncing `~/.vmodules/redact`. IPv6 and hostnames still pass through.

## Build and test

```sh
make build   # v -o jaid .  , the real verification for this repo
make check   # fmt-check + vet + test, test step may fail, see above
make fmt     # v fmt -w .
```

## Do not

- Add execution of any command beyond `journalctl` and
  `systemctl status`. The entire trust model of this tool rests on it
  being read-only; adding a "just run this fix" mode is a different,
  much more dangerous tool.
- Use `os.execute()` (shell-interpreted) anywhere `--unit`/`--since` or
  any other user-supplied value reaches the command. `os.exec()` (argv,
  no shell) is the only safe choice here, see the gotcha above.
- Add `--explain`/`coredumpctl` support without being asked. Real,
  planned scope for this tool, deliberately not built yet, see the
  README's "What's not covered yet".
