#pragma once
#include <stddef.h>
#include <stdint.h>

uint32_t shared_hash(const char *text);
int parse_decimal(const char *text);
char *copy_payload(const char *text);
int dead_feature(void);
