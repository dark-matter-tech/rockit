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

// ── Process ─────────────────────────────────────────────────────────────────

void rockit_panic(const char* message) {
    fprintf(stderr, "PANIC: %s\n", message);
    exit(1);
}
