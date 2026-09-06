module main

fn test_journalctl_args_shape() {
	args := journalctl_args('nginx', '1h')
	assert args[0] == 'journalctl'
	assert '-u' in args
	assert 'nginx' in args
	assert '--since' in args
	assert '1h' in args
	assert '--no-pager' in args
}

fn test_journalctl_args_no_shell_metacharacters_needed() {
	// os.exec takes argv directly, so a unit name or since value that
	// would be dangerous to a shell (e.g. containing ";") just becomes
	// one literal argument, never interpreted.
	args := journalctl_args('nginx; rm -rf /', '1h')
	assert 'nginx; rm -rf /' in args
	assert args.len == 7
}

fn test_systemctl_status_args_shape() {
	args := systemctl_status_args('nginx')
	assert args[0] == 'systemctl'
	assert args[1] == 'status'
	assert 'nginx' in args
}
