module main

import os

// journalctl_args builds the argv for collecting one unit's log window,
// split from execution so the exact command stays testable without a
// live systemd around. os.exec (not os.execute) runs it directly, no
// shell, so nothing in `unit` or `since` is ever shell-interpreted.
// -n caps the window at the newest `lines` entries: a chatty unit over an
// hour can exceed a local model's context (Ollama's default is 4096
// tokens and it truncates silently) or an API's request limit.
fn journalctl_args(unit string, since string, lines int) []string {
	return ['journalctl', '-u', unit, '--since', since, '-n', '${lines}', '-o', 'short-iso',
		'--no-pager']
}

fn systemctl_status_args(unit string) []string {
	return ['systemctl', 'status', unit, '--no-pager']
}

// collect_journal returns the unit's journal window. journalctl exits 0
// and prints "-- No entries --" for a unit with nothing in the window
// (even one that doesn't exist), so an empty-looking result is a normal
// outcome to report, not a command failure.
fn collect_journal(unit string, since string, lines int) !string {
	res := os.exec(journalctl_args(unit, since, lines))
	if res.exit_code != 0 {
		return error('journalctl exited ${res.exit_code}: ${res.output}')
	}
	return res.output
}

// collect_systemctl_status is best-effort: a failed or stopped unit makes
// systemctl exit non-zero, which is exactly the case worth showing the
// LLM, not an error to swallow. Any output collected is returned either
// way.
fn collect_systemctl_status(unit string) string {
	res := os.exec(systemctl_status_args(unit))
	return res.output
}
