module main

import os
import strings
import vai
import vai.anthropic
import vai.openai

const system_prompt = 'You are jaid, a read-only SRE triage assistant. You are given a ' + 'redacted systemd journal excerpt and unit status for one service. Diagnose what is ' + 'wrong, if anything, and suggest concrete next steps or commands an operator could ' + 'run. You never execute anything yourself and must never claim to have done so. If ' + 'the logs show nothing actionable, say so plainly instead of inventing a problem. Be ' + 'concise.'

// build_prompt assembles what actually goes to the model, after
// redaction has already run on it. It never sees raw log text.
fn build_prompt(unit string, status string, journal string) string {
	return 'Unit: ${unit}\n\n--- systemctl status ---\n${status}\n--- journal ---\n${journal}'
}

// diagnose sends the (already-redacted) prompt to Anthropic if
// ANTHROPIC_API_KEY is set, otherwise the first Ollama model found.
fn diagnose(prompt string) !string {
	anthropic_key := os.getenv('ANTHROPIC_API_KEY')
	if anthropic_key != '' {
		p := anthropic.Provider{
			api_key: anthropic_key
		}
		resp := p.complete(vai.Request{
			model: 'claude-sonnet-5'
			system: system_prompt
			messages: [vai.user(prompt)]
			max_tokens: 1024
		})!
		return extract_text(resp)
	}

	model := ollama_first_model() or {
		return error('${err}. Set ANTHROPIC_API_KEY, or run `ollama pull <model>` first')
	}
	p := openai.Provider{
		base_url: '${ollama_base}/v1'
	}
	resp := p.complete(vai.Request{
		model: model
		system: system_prompt
		messages: [vai.user(prompt)]
		max_tokens: 1024
	})!
	return extract_text(resp)
}

fn extract_text(resp vai.Response) string {
	mut sb := strings.new_builder(256)
	for c in resp.content {
		if c is vai.TextContent {
			sb.write_string(c.text)
		}
	}
	return sb.str()
}
