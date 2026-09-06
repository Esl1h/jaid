module main

fn test_parse_first_model_name() {
	body := '{"models":[{"name":"llama3.2:1b","model":"llama3.2:1b","size":1321098329}]}'
	name := parse_first_model_name(body) or {
		assert false, err.msg()
		return
	}
	assert name == 'llama3.2:1b'
}

fn test_parse_first_model_name_empty_list() {
	if _ := parse_first_model_name('{"models":[]}') {
		assert false, 'expected an error'
	}
}
