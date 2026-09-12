#pragma once
#include <stddef.h>
typedef struct AppContext {
  int *fd_namespace;
  char **environment;
  char *cwd;
  void *allocator_state;
  unsigned uid, gid;
  void *logical_globals;
  void *signal_event_state;
} AppContext;
