#include "common.h"
#include <stdio.h>
static int app_global = 29;
static int equivalent_sum(int a, int b) { int result = b; result += a; return result; }
__attribute__((annotate("pfaas.owner=http_service_B")))
int main(void) { printf("B %u %d %d\n", shared_hash("GET /b"), equivalent_sum(app_global, 13), parse_decimal("2048")); }
