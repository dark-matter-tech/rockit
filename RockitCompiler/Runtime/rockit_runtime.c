// rockit_runtime.c
// Rockit Native Runtime — C runtime library for LLVM-compiled Rockit programs
// Copyright © 2026 Dark Matter Tech. All rights reserved.

#include "rockit_runtime.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#ifdef __APPLE__
#include <malloc/malloc.h>
#endif

// ── RockitString ────────────────────────────────────────────────────────────

RockitString* rockit_string_new(const char* utf8) {
    if (!utf8) utf8 = "";
    int64_t len = (int64_t)strlen(utf8);
    RockitString* s = (RockitString*)malloc(sizeof(RockitString) + len + 1);
    s->refCount = 1;
    s->length = len;
    memcpy(s->data, utf8, len + 1);
    return s;
}

RockitString* rockit_string_concat(RockitString* a, RockitString* b) {
    int64_t newLen = a->length + b->length;
    RockitString* s = (RockitString*)malloc(sizeof(RockitString) + newLen + 1);
    s->refCount = 1;
    s->length = newLen;
    memcpy(s->data, a->data, a->length);
    memcpy(s->data + a->length, b->data, b->length);
    s->data[newLen] = '\0';
    return s;
}

void rockit_string_retain(RockitString* s) {
    if (s && s->refCount != ROCKIT_IMMORTAL_REFCOUNT) s->refCount++;
}

void rockit_string_release(RockitString* s) {
    if (s && s->refCount != ROCKIT_IMMORTAL_REFCOUNT && --s->refCount <= 0) {
        free(s);
    }
}

int64_t rockit_string_length(RockitString* s) {
    return s ? s->length : 0;
}

// ── RockitObject ────────────────────────────────────────────────────────────

RockitObject* rockit_object_alloc(const char* typeName, int32_t fieldCount) {
    RockitObject* obj = (RockitObject*)malloc(sizeof(RockitObject) + fieldCount * sizeof(int64_t));
    obj->typeName = typeName;
    obj->refCount = 1;
    obj->fieldCount = fieldCount;
    obj->ptrFieldBits = 0xFFFFFFFF;  // unknown: release all fields (conservative default)
    // Zero-initialize fields
    for (int32_t i = 0; i < fieldCount; i++) {
        obj->fields[i] = 0;
    }
    return obj;
}

int64_t rockit_object_get_field(RockitObject* obj, int32_t index) {
    if (!obj) {
        rockit_panic("null pointer dereference in field access");
    }
    if (index < 0 || index >= obj->fieldCount) {
        rockit_panic("field index out of bounds");
    }
    return obj->fields[index];
}

void rockit_object_set_field(RockitObject* obj, int32_t index, int64_t value) {
    if (!obj) {
        rockit_panic("null pointer dereference in field set");
    }
    if (index < 0 || index >= obj->fieldCount) {
        rockit_panic("field index out of bounds");
    }
    obj->fields[index] = value;
}

void rockit_retain(RockitObject* obj) {
    if (obj) obj->refCount++;
}

void rockit_release(RockitObject* obj) {
    if (obj && --obj->refCount <= 0) {
        // Cascade: release pointer-typed field values before freeing.
        // If ptrFieldBits is set, only release fields marked as pointers.
        // If ptrFieldBits is 0 (legacy/unknown), release all fields (conservative).
        uint32_t bits = obj->ptrFieldBits;
        if (bits == 0xFFFFFFFF) {
            // Unknown (legacy): conservatively release all fields
            for (int32_t i = 0; i < obj->fieldCount; i++) {
                rockit_release_value(obj->fields[i]);
            }
        } else {
            // Known: only release fields marked as pointers
            for (int32_t i = 0; i < obj->fieldCount && i < 32; i++) {
                if (bits & (1u << i)) {
                    rockit_release_value(obj->fields[i]);
                }
            }
        }
        free(obj);
    }
}

// ── Universal Value ARC ─────────────────────────────────────────────────────
// These functions handle retain/release for any ref-counted value stored as i64.
// Used by write barriers where the compile-time type is unknown.

static int is_likely_heap_ptr(int64_t value) {
    if (value == 0 || value == ROCKIT_NULL) return 0;
    uint64_t uval = (uint64_t)value;
    return (uval > 0x100000000ULL && uval < 0x800000000000ULL);
}

void rockit_retain_value(int64_t val) {
    if (!is_likely_heap_ptr(val)) return;
    void* ptr = (void*)(intptr_t)val;
    // RockitObject has typeName (a pointer) as its first field.
    // String/List/Map have refCount (a small integer) as their first field.
    int64_t first_field = *(int64_t*)ptr;
    if (first_field == ROCKIT_IMMORTAL_REFCOUNT) return;  // immortal string literal
    if (is_likely_heap_ptr(first_field)) {
        // First field is a pointer → RockitObject (typeName is first, refCount is second)
        ((RockitObject*)ptr)->refCount++;
    } else {
        // First field is refCount → String, List, or Map
        (*(int64_t*)ptr)++;
    }
}

void rockit_release_value(int64_t val) {
    if (!is_likely_heap_ptr(val)) return;
    void* ptr = (void*)(intptr_t)val;
    int64_t first_field = *(int64_t*)ptr;
    if (first_field == ROCKIT_IMMORTAL_REFCOUNT) return;  // immortal string literal
    if (is_likely_heap_ptr(first_field)) {
        // RockitObject: refCount is at offset 8
        RockitObject* obj = (RockitObject*)ptr;
        if (--obj->refCount <= 0) {
            // Cascade: release all field values before freeing
            for (int32_t i = 0; i < obj->fieldCount; i++) {
                rockit_release_value(obj->fields[i]);
            }
            free(obj);
        }
    } else {
        // String/List/Map: refCount is at offset 0
        int64_t* refCount = (int64_t*)ptr;
        if (--(*refCount) <= 0) {
            // Check if it has an internal allocation at offset 24 (List data / Map entries).
            // Strings use a flexible array member (inline data), so offset 24 is just string bytes.
            // Lists/Maps have: [refCount:8][size:8][capacity:8][data/entries ptr:8] = 32 bytes fixed.
            // Short strings (length < 16) have allocations < 32 bytes, so offset 24 is OOB.
            // Guard with allocation size check to prevent heap-buffer-overflow.
#ifdef __APPLE__
            size_t alloc_size = malloc_size(ptr);
#else
            size_t alloc_size = 32;  // assume safe on non-Apple (most allocators round up)
#endif
            int64_t potential_ptr = (alloc_size >= 32) ? *((int64_t*)((char*)ptr + 24)) : 0;
            if (is_likely_heap_ptr(potential_ptr)) {
                // Likely a List or Map — cascade release through elements.
                // Read size and capacity from offsets 8 and 16.
                int64_t size = *((int64_t*)((char*)ptr + 8));
                int64_t capacity = *((int64_t*)((char*)ptr + 16));
                int64_t* data = (int64_t*)(intptr_t)potential_ptr;
                // Release elements: for lists, each 8-byte slot is a value.
                // For maps, entries are larger structs but key/value are at predictable offsets.
                // Use size for lists (release size elements) as a safe upper bound.
                if (size > 0 && size <= capacity && capacity < 100000000) {
                    for (int64_t i = 0; i < size; i++) {
                        rockit_release_value(data[i]);
                    }
                }
                free((void*)(intptr_t)potential_ptr);
            }
            free(ptr);
        }
    }
}

// ── Runtime Type Checking ──────────────────────────────────────────────────

static const RockitTypeEntry* g_type_hierarchy = NULL;
static int32_t g_type_hierarchy_count = 0;

void rockit_set_type_hierarchy(const RockitTypeEntry* table, int32_t count) {
    g_type_hierarchy = table;
    g_type_hierarchy_count = count;
}

/// Look up the parent type of `childName` in the hierarchy table.
/// Returns NULL if no parent is found.
static const char* find_parent_type(const char* childName) {
    for (int32_t i = 0; i < g_type_hierarchy_count; i++) {
        if (strcmp(g_type_hierarchy[i].child, childName) == 0) {
            return g_type_hierarchy[i].parent;
        }
    }
    return NULL;
}

int8_t rockit_is_type(RockitObject* obj, const char* targetType) {
    if (!obj) return 0;
    const char* objType = obj->typeName;
    if (!objType) return 0;
    // Walk up the hierarchy: check objType, then its parent, grandparent, etc.
    const char* current = objType;
    while (current != NULL) {
        if (strcmp(current, targetType) == 0) return 1;
        current = find_parent_type(current);
    }
    return 0;
}

const char* rockit_object_get_type_name(RockitObject* obj) {
    if (!obj) return NULL;
    return obj->typeName;
}

int64_t rockit_object_is_type(RockitObject* obj, const char* typeName) {
    if (!obj || !typeName) return 0;
    return strcmp(obj->typeName, typeName) == 0 ? 1 : 0;
}

// ── RockitList ──────────────────────────────────────────────────────────────

RockitList* rockit_list_create(void) {
    RockitList* list = (RockitList*)malloc(sizeof(RockitList));
    list->refCount = 1;
    list->size = 0;
    list->capacity = 8;
    list->data = (int64_t*)malloc(8 * sizeof(int64_t));
    return list;
}

void rockit_list_append(RockitList* list, int64_t value) {
    rockit_retain_value(value);
    if (list->size >= list->capacity) {
        list->capacity *= 2;
        list->data = (int64_t*)realloc(list->data, list->capacity * sizeof(int64_t));
    }
    list->data[list->size++] = value;
}

int64_t rockit_list_get(RockitList* list, int64_t index) {
    if (index < 0 || index >= list->size) {
        rockit_panic("list index out of bounds");
    }
    return list->data[index];
}

void rockit_list_set(RockitList* list, int64_t index, int64_t value) {
    if (index < 0 || index >= list->size) {
        rockit_panic("list index out of bounds");
    }
    rockit_retain_value(value);
    rockit_release_value(list->data[index]);
    list->data[index] = value;
}

int64_t rockit_list_size(RockitList* list) {
    return list ? list->size : 0;
}

int8_t rockit_list_is_empty(RockitList* list) {
    return !list || list->size == 0;
}

void rockit_list_release(RockitList* list) {
    if (list && --list->refCount <= 0) {
        // Cascade: release all elements before freeing
        for (int64_t i = 0; i < list->size; i++) {
            rockit_release_value(list->data[i]);
        }
        free(list->data);
        free(list);
    }
}

int8_t rockit_list_contains(RockitList* list, int64_t value) {
    if (!list) return 0;
    for (int64_t i = 0; i < list->size; i++) {
        if (list->data[i] == value) return 1;
    }
    return 0;
}

int64_t rockit_list_remove_at(RockitList* list, int64_t index) {
    if (!list || index < 0 || index >= list->size) return 0;
    int64_t removed = list->data[index];
    for (int64_t i = index; i < list->size - 1; i++) {
        list->data[i] = list->data[i + 1];
    }
    list->size--;
    return removed;
}

// ── RockitMap ───────────────────────────────────────────────────────────────

RockitMap* rockit_map_create(void) {
    RockitMap* map = (RockitMap*)malloc(sizeof(RockitMap));
    map->refCount = 1;
    map->size = 0;
    map->capacity = 16;
    map->entries = (RockitMapEntry*)calloc(16, sizeof(RockitMapEntry));
    return map;
}

static int64_t map_hash(int64_t key, int64_t capacity) {
    // Simple hash — works for ints, pointers cast to int
    uint64_t h = (uint64_t)key;
    h ^= h >> 33;
    h *= 0xff51afd7ed558ccd;
    h ^= h >> 33;
    return (int64_t)(h % (uint64_t)capacity);
}

static void map_grow(RockitMap* map) {
    int64_t oldCap = map->capacity;
    RockitMapEntry* oldEntries = map->entries;
    map->capacity *= 2;
    map->entries = (RockitMapEntry*)calloc(map->capacity, sizeof(RockitMapEntry));
    map->size = 0;
    for (int64_t i = 0; i < oldCap; i++) {
        if (oldEntries[i].occupied) {
            int64_t idx = map_hash(oldEntries[i].key, map->capacity);
            while (map->entries[idx].occupied) {
                idx = (idx + 1) % map->capacity;
            }
            map->entries[idx].key = oldEntries[i].key;
            map->entries[idx].value = oldEntries[i].value;
            map->entries[idx].occupied = 1;
            map->size++;
        }
    }
    free(oldEntries);
}

void rockit_map_put(RockitMap* map, int64_t key, int64_t value) {
    if (map->size * 2 >= map->capacity) {
        map_grow(map);
    }
    int64_t idx = map_hash(key, map->capacity);
    while (map->entries[idx].occupied) {
        if (map->entries[idx].key == key) {
            rockit_retain_value(value);
            rockit_release_value(map->entries[idx].value);
            map->entries[idx].value = value;
            return;
        }
        idx = (idx + 1) % map->capacity;
    }
    rockit_retain_value(key);
    rockit_retain_value(value);
    map->entries[idx].key = key;
    map->entries[idx].value = value;
    map->entries[idx].occupied = 1;
    map->size++;
}

int64_t rockit_map_get(RockitMap* map, int64_t key) {
    int64_t idx = map_hash(key, map->capacity);
    int64_t start = idx;
    while (map->entries[idx].occupied) {
        if (map->entries[idx].key == key) {
            return map->entries[idx].value;
        }
        idx = (idx + 1) % map->capacity;
        if (idx == start) break;
    }
    rockit_panic("map key not found");
    return 0;
}

int8_t rockit_map_contains_key(RockitMap* map, int64_t key) {
    int64_t idx = map_hash(key, map->capacity);
    int64_t start = idx;
    while (map->entries[idx].occupied) {
        if (map->entries[idx].key == key) return 1;
        idx = (idx + 1) % map->capacity;
        if (idx == start) break;
    }
    return 0;
}

int64_t rockit_map_size(RockitMap* map) {
    return map ? map->size : 0;
}

int8_t rockit_map_is_empty(RockitMap* map) {
    return !map || map->size == 0;
}

void rockit_map_release(RockitMap* map) {
    if (map && --map->refCount <= 0) {
        // Cascade: release all occupied entries before freeing
        for (int64_t i = 0; i < map->capacity; i++) {
            if (map->entries[i].occupied) {
                rockit_release_value(map->entries[i].key);
                rockit_release_value(map->entries[i].value);
            }
        }
        free(map->entries);
        free(map);
    }
}

RockitList* rockit_map_keys(RockitMap* map) {
    RockitList* list = rockit_list_create();
    if (!map) return list;
    for (int64_t i = 0; i < map->capacity; i++) {
        if (map->entries[i].occupied) {
            rockit_list_append(list, map->entries[i].key);
        }
    }
    return list;
}

RockitList* rockit_map_values(RockitMap* map) {
    RockitList* list = rockit_list_create();
    if (!map) return list;
    for (int64_t i = 0; i < map->capacity; i++) {
        if (map->entries[i].occupied) {
            rockit_list_append(list, map->entries[i].value);
        }
    }
    return list;
}

void rockit_map_remove(RockitMap* map, int64_t key) {
    if (!map || map->size == 0) return;
    uint64_t h = ((uint64_t)key * 2654435761ULL) % (uint64_t)map->capacity;
    uint64_t start = h;
    while (map->entries[h].occupied) {
        if (map->entries[h].key == key) {
            map->entries[h].occupied = 0;
            rockit_release_value(map->entries[h].key);
            rockit_release_value(map->entries[h].value);
            map->size--;
            return;
        }
        h = (h + 1) % (uint64_t)map->capacity;
        if (h == start) break;
    }
}

// ── I/O ─────────────────────────────────────────────────────────────────────

void rockit_println_int(int64_t value) {
    printf("%lld\n", (long long)value);
}

void rockit_println_float(double value) {
    char buf[64];
    snprintf(buf, sizeof(buf), "%g", value);
    // Ensure at least one decimal place (match VM behavior: 4 → "4.0")
    if (!strchr(buf, '.') && !strchr(buf, 'e') && !strchr(buf, 'E')) {
        printf("%s.0\n", buf);
    } else {
        printf("%s\n", buf);
    }
}

void rockit_println_bool(int8_t value) {
    printf("%s\n", value ? "true" : "false");
}

void rockit_println_string(RockitString* s) {
    if (s) {
        printf("%s\n", s->data);
    } else {
        printf("null\n");
    }
}

void rockit_println_null(void) {
    printf("null\n");
}

void rockit_print_int(int64_t value) {
    printf("%lld", (long long)value);
}

void rockit_print_float(double value) {
    char buf[64];
    snprintf(buf, sizeof(buf), "%g", value);
    if (!strchr(buf, '.') && !strchr(buf, 'e') && !strchr(buf, 'E')) {
        printf("%s.0", buf);
    } else {
        printf("%s", buf);
    }
}

void rockit_print_bool(int8_t value) {
    printf("%s", value ? "true" : "false");
}

void rockit_print_string(RockitString* s) {
    if (s) {
        printf("%s", s->data);
    } else {
        printf("null");
    }
}

// ── Dynamic print (handles both string pointers and integer values) ──────

static int is_likely_string_ptr(int64_t value) {
    if (value == 0) return 0;
    uint64_t uval = (uint64_t)value;
    if (uval > 0x100000000ULL && uval < 0x800000000000ULL) {
        RockitString* s = (RockitString*)(intptr_t)value;
        if (((s->refCount > 0 && s->refCount < 100000) || s->refCount == ROCKIT_IMMORTAL_REFCOUNT) &&
            s->length >= 0 && s->length < 10000000) {
            return 1;
        }
    }
    return 0;
}

void rockit_println_any(int64_t value) {
    if (value == ROCKIT_NULL) {
        printf("null\n");
    } else if (value == 0) {
        printf("0\n");
    } else if (is_likely_string_ptr(value)) {
        RockitString* s = (RockitString*)(intptr_t)value;
        printf("%s\n", s->data);
    } else {
        printf("%lld\n", (long long)value);
    }
}

void rockit_print_any(int64_t value) {
    if (value == ROCKIT_NULL) {
        printf("null");
    } else if (value == 0) {
        printf("0");
    } else if (is_likely_string_ptr(value)) {
        RockitString* s = (RockitString*)(intptr_t)value;
        printf("%s", s->data);
    } else {
        printf("%lld", (long long)value);
    }
}

void rockit_println_double(double value) {
    char buf[64];
    snprintf(buf, sizeof(buf), "%g", value);
    printf("%s\n", buf);
}

void rockit_print_double(double value) {
    char buf[64];
    snprintf(buf, sizeof(buf), "%g", value);
    printf("%s", buf);
}

RockitString* rockit_double_to_string(double value) {
    char buf[64];
    snprintf(buf, sizeof(buf), "%g", value);
    return rockit_string_new(buf);
}

// ── Conversion ──────────────────────────────────────────────────────────────

RockitString* rockit_int_to_string(int64_t value) {
    char buf[32];
    snprintf(buf, sizeof(buf), "%lld", (long long)value);
    return rockit_string_new(buf);
}

RockitString* rockit_float_to_string(double value) {
    char buf[64];
    snprintf(buf, sizeof(buf), "%g", value);
    if (!strchr(buf, '.') && !strchr(buf, 'e') && !strchr(buf, 'E')) {
        strncat(buf, ".0", sizeof(buf) - strlen(buf) - 1);
    }
    return rockit_string_new(buf);
}

RockitString* rockit_bool_to_string(int8_t value) {
    return rockit_string_new(value ? "true" : "false");
}

// ── Exception Handling ──────────────────────────────────────────────────────

static jmp_buf rockit_exc_bufs[ROCKIT_MAX_EXC_DEPTH];
static int64_t rockit_exc_values[ROCKIT_MAX_EXC_DEPTH];
static int32_t rockit_exc_depth = 0;

void* rockit_exc_push(void) {
    if (rockit_exc_depth >= ROCKIT_MAX_EXC_DEPTH) {
        rockit_panic("try nesting too deep");
    }
    return (void*)&rockit_exc_bufs[rockit_exc_depth++];
}

void rockit_exc_pop(void) {
    if (rockit_exc_depth > 0) rockit_exc_depth--;
}

void rockit_exc_throw(int64_t value) {
    if (rockit_exc_depth <= 0) {
        // Uncaught exception — panic with a message
        fprintf(stderr, "PANIC: uncaught exception\n");
        exit(1);
    }
    int32_t idx = --rockit_exc_depth;
    rockit_exc_values[idx] = value;
    longjmp(rockit_exc_bufs[idx], 1);
}

int64_t rockit_exc_get(void) {
    // After throw, depth was decremented, so the value is at current depth
    return rockit_exc_values[rockit_exc_depth];
}

// ── Process ─────────────────────────────────────────────────────────────────

void rockit_panic(const char* message) {
    fprintf(stderr, "PANIC: %s\n", message);
    exit(1);
}

// ── String Comparison ────────────────────────────────────────────────────────

int8_t rockit_string_eq(int64_t a, int64_t b) {
    if (a == b) return 1;  // Same pointer, same integer, or both null sentinel
    // Null sentinel is only equal to itself (handled above)
    if (a == ROCKIT_NULL || b == ROCKIT_NULL) return 0;
    if (a == 0 || b == 0) return 0;
    // Both must look like valid string pointers for content comparison
    if (!is_likely_string_ptr(a) || !is_likely_string_ptr(b)) return 0;
    RockitString* sa = (RockitString*)(intptr_t)a;
    RockitString* sb = (RockitString*)(intptr_t)b;
    if (sa->length != sb->length) return 0;
    return memcmp(sa->data, sb->data, sa->length) == 0;
}

int8_t rockit_string_neq(int64_t a, int64_t b) {
    return !rockit_string_eq(a, b);
}

// ── Builtin Wrappers ────────────────────────────────────────────────────────
// These are called directly by LLVM IR generated from Rockit source.
// Stage 1 stores all values as i64 (pointers cast to int64_t).
// These wrappers bridge between the i64 ABI and the typed C runtime.

// -- String operations --

RockitString* charAt(RockitString* s, int64_t index) {
    if (!s || index < 0 || index >= s->length) {
        return rockit_string_new("");
    }
    char buf[2] = { s->data[index], '\0' };
    return rockit_string_new(buf);
}

int64_t charCodeAt(RockitString* s, int64_t index) {
    if (!s || index < 0 || index >= s->length) return 0;
    return (int64_t)(unsigned char)s->data[index];
}

int8_t startsWith(RockitString* s, RockitString* prefix) {
    if (!s || !prefix) return 0;
    if (prefix->length > s->length) return 0;
    return memcmp(s->data, prefix->data, prefix->length) == 0;
}

int8_t endsWith(RockitString* s, RockitString* suffix) {
    if (!s || !suffix) return 0;
    if (suffix->length > s->length) return 0;
    return memcmp(s->data + s->length - suffix->length, suffix->data, suffix->length) == 0;
}

RockitString* stringConcat(RockitString* a, RockitString* b) {
    return rockit_string_concat(a, b);
}

int64_t stringIndexOf(RockitString* s, RockitString* needle) {
    if (!s || !needle) return -1;
    char* found = strstr(s->data, needle->data);
    if (!found) return -1;
    return (int64_t)(found - s->data);
}

int64_t stringLength(RockitString* s) {
    return s ? s->length : 0;
}

RockitString* stringTrim(RockitString* s) {
    if (!s || s->length == 0) return rockit_string_new("");
    int64_t start = 0;
    while (start < s->length && (s->data[start] == ' ' || s->data[start] == '\t' ||
           s->data[start] == '\n' || s->data[start] == '\r')) start++;
    int64_t end = s->length - 1;
    while (end > start && (s->data[end] == ' ' || s->data[end] == '\t' ||
           s->data[end] == '\n' || s->data[end] == '\r')) end--;
    int64_t len = end - start + 1;
    RockitString* result = (RockitString*)malloc(sizeof(RockitString) + len + 1);
    result->refCount = 1;
    result->length = len;
    memcpy(result->data, s->data + start, len);
    result->data[len] = '\0';
    return result;
}

RockitString* substring(RockitString* s, int64_t start, int64_t end) {
    if (!s) return rockit_string_new("");
    if (start < 0) start = 0;
    if (end > s->length) end = s->length;
    if (start >= end) return rockit_string_new("");
    int64_t len = end - start;
    RockitString* result = (RockitString*)malloc(sizeof(RockitString) + len + 1);
    result->refCount = 1;
    result->length = len;
    memcpy(result->data, s->data + start, len);
    result->data[len] = '\0';
    return result;
}

int64_t toInt(int64_t value) {
    // If the value looks like a string pointer, parse the string as an integer.
    // Otherwise return the value as-is (it's already an integer).
    if (value == ROCKIT_NULL) return 0;
    if (value == 0) return 0;
    if (is_likely_string_ptr(value)) {
        RockitString* s = (RockitString*)(intptr_t)value;
        return strtoll(s->data, NULL, 10);
    }
    return value;
}

// -- Character checks --

int8_t isDigit(RockitString* ch) {
    if (!ch || ch->length == 0) return 0;
    char c = ch->data[0];
    return c >= '0' && c <= '9';
}

int8_t isLetter(RockitString* ch) {
    if (!ch || ch->length == 0) return 0;
    char c = ch->data[0];
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_';
}

int8_t isLetterOrDigit(RockitString* ch) {
    if (!ch || ch->length == 0) return 0;
    char c = ch->data[0];
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_';
}

// -- Type checks --

int8_t isMap(int64_t val) {
    // In the VM, maps are tagged values. In native, we treat non-null as "is a map"
    // when used in Stage 1 context. This is a heuristic — Stage 1 uses isMap to check
    // if an AST node is a map (non-null pointer).
    return val != 0 && val != ROCKIT_NULL;
}

// -- List operations (i64 wrapper API) --

int64_t listCreate(void) {
    return (int64_t)(intptr_t)rockit_list_create();
}

void listAppend(int64_t list, int64_t value) {
    rockit_list_append((RockitList*)(intptr_t)list, value);
}

int64_t listGet(int64_t list, int64_t index) {
    return rockit_list_get((RockitList*)(intptr_t)list, index);
}

void listSet(int64_t list, int64_t index, int64_t value) {
    rockit_list_set((RockitList*)(intptr_t)list, index, value);
}

int64_t listSize(int64_t list) {
    return rockit_list_size((RockitList*)(intptr_t)list);
}

int8_t listContains(int64_t list, int64_t value) {
    RockitList* l = (RockitList*)(intptr_t)list;
    if (!l) return 0;
    for (int64_t i = 0; i < l->size; i++) {
        if (l->data[i] == value) return 1;
    }
    return 0;
}

int64_t listRemoveAt(int64_t list, int64_t index) {
    RockitList* l = (RockitList*)(intptr_t)list;
    if (!l || index < 0 || index >= l->size) return ROCKIT_NULL;
    int64_t removed = l->data[index];
    for (int64_t i = index; i < l->size - 1; i++) {
        l->data[i] = l->data[i + 1];
    }
    l->size--;
    return removed;
}

// -- Map operations (i64 wrapper API) --

int64_t mapCreate(void);  // defined after mapCreate_string below

// String-keyed map — hash by string content, not pointer address
static uint64_t string_hash(RockitString* s) {
    if (!s) return 0;
    uint64_t h = 14695981039346656037ULL;
    for (int64_t i = 0; i < s->length; i++) {
        h ^= (unsigned char)s->data[i];
        h *= 1099511628211ULL;
    }
    return h;
}

static int8_t string_eq(RockitString* a, RockitString* b) {
    if (a == b) return 1;
    if (!a || !b) return 0;
    if (a->length != b->length) return 0;
    return memcmp(a->data, b->data, a->length) == 0;
}

// Stage 1 maps use RockitString* keys. We need string-content-based hashing.
// The rockit_map_* functions use integer hashing on raw pointer values, which
// won't work for string keys. So mapGet/mapPut use a separate implementation.

typedef struct StringMapEntry {
    RockitString* key;
    int64_t value;
    int8_t occupied;
} StringMapEntry;

typedef struct StringMap {
    int64_t refCount;
    int64_t size;
    int64_t capacity;
    StringMapEntry* entries;
} StringMap;

static void smap_grow(StringMap* map);

int64_t mapCreate_string(void) {
    StringMap* map = (StringMap*)malloc(sizeof(StringMap));
    map->refCount = 1;
    map->size = 0;
    map->capacity = 16;
    map->entries = (StringMapEntry*)calloc(16, sizeof(StringMapEntry));
    return (int64_t)(intptr_t)map;
}

// mapCreate creates a string-keyed map (StringMap), used by Stage 1
int64_t mapCreate(void) {
    return mapCreate_string();
}

int64_t mapPut(int64_t mapVal, RockitString* key, int64_t value) {
    StringMap* map = (StringMap*)(intptr_t)mapVal;
    if (!map || !key || !map->entries) return 0;
    if (map->size * 2 >= map->capacity) {
        smap_grow(map);
    }
    uint64_t h = string_hash(key) % (uint64_t)map->capacity;
    while (map->entries[h].occupied) {
        if (string_eq(map->entries[h].key, key)) {
            rockit_retain_value(value);
            rockit_release_value(map->entries[h].value);
            map->entries[h].value = value;
            return 0;
        }
        h = (h + 1) % (uint64_t)map->capacity;
    }
    rockit_string_retain(key);
    rockit_retain_value(value);
    map->entries[h].key = key;
    map->entries[h].value = value;
    map->entries[h].occupied = 1;
    map->size++;
    return 0;
}

int64_t mapGet(int64_t mapVal, RockitString* key) {
    StringMap* map = (StringMap*)(intptr_t)mapVal;
    if (!map || !key || !map->entries) return ROCKIT_NULL;
    uint64_t h = string_hash(key) % (uint64_t)map->capacity;
    uint64_t start = h;
    while (map->entries[h].occupied) {
        if (string_eq(map->entries[h].key, key)) {
            return map->entries[h].value;
        }
        h = (h + 1) % (uint64_t)map->capacity;
        if (h == start) break;
    }
    return ROCKIT_NULL;  // Not found — return null sentinel
}

int64_t mapKeys(int64_t mapVal) {
    StringMap* map = (StringMap*)(intptr_t)mapVal;
    int64_t list = listCreate();
    if (!map) return list;
    for (int64_t i = 0; i < map->capacity; i++) {
        if (map->entries[i].occupied) {
            listAppend(list, (int64_t)(intptr_t)map->entries[i].key);
        }
    }
    return list;
}

static void smap_grow(StringMap* map) {
    int64_t oldCap = map->capacity;
    StringMapEntry* oldEntries = map->entries;
    map->capacity *= 2;
    map->entries = (StringMapEntry*)calloc(map->capacity, sizeof(StringMapEntry));
    map->size = 0;
    for (int64_t i = 0; i < oldCap; i++) {
        if (oldEntries[i].occupied) {
            uint64_t h = string_hash(oldEntries[i].key) % (uint64_t)map->capacity;
            while (map->entries[h].occupied) {
                h = (h + 1) % (uint64_t)map->capacity;
            }
            map->entries[h].key = oldEntries[i].key;
            map->entries[h].value = oldEntries[i].value;
            map->entries[h].occupied = 1;
            map->size++;
        }
    }
    free(oldEntries);
}

// -- I/O operations --

RockitString* readLine(void) {
    char buf[4096];
    if (fgets(buf, sizeof(buf), stdin)) {
        // Strip trailing newline
        size_t len = strlen(buf);
        if (len > 0 && buf[len - 1] == '\n') buf[len - 1] = '\0';
        return rockit_string_new(buf);
    }
    return rockit_string_new("");
}

int8_t fileExists(RockitString* path) {
    if (!path) return 0;
    FILE* f = fopen(path->data, "r");
    if (f) { fclose(f); return 1; }
    return 0;
}

RockitString* fileRead(RockitString* path) {
    if (!path) return rockit_string_new("");
    FILE* f = fopen(path->data, "rb");
    if (!f) return rockit_string_new("");
    fseek(f, 0, SEEK_END);
    long size = ftell(f);
    fseek(f, 0, SEEK_SET);
    char* buf = (char*)malloc(size + 1);
    size_t read = fread(buf, 1, size, f);
    buf[read] = '\0';
    fclose(f);
    RockitString* result = rockit_string_new(buf);
    free(buf);
    return result;
}

int64_t fileWriteBytes(RockitString* path, int64_t bytesListVal) {
    if (!path) return 0;
    RockitList* bytes = (RockitList*)(intptr_t)bytesListVal;
    if (!bytes) return 0;
    FILE* f = fopen(path->data, "wb");
    if (!f) return 0;
    for (int64_t i = 0; i < bytes->size; i++) {
        uint8_t b = (uint8_t)(bytes->data[i] & 0xFF);
        fwrite(&b, 1, 1, f);
    }
    fclose(f);
    return bytes->size;
}

// -- Process operations --

static int s_argc = 0;
static char** s_argv = NULL;

void rockit_set_args(int argc, char** argv) {
    s_argc = argc;
    s_argv = argv;
}

int64_t processArgs(void) {
    int64_t list = listCreate();
    // Skip argv[0] (binary name) — return user arguments only
    for (int i = 1; i < s_argc; i++) {
        RockitString* s = rockit_string_new(s_argv[i]);
        listAppend(list, (int64_t)(intptr_t)s);
    }
    return list;
}

// -- Meta --

int64_t evalRockit(RockitString* source) {
    // evalRockit is a VM-specific feature — in native mode it's a no-op
    fprintf(stderr, "warning: evalRockit is not supported in native mode\n");
    return 0;
}

// -- Shell execution (used by Stage 1 build-native) --

int64_t systemExec(RockitString* cmd) {
    if (!cmd) return -1;
    return (int64_t)system(cmd->data);
}

// -- File deletion (cross-platform, replaces shell `rm -f`) --

int64_t fileDelete(RockitString* path) {
    if (!path) return 0;
    return remove(path->data) == 0 ? 1 : 0;
}

// -- toString wrapper (used by Stage 1) --

RockitString* toString(int64_t value) {
    // In Stage 1, toString is called on various values.
    // If the value looks like a pointer to a RockitString, return it.
    // Otherwise convert the integer to string.
    if (value == ROCKIT_NULL) return rockit_string_new("null");
    if (value == 0) return rockit_int_to_string(value);  // integer 0, not null
    if (is_likely_string_ptr(value)) {
        RockitString* s = (RockitString*)(intptr_t)value;
        return s;
    }
    return rockit_int_to_string(value);
}

// -- floatToString (used by float codegen) --

RockitString* floatToString(double value) {
    char buf[64];
    snprintf(buf, sizeof(buf), "%g", value);
    return rockit_string_new(buf);
}

// ── Actor Runtime (Stage 0 — synchronous) ──────────────────────────────

RockitActor* rockit_actor_create(const char* typeName, int32_t fieldCount) {
    RockitActor* actor = (RockitActor*)malloc(sizeof(RockitActor));
    actor->object = rockit_object_alloc(typeName, fieldCount);
    return actor;
}

RockitObject* rockit_actor_get_object(RockitActor* actor) {
    if (!actor) {
        rockit_panic("null actor dereference");
    }
    return actor->object;
}

void rockit_actor_release(RockitActor* actor) {
    if (actor) {
        rockit_release(actor->object);
        free(actor);
    }
}

// ── Async Runtime (Cooperative Task Scheduler) ──────────────────────────────

#define ROCKIT_COROUTINE_SUSPENDED ((int64_t)-9999)
#define ROCKIT_TASK_QUEUE_CAPACITY 4096

typedef struct {
    int64_t (*resume)(void* frame, int64_t result);
    void*   frame;
    int64_t result;
} RockitTask;

static struct {
    RockitTask tasks[ROCKIT_TASK_QUEUE_CAPACITY];
    int32_t head;
    int32_t tail;
    int32_t count;
} g_scheduler = {0};

void rockit_task_schedule(void* resume_fn, void* frame, int64_t result) {
    if (g_scheduler.count >= ROCKIT_TASK_QUEUE_CAPACITY) {
        fprintf(stderr, "rockit: task queue overflow\n");
        exit(1);
    }
    RockitTask* t = &g_scheduler.tasks[g_scheduler.tail];
    t->resume = (int64_t (*)(void*, int64_t))resume_fn;
    t->frame = frame;
    t->result = result;
    g_scheduler.tail = (g_scheduler.tail + 1) % ROCKIT_TASK_QUEUE_CAPACITY;
    g_scheduler.count++;
}

// Frame header: first fields of every continuation frame
// Layout as i64 array: [0]=state, [1]=parent_resume, [2]=parent_frame, [3]=join_counter
typedef struct {
    int64_t state;
    int64_t (*parent_resume)(void*, int64_t);
    void*   parent_frame;
    int64_t join_counter;
} RockitFrameHeader;

void* rockit_frame_alloc(int64_t size_bytes) {
    void* frame = calloc(1, (size_t)size_bytes);
    return frame;
}

void rockit_frame_free(void* frame) {
    free(frame);
}

int64_t rockit_await(void* child_resume_fn, void* child_frame,
                     void* parent_resume_fn, void* parent_frame) {
    // Set up parent continuation in child's frame header
    RockitFrameHeader* child_hdr = (RockitFrameHeader*)child_frame;
    child_hdr->parent_resume = (int64_t (*)(void*, int64_t))parent_resume_fn;
    child_hdr->parent_frame = parent_frame;
    // Schedule the child task
    rockit_task_schedule(child_resume_fn, child_frame, 0);
    return ROCKIT_COROUTINE_SUSPENDED;
}

void rockit_run_event_loop(void) {
    while (g_scheduler.count > 0) {
        RockitTask task = g_scheduler.tasks[g_scheduler.head];
        g_scheduler.head = (g_scheduler.head + 1) % ROCKIT_TASK_QUEUE_CAPACITY;
        g_scheduler.count--;

        int64_t ret = task.resume(task.frame, task.result);

        if (ret != ROCKIT_COROUTINE_SUSPENDED) {
            // Task completed — resume parent if one exists
            RockitFrameHeader* hdr = (RockitFrameHeader*)task.frame;
            if (hdr->parent_resume) {
                // Decrement parent's join counter
                RockitFrameHeader* parent_hdr = (RockitFrameHeader*)hdr->parent_frame;
                if (parent_hdr->join_counter > 0) {
                    parent_hdr->join_counter--;
                }
                rockit_task_schedule(
                    (void*)hdr->parent_resume,
                    hdr->parent_frame,
                    ret
                );
            }
            rockit_frame_free(task.frame);
        }
    }
}

int64_t rockit_is_suspended(int64_t value) {
    return value == ROCKIT_COROUTINE_SUSPENDED;
}

// ── Math Functions ──────────────────────────────────────────────────────────

double rockit_math_sqrt(double x)  { return sqrt(x); }
double rockit_math_sin(double x)   { return sin(x); }
double rockit_math_cos(double x)   { return cos(x); }
double rockit_math_tan(double x)   { return tan(x); }
double rockit_math_pow(double base, double exp) { return pow(base, exp); }
double rockit_math_floor(double x) { return floor(x); }
double rockit_math_ceil(double x)  { return ceil(x); }
double rockit_math_round(double x) { return round(x); }
double rockit_math_log(double x)   { return log(x); }
double rockit_math_exp(double x)   { return exp(x); }
double rockit_math_abs(double x)   { return fabs(x); }
double rockit_math_atan2(double y, double x) { return atan2(y, x); }
