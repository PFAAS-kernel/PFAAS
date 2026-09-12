#include "common.h"
#include <stdio.h>
static unsigned requests = 100;
__attribute__((annotate("pfaas.owner=metrics_service")))
int main(void) { printf("metric_requests %u hash=%u\n", ++requests, shared_hash("requests")); }
