#include "brotli.h"

static VALUE rb_eBrotli;
static ID id_cmp;
static ID id_dictionary;
static ID id_font;
static ID id_generic;
static ID id_lgblock;
static ID id_lgwin;
static ID id_mode;
static ID id_output_buffer_limit;
static ID id_quality;
static ID id_read;
static ID id_text;

static inline void*
brotli_alloc(void* opaque, size_t size)
{
    (void)opaque;
    return ruby_xmalloc(size);
}

static inline void
brotli_free(void* opaque, void* address)
{
    (void)opaque;
    ruby_xfree(address);
}

static VALUE
brotli_hash_lookup(VALUE hash, ID key)
{
    if (NIL_P(hash)) {
        return Qnil;
    }

    Check_Type(hash, T_HASH);
    return rb_hash_lookup(hash, ID2SYM(key));
}

static BrotliEncoderState*
brotli_encoder_state_create(void)
{
    BrotliEncoderState* state = BrotliEncoderCreateInstance(brotli_alloc, brotli_free, NULL);

    if (!state) {
        rb_raise(rb_eNoMemError, "BrotliEncoderCreateInstance failed");
    }

    return state;
}

static BrotliDecoderState*
brotli_decoder_state_create(void)
{
    BrotliDecoderState* state = BrotliDecoderCreateInstance(brotli_alloc, brotli_free, NULL);

    if (!state) {
        rb_raise(rb_eNoMemError, "BrotliDecoderCreateInstance failed");
    }

    return state;
}

/*******************************************************************************
 * inflate
 ******************************************************************************/

typedef struct {
    uint8_t* str;
    size_t len;
    BrotliDecoderState* s;
    buffer_t* buffer;
    BrotliDecoderResult r;
    uint8_t* dict;
    size_t dict_len;
} brotli_inflate_args_t;

static void
brotli_inflate_cleanup(brotli_inflate_args_t* args)
{
    delete_buffer(args->buffer);
    args->buffer = NULL;
    if (args->s) {
        BrotliDecoderDestroyInstance(args->s);
        args->s = NULL;
    }
}

static void*
brotli_inflate_no_gvl(void *arg)
{
    brotli_inflate_args_t *args = (brotli_inflate_args_t*)arg;
    uint8_t         output[BUFSIZ];
    BrotliDecoderResult  r = BROTLI_DECODER_RESULT_ERROR;
    size_t    available_in = args->len;
    const uint8_t* next_in = args->str;
    size_t   available_out = BUFSIZ;
    uint8_t*      next_out = output;
    size_t       total_out = 0;
    buffer_t*       buffer = args->buffer;
    BrotliDecoderState*  s = args->s;

#ifdef HAVE_BROTLIDECODERATTACHDICTIONARY
    /* Attach dictionary if provided */
    if (args->dict && args->dict_len > 0) {
        BrotliDecoderAttachDictionary(s, BROTLI_SHARED_DICTIONARY_RAW,
                                      args->dict_len, args->dict);
    }
#endif

    for (;;) {
        r = BrotliDecoderDecompressStream(s,
                                          &available_in, &next_in,
                                          &available_out, &next_out,
                                          &total_out);
        /* success, error or needs more input */
        if (r != BROTLI_DECODER_RESULT_NEEDS_MORE_OUTPUT) {
            break;
        }
        append_buffer(buffer, output, BUFSIZ);
        available_out = BUFSIZ;
        next_out = output;
    }

    if (r == BROTLI_DECODER_RESULT_SUCCESS) {
        if (next_out != output) {
            append_buffer(buffer, output, next_out - output);
        }
    }
    args->r = r;

    return arg;
}

static VALUE
brotli_inflate(int argc, VALUE *argv, VALUE self)
{
    VALUE str = Qnil;
    VALUE opts = Qnil;
    VALUE value = Qnil;
    VALUE dict = Qnil;
    const char *error = NULL;
    brotli_inflate_args_t args;

    (void)self;

    rb_scan_args(argc, argv, "11", &str, &opts);

    if (rb_respond_to(str, id_read)) {
        str = rb_funcall(str, id_read, 0);
    }

    StringValue(str);
    dict = brotli_hash_lookup(opts, id_dictionary);

    args.str = (uint8_t*)RSTRING_PTR(str);
    args.len = (size_t)RSTRING_LEN(str);
    args.s = brotli_decoder_state_create();
    args.buffer = create_buffer(BUFSIZ);
    args.r = BROTLI_DECODER_RESULT_ERROR;

    if (!NIL_P(dict)) {
#ifdef HAVE_BROTLIDECODERATTACHDICTIONARY
        StringValue(dict);
        args.dict = (uint8_t*)RSTRING_PTR(dict);
        args.dict_len = (size_t)RSTRING_LEN(dict);
#else
        rb_raise(rb_eBrotli, "Dictionary support not available in this build");
#endif
    } else {
        args.dict = NULL;
        args.dict_len = 0;
    }

#ifdef HAVE_RUBY_THREAD_H
    rb_thread_call_without_gvl(brotli_inflate_no_gvl, &args, NULL, NULL);
#else
    brotli_inflate_no_gvl(&args);
#endif
    RB_GC_GUARD(str);
    RB_GC_GUARD(dict);

    if (args.r == BROTLI_DECODER_RESULT_SUCCESS) {
        value = rb_str_new(args.buffer->ptr, args.buffer->used);
    } else if (args.r == BROTLI_DECODER_RESULT_ERROR) {
        error = BrotliDecoderErrorString(BrotliDecoderGetErrorCode(args.s));
    } else if (args.r == BROTLI_DECODER_RESULT_NEEDS_MORE_INPUT) {
        error = "Needs more input";
    } else {
        error = "Needs more output";
    }

    brotli_inflate_cleanup(&args);

    if (error) {
        rb_raise(rb_eBrotli, "%s", error);
    }

    return value;
}

/*******************************************************************************
 * deflate
 ******************************************************************************/

static void
brotli_deflate_set_mode(BrotliEncoderState* s, VALUE value)
{
    if (NIL_P(value)) {
        return;
    }

    if (value == ID2SYM(id_generic)) {
        BrotliEncoderSetParameter(s, BROTLI_PARAM_MODE, BROTLI_MODE_GENERIC);
    } else if (value == ID2SYM(id_text)) {
        BrotliEncoderSetParameter(s, BROTLI_PARAM_MODE, BROTLI_MODE_TEXT);
    } else if (value == ID2SYM(id_font)) {
        BrotliEncoderSetParameter(s, BROTLI_PARAM_MODE, BROTLI_MODE_FONT);
    } else {
        rb_raise(rb_eArgError, "invalid mode");
    }
}

static void
brotli_deflate_set_quality(BrotliEncoderState* s, VALUE value)
{
    int32_t param;

    if (NIL_P(value)) {
        return;
    }

    param = NUM2INT(value);
    if (0 <= param && param <= 11) {
        BrotliEncoderSetParameter(s, BROTLI_PARAM_QUALITY, param);
    } else {
        rb_raise(rb_eArgError, "invalid quality value. Should be 0 to 11.");
    }
}

static void
brotli_deflate_set_lgwin(BrotliEncoderState* s, VALUE value)
{
    int32_t param;

    if (NIL_P(value)) {
        return;
    }

    param = NUM2INT(value);
    if (10 <= param && param <= 24) {
        BrotliEncoderSetParameter(s, BROTLI_PARAM_LGWIN, param);
    } else {
        rb_raise(rb_eArgError, "invalid lgwin value. Should be 10 to 24.");
    }
}

static void
brotli_deflate_set_lgblock(BrotliEncoderState* s, VALUE value)
{
    int32_t param;

    if (NIL_P(value)) {
        return;
    }

    param = NUM2INT(value);
    if (param == 0 || (16 <= param && param <= 24)) {
        BrotliEncoderSetParameter(s, BROTLI_PARAM_LGBLOCK, param);
    } else {
        rb_raise(rb_eArgError, "invalid lgblock value. Should be 0 or 16 to 24.");
    }
}

static void
brotli_deflate_parse_options(BrotliEncoderState* s, VALUE opts)
{
    brotli_deflate_set_mode(s, brotli_hash_lookup(opts, id_mode));
    brotli_deflate_set_quality(s, brotli_hash_lookup(opts, id_quality));
    brotli_deflate_set_lgwin(s, brotli_hash_lookup(opts, id_lgwin));
    brotli_deflate_set_lgblock(s, brotli_hash_lookup(opts, id_lgblock));
}

typedef struct {
    uint8_t *str;
    size_t len;
    BrotliEncoderState* s;
    buffer_t* buffer;
    BROTLI_BOOL finished;
#if defined(HAVE_BROTLIENCODERPREPAREDICTIONARY) && defined(HAVE_BROTLIENCODERATTACHPREPAREDDICTIONARY)
    BrotliEncoderPreparedDictionary* prepared_dict;
#endif
} brotli_deflate_args_t;

static void
brotli_deflate_cleanup(brotli_deflate_args_t* args)
{
    delete_buffer(args->buffer);
    args->buffer = NULL;
    if (args->s) {
        BrotliEncoderDestroyInstance(args->s);
        args->s = NULL;
    }
#if defined(HAVE_BROTLIENCODERPREPAREDICTIONARY) && defined(HAVE_BROTLIENCODERATTACHPREPAREDDICTIONARY)
    if (args->prepared_dict) {
        BrotliEncoderDestroyPreparedDictionary(args->prepared_dict);
        args->prepared_dict = NULL;
    }
#endif
}

static void*
brotli_deflate_no_gvl(void *arg)
{
    brotli_deflate_args_t *args = (brotli_deflate_args_t *)arg;
    uint8_t         output[BUFSIZ];
    BROTLI_BOOL          r = BROTLI_FALSE;
    size_t    available_in = args->len;
    const uint8_t* next_in = args->str;
    size_t   available_out = BUFSIZ;
    uint8_t*      next_out = output;
    size_t       total_out = 0;
    buffer_t*       buffer = args->buffer;
    BrotliEncoderState*  s = args->s;

    for (;;) {
        r = BrotliEncoderCompressStream(s,
                                        BROTLI_OPERATION_FINISH,
                                        &available_in, &next_in,
                                        &available_out, &next_out, &total_out);
        if (r == BROTLI_FALSE) {
            args->finished = BROTLI_FALSE;
            break;
        } else {
            append_buffer(buffer, output, next_out - output);
            available_out = BUFSIZ;
            next_out = output;

            if (BrotliEncoderIsFinished(args->s)) {
                args->finished = BROTLI_TRUE;
                break;
            }
        }
    }

    return arg;
}

static VALUE
brotli_deflate(int argc, VALUE *argv, VALUE self)
{
    VALUE str = Qnil;
    VALUE opts = Qnil;
    VALUE value = Qnil;
    VALUE dict = Qnil;
    brotli_deflate_args_t args;
    size_t max_compressed_size;

    (void)self;

    rb_scan_args(argc, argv, "11", &str, &opts);
    if (NIL_P(str)) {
        rb_raise(rb_eArgError, "input should not be nil");
    }
    StringValue(str);
    dict = brotli_hash_lookup(opts, id_dictionary);

    args.str = (uint8_t*)RSTRING_PTR(str);
    args.len = (size_t)RSTRING_LEN(str);
    args.s = brotli_encoder_state_create();
    brotli_deflate_parse_options(args.s, opts);
    max_compressed_size = BrotliEncoderMaxCompressedSize(args.len);
    args.buffer = create_buffer(max_compressed_size);
    args.finished = BROTLI_FALSE;

#if defined(HAVE_BROTLIENCODERPREPAREDICTIONARY) && defined(HAVE_BROTLIENCODERATTACHPREPAREDDICTIONARY)
    args.prepared_dict = NULL;
#endif
    if (!NIL_P(dict)) {
#if defined(HAVE_BROTLIENCODERPREPAREDICTIONARY) && defined(HAVE_BROTLIENCODERATTACHPREPAREDDICTIONARY)
        StringValue(dict);
        args.prepared_dict = BrotliEncoderPrepareDictionary(
            BROTLI_SHARED_DICTIONARY_RAW,
            (size_t)RSTRING_LEN(dict),
            (const uint8_t*)RSTRING_PTR(dict),
            BROTLI_MAX_QUALITY,
            brotli_alloc,
            brotli_free,
            NULL);
        if (!args.prepared_dict) {
            brotli_deflate_cleanup(&args);
            rb_raise(rb_eBrotli, "Failed to prepare dictionary for compression");
        }
        if (!BrotliEncoderAttachPreparedDictionary(args.s, args.prepared_dict)) {
            brotli_deflate_cleanup(&args);
            rb_raise(rb_eBrotli, "Failed to attach dictionary for compression");
        }
#else
        brotli_deflate_cleanup(&args);
        rb_raise(rb_eBrotli, "Dictionary support not available in this build");
#endif
    }

#ifdef HAVE_RUBY_THREAD_H
    rb_thread_call_without_gvl(brotli_deflate_no_gvl, &args, NULL, NULL);
#else
    brotli_deflate_no_gvl(&args);
#endif
    RB_GC_GUARD(str);
    RB_GC_GUARD(dict);
    if (args.finished == BROTLI_TRUE) {
        value = rb_str_new(args.buffer->ptr, args.buffer->used);
    }

    brotli_deflate_cleanup(&args);

    if (args.finished != BROTLI_TRUE) {
        rb_raise(rb_eBrotli, "Failed to compress");
    }

    return value;
}

/*******************************************************************************
 * version
 ******************************************************************************/

static VALUE brotli_version(VALUE klass) {
    uint32_t ver = BrotliEncoderVersion();
    char version[255];

    (void)klass;
    snprintf(version, sizeof(version), "%u.%u.%u", ver >> 24, (ver >> 12) & 0xFFF, ver & 0xFFF);
    return rb_str_new2(version);
}

/*******************************************************************************
 * Streaming APIs
 ******************************************************************************/

static VALUE rb_cBrotliCompressor;
static VALUE rb_cBrotliDecompressor;

static uint8_t*
brotli_copy_string_data(VALUE string, size_t* len)
{
    size_t copy_len;
    size_t alloc_len;
    uint8_t* copy;

    StringValue(string);
    copy_len = (size_t)RSTRING_LEN(string);
    alloc_len = copy_len > 0 ? copy_len : 1;
    copy = brotli_alloc(NULL, alloc_len);
    if (copy_len > 0) {
        memcpy(copy, RSTRING_PTR(string), copy_len);
    }
    *len = copy_len;
    return copy;
}

typedef struct {
    BrotliEncoderState* state;
#if defined(HAVE_BROTLIENCODERPREPAREDICTIONARY) && defined(HAVE_BROTLIENCODERATTACHPREPAREDDICTIONARY)
    BrotliEncoderPreparedDictionary* prepared_dict;
#endif
    uint8_t* dict_data;
    size_t dict_len;
    BROTLI_BOOL finished;
} brotli_encoder_t;

typedef struct {
    brotli_encoder_t encoder;
} brotli_compressor_t;

typedef struct {
    BrotliDecoderState* state;
    uint8_t* dict_data;
    size_t dict_len;
    VALUE pending_input;
    BROTLI_BOOL needs_more_output;
    BROTLI_BOOL finished;
} brotli_decompressor_t;

typedef struct {
    BrotliEncoderState* state;
    BrotliEncoderOperation op;
    size_t available_in;
    const uint8_t* next_in;
    BROTLI_BOOL ok;
} brotli_encoder_args_t;

typedef struct {
    BrotliDecoderState* state;
    size_t available_in;
    const uint8_t* next_in;
    size_t available_out;
    uint8_t* next_out;
    BrotliDecoderResult result;
} brotli_decoder_args_t;

static void* compress_no_gvl(void *ptr) {
    brotli_encoder_args_t *args = ptr;
    size_t zero = 0;
    args->ok = BrotliEncoderCompressStream(args->state, args->op,
                                           &args->available_in, &args->next_in,
                                           &zero, NULL, NULL);
    return NULL;
}

static void* decompress_no_gvl(void *ptr) {
    brotli_decoder_args_t *args = ptr;
    args->result = BrotliDecoderDecompressStream(args->state,
                                                 &args->available_in,
                                                 &args->next_in,
                                                 &args->available_out,
                                                 &args->next_out,
                                                 NULL);
    return NULL;
}

static void
brotli_encoder_step(brotli_encoder_args_t *args)
{
#ifdef HAVE_RUBY_THREAD_H
    rb_thread_call_without_gvl(compress_no_gvl, (void*)args, NULL, NULL);
#else
    compress_no_gvl((void*)args);
#endif
}

static void
brotli_decompressor_step(brotli_decoder_args_t *args)
{
#ifdef HAVE_RUBY_THREAD_H
    rb_thread_call_without_gvl(decompress_no_gvl, (void*)args, NULL, NULL);
#else
    decompress_no_gvl((void*)args);
#endif
}

static void
brotli_encoder_destroy(brotli_encoder_t* encoder)
{
    if (encoder->state) {
        BrotliEncoderDestroyInstance(encoder->state);
        encoder->state = NULL;
    }
#if defined(HAVE_BROTLIENCODERPREPAREDICTIONARY) && defined(HAVE_BROTLIENCODERATTACHPREPAREDDICTIONARY)
    if (encoder->prepared_dict) {
        BrotliEncoderDestroyPreparedDictionary(encoder->prepared_dict);
        encoder->prepared_dict = NULL;
    }
#endif
    brotli_free(NULL, encoder->dict_data);
    encoder->dict_data = NULL;
    encoder->dict_len = 0;
    encoder->finished = BROTLI_FALSE;
}

static void
brotli_encoder_reset(brotli_encoder_t* encoder)
{
    brotli_encoder_destroy(encoder);
    encoder->state = brotli_encoder_state_create();
}

static void
brotli_encoder_take_output_to_string(BrotliEncoderState* state, VALUE output)
{
    while (BrotliEncoderHasMoreOutput(state)) {
        size_t len = 0;
        const uint8_t* out = BrotliEncoderTakeOutput(state, &len);
        if (len > 0) {
            rb_str_cat(output, (const char*)out, len);
        }
    }
}

static void
brotli_encoder_attach_dictionary(brotli_encoder_t* encoder, VALUE opts)
{
    VALUE dict = brotli_hash_lookup(opts, id_dictionary);

    if (NIL_P(dict)) {
        return;
    }

#if defined(HAVE_BROTLIENCODERPREPAREDICTIONARY) && defined(HAVE_BROTLIENCODERATTACHPREPAREDDICTIONARY)
    encoder->dict_data = brotli_copy_string_data(dict, &encoder->dict_len);
    encoder->prepared_dict = BrotliEncoderPrepareDictionary(
        BROTLI_SHARED_DICTIONARY_RAW,
        encoder->dict_len,
        encoder->dict_data,
        BROTLI_MAX_QUALITY,
        brotli_alloc,
        brotli_free,
        NULL);

    if (!encoder->prepared_dict) {
        brotli_free(NULL, encoder->dict_data);
        encoder->dict_data = NULL;
        encoder->dict_len = 0;
        rb_raise(rb_eBrotli, "Failed to prepare dictionary for compression");
    }

    if (!BrotliEncoderAttachPreparedDictionary(encoder->state, encoder->prepared_dict)) {
        BrotliEncoderDestroyPreparedDictionary(encoder->prepared_dict);
        encoder->prepared_dict = NULL;
        brotli_free(NULL, encoder->dict_data);
        encoder->dict_data = NULL;
        encoder->dict_len = 0;
        rb_raise(rb_eBrotli, "Failed to attach dictionary for compression");
    }
#else
    rb_raise(rb_eBrotli, "Dictionary support not available in this build");
#endif
}

static VALUE
brotli_encoder_stream_to_string(brotli_encoder_t* encoder,
                                BrotliEncoderOperation op,
                                const uint8_t* input,
                                size_t input_len)
{
    VALUE output = rb_str_buf_new(BUFSIZ);
    brotli_encoder_args_t args = {
        .state = encoder->state,
        .op = op,
        .available_in = input_len,
        .next_in = input,
        .ok = BROTLI_FALSE
    };

    if (op == BROTLI_OPERATION_PROCESS && input_len == 0) {
        return output;
    }

    for (;;) {
        long output_len_before;
        size_t produced;

        brotli_encoder_step(&args);
        if (args.ok == BROTLI_FALSE) {
            rb_raise(rb_eBrotli, "BrotliEncoderCompressStream failed");
        }

        output_len_before = RSTRING_LEN(output);
        brotli_encoder_take_output_to_string(encoder->state, output);
        produced = (size_t)(RSTRING_LEN(output) - output_len_before);

        if (args.available_in > 0 || BrotliEncoderHasMoreOutput(encoder->state)) {
            continue;
        }
        if (op != BROTLI_OPERATION_PROCESS && produced > 0) {
            continue;
        }
        break;
    }

    return output;
}

/*******************************************************************************
 * Compressor
 ******************************************************************************/

static void
brotli_compressor_free(void *p)
{
    brotli_compressor_t* br = p;
    brotli_encoder_destroy(&br->encoder);
    ruby_xfree(br);
}

static size_t
brotli_compressor_memsize(const void *p)
{
    const brotli_compressor_t *br = p;
    return sizeof(*br) + br->encoder.dict_len;
}

static const rb_data_type_t brotli_compressor_data_type = {
    "brotli_compressor",
    { 0, brotli_compressor_free, brotli_compressor_memsize },
    0, 0, RUBY_TYPED_FREE_IMMEDIATELY
};

static VALUE
rb_compressor_alloc(VALUE klass)
{
    brotli_compressor_t *br;
    VALUE obj = TypedData_Make_Struct(klass, brotli_compressor_t, &brotli_compressor_data_type, br);
    br->encoder.state = NULL;
#if defined(HAVE_BROTLIENCODERPREPAREDICTIONARY) && defined(HAVE_BROTLIENCODERATTACHPREPAREDDICTIONARY)
    br->encoder.prepared_dict = NULL;
#endif
    br->encoder.dict_data = NULL;
    br->encoder.dict_len = 0;
    br->encoder.finished = BROTLI_FALSE;
    return obj;
}

static void
brotli_compressor_ensure_open(brotli_compressor_t* br)
{
    if (!br->encoder.state) {
        rb_raise(rb_eBrotli, "Compressor is closed");
    }
}

static VALUE
rb_compressor_initialize(int argc, VALUE* argv, VALUE self)
{
    VALUE opts = Qnil;
    brotli_compressor_t *br;

    rb_scan_args(argc, argv, "01", &opts);

    TypedData_Get_Struct(self, brotli_compressor_t, &brotli_compressor_data_type, br);
    brotli_encoder_reset(&br->encoder);
    brotli_deflate_parse_options(br->encoder.state, opts);
    brotli_encoder_attach_dictionary(&br->encoder, opts);

    return self;
}

static VALUE
rb_compressor_process(VALUE self, VALUE input)
{
    brotli_compressor_t *br;
    VALUE output;
    TypedData_Get_Struct(self, brotli_compressor_t, &brotli_compressor_data_type, br);
    brotli_compressor_ensure_open(br);
    if (br->encoder.finished) {
        rb_raise(rb_eBrotli, "Compressor is finished");
    }

    StringValue(input);
    output = brotli_encoder_stream_to_string(&br->encoder,
                                             BROTLI_OPERATION_PROCESS,
                                             (const uint8_t*)RSTRING_PTR(input),
                                             (size_t)RSTRING_LEN(input));
    RB_GC_GUARD(input);
    return output;
}

static VALUE
rb_compressor_flush(VALUE self)
{
    brotli_compressor_t *br;
    TypedData_Get_Struct(self, brotli_compressor_t, &brotli_compressor_data_type, br);
    brotli_compressor_ensure_open(br);
    if (br->encoder.finished) {
        rb_raise(rb_eBrotli, "Compressor is finished");
    }

    return brotli_encoder_stream_to_string(&br->encoder, BROTLI_OPERATION_FLUSH, NULL, 0);
}

static VALUE
rb_compressor_finish(VALUE self)
{
    brotli_compressor_t *br;
    VALUE output;

    TypedData_Get_Struct(self, brotli_compressor_t, &brotli_compressor_data_type, br);
    brotli_compressor_ensure_open(br);

    if (br->encoder.finished) {
        return rb_str_new("", 0);
    }

    output = brotli_encoder_stream_to_string(&br->encoder, BROTLI_OPERATION_FINISH, NULL, 0);
    br->encoder.finished = BROTLI_TRUE;
    return output;
}

static VALUE
rb_compressor_is_finished(VALUE self)
{
    brotli_compressor_t *br;

    TypedData_Get_Struct(self, brotli_compressor_t, &brotli_compressor_data_type, br);
    brotli_compressor_ensure_open(br);
    return br->encoder.finished ? Qtrue : Qfalse;
}

/*******************************************************************************
 * Decompressor
 ******************************************************************************/

static void
brotli_decompressor_mark(void *p)
{
    brotli_decompressor_t *br = p;
#ifdef HAVE_RB_GC_MARK_MOVABLE
    rb_gc_mark_movable(br->pending_input);
#else
    rb_gc_mark(br->pending_input);
#endif
}

static void
brotli_decompressor_free(void *p)
{
    brotli_decompressor_t *br = p;
    if (br->state) {
        BrotliDecoderDestroyInstance(br->state);
        br->state = NULL;
    }
    brotli_free(NULL, br->dict_data);
    br->dict_data = NULL;
    br->dict_len = 0;
    br->pending_input = Qnil;
    br->needs_more_output = BROTLI_FALSE;
    br->finished = BROTLI_FALSE;
    ruby_xfree(br);
}

static void
brotli_decompressor_set_pending_input(VALUE self, brotli_decompressor_t* br, VALUE pending_input)
{
    RB_OBJ_WRITE(self, &br->pending_input, pending_input);
}

static void
brotli_decompressor_reset(VALUE self, brotli_decompressor_t* br)
{
    if (br->state) {
        BrotliDecoderDestroyInstance(br->state);
        br->state = NULL;
    }

    brotli_free(NULL, br->dict_data);
    br->dict_data = NULL;
    br->dict_len = 0;
    brotli_decompressor_set_pending_input(self, br, Qnil);
    br->needs_more_output = BROTLI_FALSE;
    br->finished = BROTLI_FALSE;
    br->state = brotli_decoder_state_create();
}

static size_t
brotli_decompressor_memsize(const void *p)
{
    const brotli_decompressor_t *br = p;
    return sizeof(*br) + br->dict_len;
}

#ifdef HAVE_RB_GC_MARK_MOVABLE
static void
brotli_decompressor_compact(void *p)
{
    brotli_decompressor_t *br = p;

    if (!NIL_P(br->pending_input)) {
        br->pending_input = rb_gc_location(br->pending_input);
    }
}
#endif

static const rb_data_type_t brotli_decompressor_data_type = {
    "brotli_decompressor",
    {
        brotli_decompressor_mark,
        brotli_decompressor_free,
        brotli_decompressor_memsize,
#ifdef HAVE_RB_GC_MARK_MOVABLE
        brotli_decompressor_compact,
#endif
    },
    0, 0, RUBY_TYPED_FREE_IMMEDIATELY | RUBY_TYPED_WB_PROTECTED
};

static VALUE
rb_decompressor_alloc(VALUE klass)
{
    brotli_decompressor_t *br;
    VALUE obj = TypedData_Make_Struct(klass, brotli_decompressor_t, &brotli_decompressor_data_type, br);
    br->state = NULL;
    br->dict_data = NULL;
    br->dict_len = 0;
    RB_OBJ_WRITE(obj, &br->pending_input, Qnil);
    br->needs_more_output = BROTLI_FALSE;
    br->finished = BROTLI_FALSE;
    return obj;
}

static void
brotli_decompressor_attach_dictionary(brotli_decompressor_t* br, VALUE opts)
{
    VALUE dict = brotli_hash_lookup(opts, id_dictionary);
    if (NIL_P(dict)) {
        return;
    }

#ifdef HAVE_BROTLIDECODERATTACHDICTIONARY
    br->dict_data = brotli_copy_string_data(dict, &br->dict_len);
    if (!BrotliDecoderAttachDictionary(br->state,
                                       BROTLI_SHARED_DICTIONARY_RAW,
                                       br->dict_len,
                                       br->dict_data)) {
        brotli_free(NULL, br->dict_data);
        br->dict_data = NULL;
        br->dict_len = 0;
        rb_raise(rb_eBrotli, "Failed to attach dictionary for decompression");
    }
#else
    rb_raise(rb_eBrotli, "Dictionary support not available in this build");
#endif
}

static VALUE
rb_decompressor_initialize(int argc, VALUE* argv, VALUE self)
{
    VALUE opts = Qnil;
    brotli_decompressor_t *br;

    rb_scan_args(argc, argv, "01", &opts);
    TypedData_Get_Struct(self, brotli_decompressor_t, &brotli_decompressor_data_type, br);
    brotli_decompressor_reset(self, br);
    brotli_decompressor_attach_dictionary(br, opts);

    return self;
}

static BROTLI_BOOL
brotli_decompressor_has_pending_input(const brotli_decompressor_t *br)
{
    return !NIL_P(br->pending_input) && RSTRING_LEN(br->pending_input) > 0;
}

static size_t
brotli_decompressor_pending_input_length(const brotli_decompressor_t *br)
{
    if (!brotli_decompressor_has_pending_input(br)) {
        return 0;
    }
    return (size_t)RSTRING_LEN(br->pending_input);
}

static void
brotli_decompressor_clear_pending_input(VALUE self, brotli_decompressor_t* br)
{
    brotli_decompressor_set_pending_input(self, br, Qnil);
}

static void
brotli_decompressor_ensure_open(const brotli_decompressor_t* br)
{
    if (!br->state) {
        rb_raise(rb_eBrotli, "Decompressor is closed");
    }
}

static BROTLI_BOOL
brotli_decompressor_needs_output_drain(const brotli_decompressor_t *br)
{
    return br->needs_more_output || brotli_decompressor_has_pending_input(br) ||
           BrotliDecoderHasMoreOutput(br->state);
}

static void
brotli_decompressor_store_pending_input(VALUE self,
                                        brotli_decompressor_t* br,
                                        const uint8_t* next_in,
                                        size_t available_in)
{
    if (available_in == 0) {
        brotli_decompressor_clear_pending_input(self, br);
        return;
    }
    brotli_decompressor_set_pending_input(self, br, rb_str_new((const char*)next_in, (long)available_in));
}

static size_t
brotli_output_buffer_limit(VALUE opts)
{
    VALUE limit_value = brotli_hash_lookup(opts, id_output_buffer_limit);

    if (NIL_P(limit_value)) {
        return 0;
    }

    if (rb_cmpint(rb_funcall(limit_value, id_cmp, 1, INT2FIX(0)), limit_value, INT2FIX(0)) <= 0) {
        rb_raise(rb_eArgError, "output_buffer_limit must be positive");
    }

    return NUM2SIZET(limit_value);
}

static VALUE
rb_decompressor_process(int argc, VALUE* argv, VALUE self)
{
    brotli_decompressor_t *br;
    VALUE input = Qnil;
    VALUE opts = Qnil;
    VALUE input_source = Qnil;
    VALUE output;
    size_t available_in;
    const uint8_t* next_in;
    size_t output_buffer_limit;
    BROTLI_BOOL limit_output;
    BrotliDecoderResult result = BROTLI_DECODER_RESULT_ERROR;
    uint8_t outbuf[BUFSIZ];

    rb_scan_args(argc, argv, "11", &input, &opts);
    TypedData_Get_Struct(self, brotli_decompressor_t, &brotli_decompressor_data_type, br);
    brotli_decompressor_ensure_open(br);
    output_buffer_limit = brotli_output_buffer_limit(opts);
    limit_output = output_buffer_limit > 0 ? BROTLI_TRUE : BROTLI_FALSE;

    if (br->finished) {
        StringValue(input);
        available_in = (size_t)RSTRING_LEN(input);
        if (available_in == 0) {
            return rb_str_buf_new(0);
        }
        rb_raise(rb_eBrotli, "Decompressor is finished");
    }

    StringValue(input);
    if (brotli_decompressor_needs_output_drain(br)) {
        if (RSTRING_LEN(input) > 0) {
            rb_raise(rb_eBrotli,
                     "Decompressor cannot accept more data until pending output is drained");
        }
        if (brotli_decompressor_has_pending_input(br)) {
            input_source = br->pending_input;
        } else {
            input_source = input;
        }
    } else {
        input_source = input;
    }

    if (input_source == br->pending_input) {
        available_in = brotli_decompressor_pending_input_length(br);
        next_in = (const uint8_t*)RSTRING_PTR(input_source);
    } else {
        available_in = (size_t)RSTRING_LEN(input_source);
        next_in = (const uint8_t*)RSTRING_PTR(input_source);
        brotli_decompressor_clear_pending_input(self, br);
    }
    br->needs_more_output = BROTLI_FALSE;
    output = rb_str_buf_new(BUFSIZ);

    for (;;) {
        size_t chunk_size = BUFSIZ;
        brotli_decoder_args_t args;
        size_t produced;

        if (limit_output) {
            size_t used = (size_t)RSTRING_LEN(output);
            if (used >= output_buffer_limit) {
                brotli_decompressor_store_pending_input(self, br, next_in, available_in);
                br->needs_more_output = BROTLI_TRUE;
                break;
            }
            if (output_buffer_limit - used < chunk_size) {
                chunk_size = output_buffer_limit - used;
            }
        }

        args.state = br->state;
        args.available_in = available_in;
        args.next_in = next_in;
        args.available_out = chunk_size;
        args.next_out = outbuf;
        args.result = BROTLI_DECODER_RESULT_ERROR;
        brotli_decompressor_step(&args);
        available_in = args.available_in;
        next_in = args.next_in;
        result = args.result;

        produced = chunk_size - args.available_out;
        if (produced > 0) {
            rb_str_cat(output, (const char*)outbuf, produced);
        }

        if (result == BROTLI_DECODER_RESULT_NEEDS_MORE_OUTPUT) {
            if (limit_output && (size_t)RSTRING_LEN(output) >= output_buffer_limit) {
                brotli_decompressor_store_pending_input(self, br, next_in, available_in);
                br->needs_more_output = BROTLI_TRUE;
                break;
            }
            continue;
        }
        if (result == BROTLI_DECODER_RESULT_NEEDS_MORE_INPUT) {
            if (BrotliDecoderHasMoreOutput(br->state)) {
                continue;
            }
            brotli_decompressor_clear_pending_input(self, br);
            br->needs_more_output = BROTLI_FALSE;
            break;
        }
        if (result == BROTLI_DECODER_RESULT_SUCCESS) {
            br->finished = BROTLI_TRUE;
            brotli_decompressor_store_pending_input(self, br, next_in, available_in);
            br->needs_more_output = BROTLI_FALSE;
            break;
        }

        rb_raise(rb_eBrotli, "%s",
                 BrotliDecoderErrorString(BrotliDecoderGetErrorCode(br->state)));
    }

    RB_GC_GUARD(input_source);
    return output;
}

static VALUE
rb_decompressor_is_finished(VALUE self)
{
    brotli_decompressor_t *br;

    TypedData_Get_Struct(self, brotli_decompressor_t, &brotli_decompressor_data_type, br);
    brotli_decompressor_ensure_open(br);

    if (br->finished || BrotliDecoderIsFinished(br->state)) {
        br->finished = BROTLI_TRUE;
        return Qtrue;
    }
    return Qfalse;
}

static VALUE
rb_decompressor_can_accept_more_data(VALUE self)
{
    brotli_decompressor_t *br;
    TypedData_Get_Struct(self, brotli_decompressor_t, &brotli_decompressor_data_type, br);
    brotli_decompressor_ensure_open(br);
    return (br->finished || brotli_decompressor_needs_output_drain(br)) ? Qfalse : Qtrue;
}

static VALUE
rb_decompressor_unused_data(VALUE self)
{
    brotli_decompressor_t *br;
    size_t available_in;
    TypedData_Get_Struct(self, brotli_decompressor_t, &brotli_decompressor_data_type, br);
    brotli_decompressor_ensure_open(br);
    available_in = brotli_decompressor_pending_input_length(br);
    if (!br->finished || available_in == 0) {
        return rb_str_buf_new(0);
    }
    return rb_str_dup(br->pending_input);
}

/*******************************************************************************
 * entry
 ******************************************************************************/

void
Init_brotli(void)
{
#if HAVE_RB_EXT_RACTOR_SAFE
    rb_ext_ractor_safe(true);
#endif

    VALUE rb_mBrotli;
    rb_mBrotli = rb_define_module("Brotli");
    rb_eBrotli = rb_define_class_under(rb_mBrotli, "Error", rb_eStandardError);
    rb_define_singleton_method(rb_mBrotli, "deflate", brotli_deflate, -1);
    rb_define_singleton_method(rb_mBrotli, "inflate", brotli_inflate, -1);
    rb_define_singleton_method(rb_mBrotli, "version", brotli_version, 0);
    id_cmp = rb_intern("<=>");
    id_dictionary = rb_intern("dictionary");
    id_font = rb_intern("font");
    id_generic = rb_intern("generic");
    id_lgblock = rb_intern("lgblock");
    id_lgwin = rb_intern("lgwin");
    id_mode = rb_intern("mode");
    id_output_buffer_limit = rb_intern("output_buffer_limit");
    id_quality = rb_intern("quality");
    id_read = rb_intern("read");
    id_text = rb_intern("text");

    rb_cBrotliCompressor = rb_define_class_under(rb_mBrotli, "Compressor", rb_cObject);
    rb_define_alloc_func(rb_cBrotliCompressor, rb_compressor_alloc);
    rb_define_method(rb_cBrotliCompressor, "initialize", rb_compressor_initialize, -1);
    rb_define_method(rb_cBrotliCompressor, "process", rb_compressor_process, 1);
    rb_define_method(rb_cBrotliCompressor, "flush", rb_compressor_flush, 0);
    rb_define_method(rb_cBrotliCompressor, "finish", rb_compressor_finish, 0);
    rb_define_method(rb_cBrotliCompressor, "finished?", rb_compressor_is_finished, 0);

    rb_cBrotliDecompressor = rb_define_class_under(rb_mBrotli, "Decompressor", rb_cObject);
    rb_define_alloc_func(rb_cBrotliDecompressor, rb_decompressor_alloc);
    rb_define_method(rb_cBrotliDecompressor, "initialize", rb_decompressor_initialize, -1);
    rb_define_method(rb_cBrotliDecompressor, "process", rb_decompressor_process, -1);
    rb_define_method(rb_cBrotliDecompressor, "is_finished", rb_decompressor_is_finished, 0);
    rb_define_method(rb_cBrotliDecompressor, "finished?", rb_decompressor_is_finished, 0);
    rb_define_method(rb_cBrotliDecompressor, "can_accept_more_data", rb_decompressor_can_accept_more_data, 0);
    rb_define_method(rb_cBrotliDecompressor, "can_accept_more_data?", rb_decompressor_can_accept_more_data, 0);
    rb_define_method(rb_cBrotliDecompressor, "unused_data", rb_decompressor_unused_data, 0);
}
