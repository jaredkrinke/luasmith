#include <stddef.h>
#include "chtml.h"

/* Character classifier */
typedef enum {
	C_SPACE = 1,
	C_BROPEN,
	C_BRCLOSE,
	C_EQUAL,
	C_APOS,
	C_QUOT,
	C_NULL,
	C_TEXT,
} class_t;

class_t classify_character(char c) {
	switch (c) {
		case ' ':
		case '\t':
		case '\r':
		case '\n':
			return C_SPACE;
			break;

		case '<': return C_BROPEN; break;
		case '>': return C_BRCLOSE; break;
		case '=': return C_EQUAL; break;
		case '\'': return C_APOS; break;
		case '"': return C_QUOT; break;
		case '\0': return C_NULL; break;

		default: return C_TEXT; break;
	}
}

/* Parser */
typedef struct {
	chtml_callback_t cb;
	chtml_context_t ctx;
	const char* start;
	const char* c;
} state_t;

class_t peek(state_t* state) {
	return classify_character(*state->c);
}

void coalesce(class_t prev, state_t* state) {
	while (peek(state) == prev) {
		state->c++;
	}
}

void flush(chtml_event_t event, state_t* state) {
	if (state->c > state->start) {
		state->cb(event, state->start, (size_t)(state->c - state->start), &state->ctx);
		state->start = state->c;
	}
}

void flush_other(state_t* state) {
	flush(CHTML_EVENT_OTHER, state);
}

void flush_tag_enter(state_t* state) {
	flush(CHTML_EVENT_TAG_ENTER, state);
}

void flush_tag_exit(state_t* state) {
	flush(CHTML_EVENT_TAG_EXIT, state);
}

void flush_attribute(state_t* state, const char* attribute, size_t attribute_size, const char* value, size_t value_size) {
	state->ctx.attribute = attribute;
	state->ctx.attribute_size = attribute_size;
	state->ctx.value = value;
	state->ctx.value_size = value_size;
	flush(CHTML_EVENT_ATTRIBUTE, state);
	state->ctx.attribute = NULL;
	state->ctx.attribute_size = 0;
	state->ctx.value = NULL;
	state->ctx.value_size = 0;
}

void parse_value(state_t* state, const char* attribute, size_t attribute_size) {
	const char* value = NULL;
	size_t value_size = 0;

	/* Three cases: no quotation, apostrophes, or quotation marks */
	class_t start = peek(state);
	switch (start) {
		case C_APOS:
		case C_QUOT:
			/* Look for matching apostrophe/quotation mark */
			state->c++;
			value = state->c;

			for (;;) {
				class_t next = peek(state);
				switch (next) {
					case C_APOS:
					case C_QUOT:
						if (next == start) {
							value_size = (size_t)(state->c - value);
							state->c++;
							flush_attribute(state, attribute, attribute_size, value, value_size);
							return;
						}
						else {
							state->c++;
						}
						break;

					case C_SPACE:
					case C_EQUAL:
					case C_TEXT:
						state->c++;
						break;

					default:
						/* TODO: Errors: BROPEN, BRCLOSE, NULL */
						return;
				}
			}
			break;

		case C_TEXT:
			/* No quotation */
			value = state->c;
			coalesce(C_TEXT, state);
			flush_attribute(state, attribute, attribute_size, value, (size_t)(state->c - value));
			return;

		default:
			/* TODO: Errors: SPACE, BROPEN, BRCLOSE, EQUAL, NULL */
			return;
	}
}

void parse_attribute(state_t *state, const char* attribute, size_t attribute_size) {
	switch (peek(state)) {
		case C_SPACE:
		case C_BRCLOSE:
			/* No equal sign */
			flush_attribute(state, attribute, attribute_size, NULL, 0);
			break;

		case C_EQUAL:
			state->c++;
			parse_value(state, attribute, attribute_size);
			break;

		default:
			/* TODO: Error: BROPEN, NULL, APOS, QUOT */
			return;
	}
}

void parse_tag(state_t* state) {
	const char* attribute = NULL;
	size_t attribute_size = 0;

	state->c++;
	state->ctx.tag = state->c;
	state->ctx.tag_size = 0;

	coalesce(C_TEXT, state);
	state->ctx.tag_size = (size_t)(state->c - state->ctx.tag);
	flush_tag_enter(state);

	for (;;) {
		coalesce(C_SPACE, state);

		switch (peek(state)) {
			case C_BRCLOSE:
				flush_other(state);

				state->c++;
				flush_tag_exit(state);
				return;

			case C_NULL:
				return;

			case C_TEXT:
				flush_other(state);
				attribute = state->c;
				coalesce(C_TEXT, state);
				attribute_size = (size_t)(state->c - attribute);

				/* Check for XML-style self-closing tag */
				if (attribute_size == 1 && attribute[0] == '/') {
					flush_other(state);
				}
				else {
					parse_attribute(state, attribute, attribute_size);
				}
				break;

			default:
				/* TODO: Errors: BROPEN, EQUAL, APOS, QUOT */
				return;
		}
	}
}

void parse_html(const char* html, chtml_callback_t cb, void* user_data) {
	state_t state = {
		cb,
		{
			user_data,
			NULL, 0,
			NULL, 0,
			NULL, 0
		},
		html,
		html
	};

	class_t next = C_NULL;
	
	while ((next = peek(&state)) != C_NULL) {
		switch (next) {
			case C_BROPEN:
				flush_other(&state);
				parse_tag(&state);
				break;

			default:
				state.c++;
				break;
		}
	}

	flush_other(&state);
}
