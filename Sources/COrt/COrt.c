#include "COrt.h"
#include <onnxruntime/onnxruntime_c_api.h>
#include <onnxruntime/coreml_provider_factory.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define ORT_CHECK(call, label) do { \
    OrtStatus* _status = call; \
    if (_status != NULL) { \
        const char* msg = get_api()->GetErrorMessage(_status); \
        fprintf(stderr, "ORT error at %s:%d: %s\n", __FILE__, __LINE__, msg); \
        get_api()->ReleaseStatus(_status); \
        goto label; \
    } \
} while (0)

#define ORT_RELEASE_ALLOCATED(allocator, value) do { \
    OrtStatus* _status = get_api()->AllocatorFree((allocator), (value)); \
    if (_status != NULL) { \
        const char* msg = get_api()->GetErrorMessage(_status); \
        fprintf(stderr, "ORT allocator free error at %s:%d: %s\n", __FILE__, __LINE__, msg); \
        get_api()->ReleaseStatus(_status); \
    } \
} while (0)

static const OrtApi *g_api = NULL;

static const OrtApi *get_api(void) {
    if (g_api == NULL) {
        g_api = OrtGetApiBase()->GetApi(ORT_API_VERSION);
    }
    return g_api;
}

struct COrtTensor {
    void *data;
    int64_t *shape;
    int64_t ndim;
    int64_t size;
    COrtDataType data_type;
};

struct COrtSession {
    OrtEnv *env;
    OrtSession *session;
    OrtAllocator *allocator;
    OrtMemoryInfo *mem_info;
};

COrtSession *cort_session_create(const uint8_t *model_data, size_t model_len) {
    const OrtApi *api = get_api();
    COrtSession *s = calloc(1, sizeof(COrtSession));
    if (!s) return NULL;

    ORT_CHECK(api->CreateEnv(ORT_LOGGING_LEVEL_WARNING, "COrt", &s->env), fail_env);
    ORT_CHECK(api->GetAllocatorWithDefaultOptions(&s->allocator), fail_alloc);
    ORT_CHECK(api->CreateCpuMemoryInfo(OrtArenaAllocator, OrtMemTypeDefault, &s->mem_info), fail_mem);

    OrtSessionOptions *opts = NULL;
    ORT_CHECK(api->CreateSessionOptions(&opts), fail_opts);
    ORT_CHECK(OrtSessionOptionsAppendExecutionProvider_CoreML(opts, COREML_FLAG_ENABLE_ON_SUBGRAPH), fail_session);
    ORT_CHECK(api->CreateSessionFromArray(s->env, model_data, model_len, opts, &s->session), fail_session);

    api->ReleaseSessionOptions(opts);
    return s;

fail_session:
    api->ReleaseSessionOptions(opts);
fail_opts:
    api->ReleaseMemoryInfo(s->mem_info);
fail_mem:
    api->ReleaseAllocator(s->allocator);
fail_alloc:
    api->ReleaseEnv(s->env);
fail_env:
    free(s);
    return NULL;
}

COrtSession *cort_session_create_from_path(const char *model_path) {
    const OrtApi *api = get_api();
    COrtSession *s = calloc(1, sizeof(COrtSession));
    if (!s) return NULL;

    ORT_CHECK(api->CreateEnv(ORT_LOGGING_LEVEL_WARNING, "COrt", &s->env), fail_env);
    ORT_CHECK(api->GetAllocatorWithDefaultOptions(&s->allocator), fail_alloc);
    ORT_CHECK(api->CreateCpuMemoryInfo(OrtArenaAllocator, OrtMemTypeDefault, &s->mem_info), fail_mem);

    OrtSessionOptions *opts = NULL;
    ORT_CHECK(api->CreateSessionOptions(&opts), fail_opts);
    ORT_CHECK(OrtSessionOptionsAppendExecutionProvider_CoreML(opts, COREML_FLAG_ENABLE_ON_SUBGRAPH), fail_session);
    ORT_CHECK(api->CreateSession(s->env, model_path, opts, &s->session), fail_session);

    api->ReleaseSessionOptions(opts);
    return s;

fail_session:
    api->ReleaseSessionOptions(opts);
fail_opts:
    api->ReleaseMemoryInfo(s->mem_info);
fail_mem:
    api->ReleaseAllocator(s->allocator);
fail_alloc:
    api->ReleaseEnv(s->env);
fail_env:
    free(s);
    return NULL;
}

void cort_session_destroy(COrtSession *session) {
    if (!session) return;
    const OrtApi *api = get_api();
    if (session->session) api->ReleaseSession(session->session);
    if (session->mem_info) api->ReleaseMemoryInfo(session->mem_info);
    if (session->allocator) api->ReleaseAllocator(session->allocator);
    if (session->env) api->ReleaseEnv(session->env);
    free(session);
}

int64_t cort_input_count(COrtSession *session) {
    const OrtApi *api = get_api();
    size_t n = 0;
    ORT_CHECK(api->SessionGetInputCount(session->session, &n), fail);
    return (int64_t)n;
fail:
    return -1;
}

int64_t cort_output_count(COrtSession *session) {
    const OrtApi *api = get_api();
    size_t n = 0;
    ORT_CHECK(api->SessionGetOutputCount(session->session, &n), fail);
    return (int64_t)n;
fail:
    return -1;
}

const char *cort_input_name(COrtSession *session, int64_t index) {
    const OrtApi *api = get_api();
    char *name = NULL;
    ORT_CHECK(api->SessionGetInputName(session->session, (size_t)index, session->allocator, &name), fail);
    return name;
fail:
    return NULL;
}

const char *cort_output_name(COrtSession *session, int64_t index) {
    const OrtApi *api = get_api();
    char *name = NULL;
    ORT_CHECK(api->SessionGetOutputName(session->session, (size_t)index, session->allocator, &name), fail);
    return name;
fail:
    return NULL;
}

static int64_t *get_shape(COrtSession *session, int is_input, int64_t index, int64_t *ndim_out) {
    const OrtApi *api = get_api();
    OrtTypeInfo *type_info = NULL;
    const OrtTensorTypeAndShapeInfo *shape_info = NULL;
    int64_t *shape = NULL;
    size_t ndim = 0;

    if (is_input) {
        ORT_CHECK(api->SessionGetInputTypeInfo(session->session, (size_t)index, &type_info), fail);
    } else {
        ORT_CHECK(api->SessionGetOutputTypeInfo(session->session, (size_t)index, &type_info), fail);
    }
    ORT_CHECK(api->CastTypeInfoToTensorInfo(type_info, &shape_info), fail);
    ORT_CHECK(api->GetDimensionsCount(shape_info, &ndim), fail);
    shape = calloc(ndim, sizeof(int64_t));
    if (!shape) goto fail;
    ORT_CHECK(api->GetDimensions(shape_info, shape, ndim), fail_free_shape);
    api->ReleaseTypeInfo(type_info);

    *ndim_out = (int64_t)ndim;
    return shape;

fail_free_shape:
    free(shape);
fail:
    api->ReleaseTypeInfo(type_info);
    return NULL;
}

int64_t *cort_input_shape(COrtSession *session, int64_t index, int64_t *ndim_out) {
    return get_shape(session, 1, index, ndim_out);
}

int64_t *cort_output_shape(COrtSession *session, int64_t index, int64_t *ndim_out) {
    return get_shape(session, 0, index, ndim_out);
}

int cort_run(COrtSession *session,
             const char *input_name, const int64_t *shape, int64_t ndim,
             const float *input_data, int64_t data_len,
             COrtTensor **output) {
    const OrtApi *api = get_api();

    OrtValue *in_val = NULL;
    size_t out_count = 0;
    char **out_names = NULL;
    OrtValue *out_val = NULL;
    OrtTensorTypeAndShapeInfo *shape_info = NULL;
    int64_t *out_shape = NULL;
    COrtTensor *t = NULL;

    // Create input tensor
    ORT_CHECK(api->CreateTensorWithDataAsOrtValue(
        session->mem_info, (void *)input_data, (size_t)(data_len * sizeof(float)),
        shape, (size_t)ndim, ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT, &in_val), fail);

    // Get output count
    ORT_CHECK(api->SessionGetOutputCount(session->session, &out_count), fail);

    // Get output name(s)
    out_names = calloc(out_count, sizeof(char *));
    if (!out_names) goto fail;
    for (size_t i = 0; i < out_count; i++) {
        ORT_CHECK(api->SessionGetOutputName(session->session, i, session->allocator, &out_names[i]), fail);
    }

    // Run inference
    ORT_CHECK(api->Run(session->session, NULL,
                  &input_name, (const OrtValue *const *)&in_val, 1,
                  (const char *const *)out_names, out_count, &out_val), fail);

    // Release intermediate resources
    api->ReleaseValue(in_val);
    in_val = NULL;
    for (size_t i = 0; i < out_count; i++) {
        (void)api->AllocatorFree(session->allocator, out_names[i]);
    }
    free(out_names);
    out_names = NULL;

    // Extract data from output
    ORT_CHECK(api->GetTensorTypeAndShape(out_val, &shape_info), fail_after_run);

    size_t out_ndim = 0;
    ORT_CHECK(api->GetDimensionsCount(shape_info, &out_ndim), fail_after_run);

    out_shape = calloc(out_ndim, sizeof(int64_t));
    if (!out_shape) goto fail_after_run;
    ORT_CHECK(api->GetDimensions(shape_info, out_shape, out_ndim), fail_after_run);

    size_t elem_count = 0;
    ORT_CHECK(api->GetTensorShapeElementCount(shape_info, &elem_count), fail_after_run);

    api->ReleaseTensorTypeAndShapeInfo(shape_info);
    shape_info = NULL;

    float *raw_data = NULL;
    ORT_CHECK(api->GetTensorMutableData(out_val, (void **)&raw_data), fail_after_run);

    t = calloc(1, sizeof(COrtTensor));
    if (!t) goto fail_after_run;
    t->ndim = (int64_t)out_ndim;
    t->size = (int64_t)elem_count;
    t->shape = out_shape;
    t->data_type = COrtDataTypeFloat;
    t->data = calloc(elem_count, sizeof(float));
    if (!t->data) { free(t); t = NULL; goto fail_after_run; }
    memcpy(t->data, raw_data, elem_count * sizeof(float));

    api->ReleaseValue(out_val);

    *output = t;
    return 0;

fail_after_run:
    api->ReleaseValue(out_val);
    api->ReleaseTensorTypeAndShapeInfo(shape_info);
    free(out_shape);
    free(t);
    // fall through
fail:
    if (output) *output = NULL;
    if (out_names) {
        for (size_t i = 0; i < out_count; i++) {
            if (out_names[i]) (void)api->AllocatorFree(session->allocator, out_names[i]);
        }
        free(out_names);
    }
    if (in_val) api->ReleaseValue(in_val);
    return -1;
}

static ONNXTensorElementDataType cort_to_onnx_type(COrtDataType dt) {
    switch (dt) {
        case COrtDataTypeFloat: return ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT;
        case COrtDataTypeInt64: return ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64;
        case COrtDataTypeInt32: return ONNX_TENSOR_ELEMENT_DATA_TYPE_INT32;
    }
    return ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT;
}

static COrtDataType onnx_to_cort_type(ONNXTensorElementDataType dt) {
    switch (dt) {
        case ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT: return COrtDataTypeFloat;
        case ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64: return COrtDataTypeInt64;
        case ONNX_TENSOR_ELEMENT_DATA_TYPE_INT32: return COrtDataTypeInt32;
        default: return COrtDataTypeFloat;
    }
}

static size_t cort_type_size(COrtDataType dt) {
    switch (dt) {
        case COrtDataTypeFloat: return sizeof(float);
        case COrtDataTypeInt64: return sizeof(int64_t);
        case COrtDataTypeInt32: return sizeof(int32_t);
    }
    return sizeof(float);
}

int cort_run_batch(COrtSession *session,
                   const COrtInput *inputs, int64_t num_inputs,
                   COrtTensor ***outputs, int64_t *num_outputs) {
    const OrtApi *api = get_api();

    OrtValue **in_vals = NULL;
    const char **in_names = NULL;
    char **out_name_list = NULL;
    OrtValue **out_vals = NULL;
    size_t out_count = 0;
    int ret = -1;

    if (num_inputs <= 0 || !inputs || !outputs) return -1;

    // Allocate input arrays
    in_vals = calloc((size_t)num_inputs, sizeof(OrtValue *));
    in_names = calloc((size_t)num_inputs, sizeof(const char *));
    if (!in_vals || !in_names) goto cleanup;

    // Create input tensors
    for (int64_t i = 0; i < num_inputs; i++) {
        in_names[i] = inputs[i].name;
        ONNXTensorElementDataType onnx_type = cort_to_onnx_type(inputs[i].data_type);
        size_t byte_len = (size_t)(inputs[i].data_len * cort_type_size(inputs[i].data_type));
        ORT_CHECK(api->CreateTensorWithDataAsOrtValue(
            session->mem_info, (void *)inputs[i].data, byte_len,
            inputs[i].shape, (size_t)inputs[i].ndim, onnx_type, &in_vals[i]), cleanup);
    }

    // Get output count
    ORT_CHECK(api->SessionGetOutputCount(session->session, &out_count), cleanup);

    // Get output names
    out_name_list = calloc(out_count, sizeof(char *));
    if (!out_name_list) goto cleanup;
    for (size_t i = 0; i < out_count; i++) {
        ORT_CHECK(api->SessionGetOutputName(session->session, i, session->allocator, &out_name_list[i]), cleanup);
    }

    // Allocate output value array
    out_vals = calloc(out_count, sizeof(OrtValue *));
    if (!out_vals) goto cleanup;

    // Run inference
    ORT_CHECK(api->Run(session->session, NULL,
                  in_names, (const OrtValue *const *)in_vals, (size_t)num_inputs,
                  (const char *const *)out_name_list, out_count, out_vals), cleanup);

    // Allocate result COrtTensor array
    COrtTensor **result = calloc(out_count, sizeof(COrtTensor *));
    if (!result) goto cleanup;

    for (size_t i = 0; i < out_count; i++) {
        COrtTensor *t = calloc(1, sizeof(COrtTensor));
        if (!t) {
            for (size_t j = 0; j < i; j++) cort_tensor_destroy(result[j]);
            free(result);
            goto cleanup;
        }

        // Get shape and type info
        OrtTensorTypeAndShapeInfo *info = NULL;
        ORT_CHECK(api->GetTensorTypeAndShape(out_vals[i], &info), cleanup);
        api->ReleaseTensorTypeAndShapeInfo(info);
        // Re-fetch: actually we need the info before releasing. Let me inline the shape fetch.

        // Fetch shape properly
        OrtTensorTypeAndShapeInfo *info2 = NULL;
        ORT_CHECK(api->GetTensorTypeAndShape(out_vals[i], &info2), cleanup);

        ONNXTensorElementDataType elem_type = ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT;
        ORT_CHECK(api->GetTensorElementType(info2, &elem_type), cleanup);
        t->data_type = onnx_to_cort_type(elem_type);

        size_t out_ndim = 0;
        ORT_CHECK(api->GetDimensionsCount(info2, &out_ndim), cleanup);
        t->shape = calloc(out_ndim, sizeof(int64_t));
        if (!t->shape) { api->ReleaseTensorTypeAndShapeInfo(info2); cort_tensor_destroy(t); goto cleanup; }
        ORT_CHECK(api->GetDimensions(info2, t->shape, out_ndim), cleanup);
        t->ndim = (int64_t)out_ndim;

        size_t elem_count = 0;
        ORT_CHECK(api->GetTensorShapeElementCount(info2, &elem_count), cleanup);
        t->size = (int64_t)elem_count;
        api->ReleaseTensorTypeAndShapeInfo(info2);

        // Copy data
        void *raw_data = NULL;
        ORT_CHECK(api->GetTensorMutableData(out_vals[i], &raw_data), cleanup);
        size_t byte_count = elem_count * cort_type_size(t->data_type);
        t->data = calloc(1, byte_count);
        if (!t->data) { cort_tensor_destroy(t); goto cleanup; }
        memcpy(t->data, raw_data, byte_count);

        result[i] = t;
    }

    *outputs = result;
    *num_outputs = (int64_t)out_count;
    ret = 0;

cleanup:
    // Release input OrtValues
    if (in_vals) {
        for (int64_t i = 0; i < num_inputs; i++) {
            if (in_vals[i]) api->ReleaseValue(in_vals[i]);
        }
        free(in_vals);
    }
    free(in_names);

    // Release output OrtValues
    if (out_vals) {
        for (size_t i = 0; i < out_count; i++) {
            if (out_vals[i]) api->ReleaseValue(out_vals[i]);
        }
        free(out_vals);
    }

    // Free output names
    if (out_name_list) {
        for (size_t i = 0; i < out_count; i++) {
            if (out_name_list[i]) ORT_RELEASE_ALLOCATED(session->allocator, out_name_list[i]);
        }
        free(out_name_list);
    }

    if (ret != 0 && outputs) *outputs = NULL;
    return ret;
}

const float *cort_tensor_data(COrtTensor *tensor) {
    return (const float *)tensor->data;
}

const void *cort_tensor_data_raw(COrtTensor *tensor) {
    return tensor->data;
}

int64_t cort_tensor_size(COrtTensor *tensor) {
    return tensor->size;
}

int64_t *cort_tensor_shape(COrtTensor *tensor, int64_t *ndim_out) {
    *ndim_out = tensor->ndim;
    return tensor->shape;
}

COrtDataType cort_tensor_data_type(COrtTensor *tensor) {
    return tensor->data_type;
}

void cort_tensor_destroy(COrtTensor *tensor) {
    if (!tensor) return;
    free(tensor->data);
    free(tensor->shape);
    free(tensor);
}
