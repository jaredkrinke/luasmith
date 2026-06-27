/* Note: a "tag" in the context of this library means "<...>", so "entering" a
 * tag means "<" and exiting a tag means ">". Most importantly, closing tags
 * are not distinguished by this library, so they are represented by entering a
 * tag like "/table" (note the "/") and then immediately exiting it. */

typedef enum {
	CHTML_EVENT_OTHER = 1,
	CHTML_EVENT_TAG_ENTER,
	CHTML_EVENT_TAG_EXIT,
	CHTML_EVENT_ATTRIBUTE,
} chtml_event_t;

typedef struct {
	void* user_data;
	const char* tag;
	size_t tag_size;
	const char* attribute;
	size_t attribute_size;
	const char* value;
	size_t value_size;
} chtml_context_t;

typedef void (*chtml_callback_t)(chtml_event_t event, const char* str, size_t size, const chtml_context_t* ctx);

extern void parse_html(const char* html, chtml_callback_t cb, void* user_data);

