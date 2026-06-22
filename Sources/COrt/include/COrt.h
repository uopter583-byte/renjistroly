#ifndef COrt_h
#define COrt_h

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct COrtSession COrtSession;
typedef struct COrtTensor COrtTensor;

// Data type enum
typedef enum {
    COrtDataTypeFloat = 0,
    COrtDataTypeInt64 = 1,
    COrtDataTypeInt32 = 2,
} COrtDataType;

// A single input descriptor for batch inference
typedef struct {
    const char *name;       // ONNX input name
    COrtDataType data_type; // float or int64
    const int64_t *shape;   // shape array
    int64_t ndim;           // rank
    const void *data;       // element data
    int64_t data_len;       // element count
} COrtInput;

// Session lifecycle
COrtSession *cort_session_create(const uint8_t *model_data, size_t model_len);
COrtSession *cort_session_create_from_path(const char *model_path);
void cort_session_destroy(COrtSession *session);

// Shape introspection (existing)
int64_t cort_input_count(COrtSession *session);
int64_t cort_output_count(COrtSession *session);
const char *cort_input_name(COrtSession *session, int64_t index);
const char *cort_output_name(COrtSession *session, int64_t index);
int64_t *cort_input_shape(COrtSession *session, int64_t index, int64_t *ndim_out);
int64_t *cort_output_shape(COrtSession *session, int64_t index, int64_t *ndim_out);

// Single-input/single-output run (existing, float only)
int cort_run(COrtSession *session,
             const char *input_name, const int64_t *shape, int64_t ndim,
             const float *input_data, int64_t data_len,
             COrtTensor **output);

// Multi-input/multi-output run with mixed types
int cort_run_batch(COrtSession *session,
                   const COrtInput *inputs, int64_t num_inputs,
                   COrtTensor ***outputs, int64_t *num_outputs);

// Access output tensor (existing + new)
const float *cort_tensor_data(COrtTensor *tensor);
const void *cort_tensor_data_raw(COrtTensor *tensor);
int64_t *cort_tensor_shape(COrtTensor *tensor, int64_t *ndim_out);
int64_t cort_tensor_size(COrtTensor *tensor);
COrtDataType cort_tensor_data_type(COrtTensor *tensor);
void cort_tensor_destroy(COrtTensor *tensor);

#ifdef __cplusplus
}
#endif

#endif /* COrt_h */
