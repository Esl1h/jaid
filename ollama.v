module main

import json2
import net.http

const ollama_base = 'http://localhost:11434'

// parse_first_model_name is split from the HTTP call so it's testable
// with a fixture. Every level is type-checked before converting: json2's
// as_array()/as_map() silently coerce instead of failing (a null becomes
// [null]), so a malformed response would otherwise land as an unrelated
// error deep inside the caller.
fn parse_first_model_name(body string) !string {
	val := json2.decode[json2.Any](body)!
	if val !is map[string]json2.Any {
		return error('expected a JSON object from Ollama')
	}
	obj := val.as_map()
	models_val := obj['models'] or { return error('no "models" field in Ollama response') }
	if models_val !is []json2.Any {
		return error('"models" must be an array')
	}
	models := models_val.as_array()
	if models.len == 0 {
		return error('Ollama has no models pulled (try: ollama pull llama3.2:1b)')
	}
	if models[0] !is map[string]json2.Any {
		return error('a model entry is not an object')
	}
	first := models[0].as_map()
	name_val := first['name'] or { return error('a model entry has no "name" field') }
	if name_val !is string {
		return error('a model entry "name" is not a string')
	}
	return name_val.str()
}

fn ollama_first_model() !string {
	resp := http.get('${ollama_base}/api/tags') or {
		return error('Ollama not reachable at ${ollama_base}: ${err}')
	}
	if resp.status_code != 200 {
		return error('Ollama returned HTTP ${resp.status_code}')
	}
	return parse_first_model_name(resp.body)
}
