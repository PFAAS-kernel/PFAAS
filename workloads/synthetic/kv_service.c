#include "common.h"
#include <stdio.h>
static const char *table[] = {"alpha", "beta", "gamma"};
__attribute__((annotate("pfaas.owner=kv_service")))
int main(void) { printf("KV %s %u\n", table[shared_hash("key") % 3], shared_hash("key")); }
