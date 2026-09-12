find_package(LLVM REQUIRED CONFIG)
message(STATUS "Using LLVM ${LLVM_PACKAGE_VERSION}")

add_library(PfaasInventory MODULE InventoryPass.cpp)
target_include_directories(PfaasInventory PRIVATE ${LLVM_INCLUDE_DIRS})
target_compile_definitions(PfaasInventory PRIVATE ${LLVM_DEFINITIONS})
set_target_properties(PfaasInventory PROPERTIES PREFIX "")
