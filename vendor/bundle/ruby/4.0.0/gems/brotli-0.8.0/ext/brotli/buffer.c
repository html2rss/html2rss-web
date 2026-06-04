#include "buffer.h"
#include "ruby/ruby.h"

#include <stdint.h>
#include <string.h>

#define BUFFER_INITIAL_SIZE 1024

buffer_t*
create_buffer(size_t initial)
{
    buffer_t *buffer = ruby_xmalloc(sizeof(*buffer));
    buffer->used = 0;
    buffer->size = initial > 0 ? initial : BUFFER_INITIAL_SIZE;
    buffer->ptr = ruby_xmalloc(buffer->size);
    return buffer;
}

void
delete_buffer(buffer_t* buffer)
{
    if (!buffer) {
        return;
    }

    ruby_xfree(buffer->ptr);
    ruby_xfree(buffer);
}

static size_t
buffer_size_for(size_t current, size_t required)
{
    size_t size = current > 0 ? current : BUFFER_INITIAL_SIZE;

    while (size < required) {
        if (size > SIZE_MAX / 2) {
            return required;
        }
        size *= 2;
    }

    return size;
}

static void
expand_buffer(buffer_t* buffer, size_t required)
{
    buffer->size = buffer_size_for(buffer->size, required);
    buffer->ptr = ruby_xrealloc(buffer->ptr, buffer->size);
}

void
append_buffer(buffer_t* buffer, const void* ptr, size_t size)
{
    size_t required;

    if (size == 0) {
        return;
    }

    required = buffer->used + size;
    if (required > buffer->size) {
        expand_buffer(buffer, required);
    }

    memcpy(buffer->ptr + buffer->used, ptr, size);
    buffer->used += size;
}
