#ifndef __khrplatform_h_
#define __khrplatform_h_

/* Minimal KHR platform header for Phase 1–3 GLAD setup. */

#include <stdint.h>
#include <stddef.h>

typedef float           khronos_float_t;
typedef int32_t         khronos_int32_t;
typedef uint32_t        khronos_uint32_t;
typedef int64_t         khronos_int64_t;
typedef uint64_t        khronos_uint64_t;
typedef intptr_t        khronos_intptr_t;
typedef uintptr_t       khronos_uintptr_t;
typedef int8_t          khronos_int8_t;
typedef uint8_t         khronos_uint8_t;
typedef int16_t         khronos_int16_t;
typedef uint16_t        khronos_uint16_t;
typedef khronos_int32_t khronos_ssize_t;
typedef khronos_uint32_t khronos_usize_t;

#define KHRONOS_APIATTRIBUTES

#endif /* __khrplatform_h_ */
