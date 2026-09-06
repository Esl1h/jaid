module main

import os
import redact

fn main() {
	mut unit := ''
	mut since := '1h'
	mut offline := false
	mut show_payload := false
	mut markdown := false

	mut i := 1
	for i < os.args.len {
		arg := os.args[i]
		match arg {
			'--unit' {
				i++
				if i >= os.args.len {
					eprintln('--unit needs a value')
					exit(1)
				}
				unit = os.args[i]
			}
			'--since' {
				i++
				if i >= os.args.len {
					eprintln('--since needs a value')
					exit(1)
				}
				since = os.args[i]
			}
			'--offline' {
				offline = true
			}
			'--show-payload' {
				show_payload = true
			}
			'--markdown' {
				markdown = true
			}
			else {
				eprintln('unknown argument: ${arg}')
				exit(1)
			}
		}
		i++
	}

	if unit == '' {
		eprintln('usage: jaid --unit <name> [--since 1h] [--offline] [--show-payload] [--markdown]')
		exit(1)
	}

	status := collect_systemctl_status(unit)
	journal := collect_journal(unit, since) or {
		eprintln('error: ${err}')
		exit(1)
	}

	raw_context := build_prompt(unit, status, journal)
	redacted := redact.apply(raw_context)

	if redacted.findings.len > 0 {
		eprintln('jaid: redacted ${redacted.findings.len} finding(s) before sending')
	}
	if show_payload {
		eprintln('--- payload that would be sent ---')
		eprintln(redacted.text)
		eprintln('--- end payload ---')
	}

	if offline {
		return
	}

	diagnosis := diagnose(redacted.text) or {
		eprintln('error: ${err}')
		exit(1)
	}

	if markdown {
		println('## jaid diagnosis: ${unit}')
		println('')
		println(diagnosis)
	} else {
		println(diagnosis)
	}
}
