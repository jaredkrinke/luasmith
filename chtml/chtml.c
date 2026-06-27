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

void parse_value(state_t* state) {
	/* Three cases: no quotation, apostrophes, or quotation marks */
	class_t start = peek(state);
	switch (start) {
		case C_APOS:
		case C_QUOT:
			/* Look for matching apostrophe/quotation mark */
			state->c++;
			state->ctx.value = state->c;

			for (;;) {
				class_t next = peek(state);
				switch (next) {
					case C_APOS:
					case C_QUOT:
						if (next == start) {
							state->ctx.value_size = (size_t)(state->c - state->ctx.value);
							state->c++;
							flush(CHTML_EVENT_ATTRIBUTE, state);
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
			state->ctx.value = state->c;
			coalesce(C_TEXT, state);
			state->ctx.value_size = (size_t)(state->c - state->ctx.value);
			flush(CHTML_EVENT_ATTRIBUTE, state);
			return;

		default:
			/* TODO: Errors: SPACE, BROPEN, BRCLOSE, EQUAL, NULL */
			return;
	}
}

void parse_attribute(state_t *state) {
	switch (peek(state)) {
		case C_SPACE:
		case C_BRCLOSE:
			/* No equal sign */
			state->ctx.value = NULL;
			state->ctx.value_size = 0;
			flush(CHTML_EVENT_ATTRIBUTE, state);
			break;

		case C_EQUAL:
			state->c++;
			parse_value(state);
			break;

		default:
			/* TODO: Error: BROPEN, NULL, APOS, QUOT */
			return;
	}
}

void parse_tag(state_t* state) {
	state->c++;
	state->ctx.tag = state->c;
	state->ctx.tag_size = 0;
	state->ctx.attribute = NULL;
	state->ctx.attribute_size = 0;
	state->ctx.value = NULL;
	state->ctx.value_size = 0;

	coalesce(C_TEXT, state);
	state->ctx.tag_size = (size_t)(state->c - state->ctx.tag);
	flush(CHTML_EVENT_TAG_ENTER, state);

	for (;;) {
		coalesce(C_SPACE, state);

		switch (peek(state)) {
			case C_BRCLOSE:
				state->ctx.attribute = NULL;
				state->ctx.attribute_size = 0;
				state->ctx.value = NULL;
				state->ctx.value_size = 0;
				flush(CHTML_EVENT_OTHER, state);

				state->c++;
				flush(CHTML_EVENT_TAG_EXIT, state);
				return;

			case C_NULL:
				return;

			case C_TEXT:
				flush(CHTML_EVENT_OTHER, state);
				state->ctx.attribute = state->c;
				coalesce(C_TEXT, state);
				state->ctx.attribute_size = (size_t)(state->c - state->ctx.attribute);

				/* Check for XML-style self-closing tag */
				if (state->ctx.attribute_size == 1 && state->ctx.attribute[0] == '/') {
					state->ctx.attribute = NULL;
					state->ctx.attribute_size = 0;
					flush(CHTML_EVENT_OTHER, state);
				}
				else {
					parse_attribute(state);
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
				flush(CHTML_EVENT_OTHER, &state);
				parse_tag(&state);
				break;

			default:
				state.c++;
				break;
		}
	}

	flush(CHTML_EVENT_OTHER, &state);
}
