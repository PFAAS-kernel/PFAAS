#include "common.h"
#include <stdlib.h>
#include <string.h>

uint32_t shared_hash(const char *text) {
  uint32_t h = 2166136261u;
  for (; *text; ++text) h = (h ^ (unsigned char)*text) * 16777619u;
  return h;
}
int parse_decimal(const char *text) { int n = 0; while (*text >= '0' && *text <= '9') n = n * 10 + (*text++ - '0'); return n; }
char *copy_payload(const char *text) { size_t n = strlen(text) + 1; char *p = malloc(n); return p ? memcpy(p, text, n) : NULL; }
int dead_feature(void) { return 0x5eed; }
