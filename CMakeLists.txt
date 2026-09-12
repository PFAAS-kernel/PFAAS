cmake_minimum_required(VERSION 3.20)
project(pfaas_lab LANGUAGES C CXX)

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
add_compile_options(-ffile-prefix-map=${CMAKE_SOURCE_DIR}=. -fdebug-prefix-map=${CMAKE_SOURCE_DIR}=.)
add_link_options(-Wl,--build-id=none)

add_library(common STATIC workloads/synthetic/common.c)
foreach(app IN ITEMS http_service_A http_service_B kv_service metrics_service)
  add_executable(${app} workloads/synthetic/${app}.c)
  target_link_libraries(${app} PRIVATE common)
endforeach()

add_subdirectory(compiler/passes)
