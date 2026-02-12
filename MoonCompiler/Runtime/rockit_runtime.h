// rockit_runtime.h
// Rockit Native Runtime — C runtime library for LLVM-compiled Rockit programs
// Copyright © 2026 Dark Matter Tech. All rights reserved.

#ifndef ROCKIT_RUNTIME_H
#define ROCKIT_RUNTIME_H

#include <stdint.h>
#include <stddef.h>

// ── Value Tags ──────────────────────────────────────────────────────────────

#define ROCKIT_TAG_INT     0
#define ROCKIT_TAG_FLOAT   1
#define ROCKIT_TAG_BOOL    2
#define ROCKIT_TAG_STRING  3
#define ROCKIT_TAG_NULL    4
#define ROCKIT_TAG_OBJECT  5
#define ROCKIT_TAG_UNIT    6

// ── Forward Declarations ────────────────────────────────────────────────────

typedef struct RockitString RockitString;
typedef struct RockitObject RockitObject;

// ── RockitString ────────────────────────────────────────────────────────────

struct RockitString {
    int64_t refCount;
    int64_t length;
    char data[];  // UTF-8, null-terminated, flexible array member
};

RockitString* rockit_string_new(const char* utf8);
RockitString* rockit_string_concat(RockitString* a, RockitString* b);
void rockit_string_retain(RockitString* s);
void rockit_string_release(RockitString* s);
int64_t rockit_string_length(RockitString* s);

// ── RockitObject ────────────────────────────────────────────────────────────

struct RockitObject {
    const char* typeName;
    int64_t     refCount;
    int32_t     fieldCount;
    int32_t     _padding;
    int64_t     fields[];   // flexible array member — stores all field values as i64
};

RockitObject* rockit_object_alloc(const char* typeName, int32_t fieldCount);
int64_t  rockit_object_get_field(RockitObject* obj, int32_t index);
void     rockit_object_set_field(RockitObject* obj, int32_t index, int64_t value);
void     rockit_retain(RockitObject* obj);
void     rockit_release(RockitObject* obj);

// ── RockitList ──────────────────────────────────────────────────────────────

typedef struct RockitList {
    int64_t refCount;
    int64_t size;
    int64_t capacity;
    int64_t* data;
} RockitList;

RockitList* rockit_list_create(void);
void     rockit_list_append(RockitList* list, int64_t value);
int64_t  rockit_list_get(RockitList* list, int64_t index);
void     rockit_list_set(RockitList* list, int64_t index, int64_t value);
int64_t  rockit_list_size(RockitList* list);
int8_t   rockit_list_is_empty(RockitList* list);
void     rockit_list_release(RockitList* list);

// ── RockitMap ───────────────────────────────────────────────────────────────

typedef struct RockitMapEntry {
    int64_t key;
    int64_t value;
    int8_t  occupied;
} RockitMapEntry;

typedef struct RockitMap {
    int64_t        refCount;
    int64_t        size;
    int64_t        capacity;
    RockitMapEntry* entries;
} RockitMap;

RockitMap* rockit_map_create(void);
void     rockit_map_put(RockitMap* map, int64_t key, int64_t value);
int64_t  rockit_map_get(RockitMap* map, int64_t key);
int8_t   rockit_map_contains_key(RockitMap* map, int64_t key);
int64_t  rockit_map_size(RockitMap* map);
int8_t   rockit_map_is_empty(RockitMap* map);
void     rockit_map_release(RockitMap* map);

// ── I/O ─────────────────────────────────────────────────────────────────────

void rockit_println_int(int64_t value);
void rockit_println_float(double value);
void rockit_println_bool(int8_t value);
void rockit_println_string(RockitString* s);
void rockit_println_null(void);
void rockit_print_int(int64_t value);
void rockit_print_float(double value);
void rockit_print_bool(int8_t value);
void rockit_print_string(RockitString* s);

// ── Conversion ──────────────────────────────────────────────────────────────

RockitString* rockit_int_to_string(int64_t value);
RockitString* rockit_float_to_string(double value);
RockitString* rockit_bool_to_string(int8_t value);

// ── Process ─────────────────────────────────────────────────────────────────

void rockit_panic(const char* message);

#endif // ROCKIT_RUNTIME_H
