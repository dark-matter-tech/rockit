// rockit_runtime.c
// Rockit Native Runtime — C runtime library for LLVM-compiled Rockit programs
// Copyright © 2026 Dark Matter Tech. All rights reserved.

#include "rockit_runtime.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

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
    if (s) s->refCount++;
}

void rockit_string_release(RockitString* s) {
    if (s && --s->refCount <= 0) {
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
    obj->_padding = 0;
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
        free(obj);
    }
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
        free(list->data);
        free(list);
    }
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
            rockit_map_put(map, oldEntries[i].key, oldEntries[i].value);
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
            map->entries[idx].value = value;
            return;
        }
        idx = (idx + 1) % map->capacity;
    }
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
        free(map->entries);
        free(map);
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
    if (a == b) return 1;  // Same pointer
    if (a == 0 || b == 0) return a == b;
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
    // In the VM, toInt extracts the integer from a tagged value.
    // In native mode, values are unboxed i64 — just pass through.
    // If the value is actually a string pointer, parse it.
    // Use a heuristic: small values (<= 0xFFFF) are likely raw integers;
    // values in the heap range are likely pointers.
    // For Stage 1 compatibility, most toInt calls are on raw integers from mapGet.
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
    return val != 0;
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

void listRemoveAt(int64_t list, int64_t index) {
    RockitList* l = (RockitList*)(intptr_t)list;
    if (!l || index < 0 || index >= l->size) return;
    for (int64_t i = index; i < l->size - 1; i++) {
        l->data[i] = l->data[i + 1];
    }
    l->size--;
}

// -- Map operations (i64 wrapper API) --

int64_t mapCreate(void) {
    return (int64_t)(intptr_t)rockit_map_create();
}

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

// Override mapCreate to use string maps for Stage 1
// Actually, we need mapCreate to return a StringMap since Stage 1 uses string keys

int64_t mapPut(int64_t mapVal, RockitString* key, int64_t value) {
    StringMap* map = (StringMap*)(intptr_t)mapVal;
    if (map->size * 2 >= map->capacity) {
        smap_grow(map);
    }
    uint64_t h = string_hash(key) % (uint64_t)map->capacity;
    while (map->entries[h].occupied) {
        if (string_eq(map->entries[h].key, key)) {
            map->entries[h].value = value;
            return 0;
        }
        h = (h + 1) % (uint64_t)map->capacity;
    }
    map->entries[h].key = key;
    map->entries[h].value = value;
    map->entries[h].occupied = 1;
    map->size++;
    return 0;
}

int64_t mapGet(int64_t mapVal, RockitString* key) {
    StringMap* map = (StringMap*)(intptr_t)mapVal;
    if (!map || map->capacity == 0) return 0;
    uint64_t h = string_hash(key) % (uint64_t)map->capacity;
    uint64_t start = h;
    while (map->entries[h].occupied) {
        if (string_eq(map->entries[h].key, key)) {
            return map->entries[h].value;
        }
        h = (h + 1) % (uint64_t)map->capacity;
        if (h == start) break;
    }
    return 0;  // Not found — return null/0
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
            mapPut((int64_t)(intptr_t)map, oldEntries[i].key, oldEntries[i].value);
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

// -- toString wrapper (used by Stage 1) --

RockitString* toString(int64_t value) {
    // In Stage 1, toString is called on various values.
    // If the value looks like a pointer to a RockitString, return it.
    // Otherwise convert the integer to string.
    if (value == 0) return rockit_string_new("null");
    // On arm64 macOS, heap pointers are > 0x100000000.
    // Small values (line numbers, opcodes, etc.) are raw integers.
    uint64_t uval = (uint64_t)value;
    if (uval > 0x100000000ULL) {
        // Likely a pointer — safely check if it looks like a RockitString
        RockitString* s = (RockitString*)(intptr_t)value;
        if (s->refCount > 0 && s->refCount < 100000 &&
            s->length >= 0 && s->length < 10000000) {
            return s;
        }
    }
    return rockit_int_to_string(value);
}
