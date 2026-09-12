#include "common.h"
#include <stdio.h>
#include <stdlib.h>
static int app_global = 17;
static int equivalent_sum(int a, int b) { return a + b; }
__attribute__((annotate("pfaas.owner=http_service_A")))
int main(void) { char *p = copy_payload("GET /a"); printf("A %u %d %s\n", shared_hash(p), equivalent_sum(app_global, 25), p); free(p); }
