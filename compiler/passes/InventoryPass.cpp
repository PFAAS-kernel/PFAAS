#include "llvm/ADT/SmallPtrSet.h"
#include "llvm/ADT/SmallString.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/Module.h"
#include "llvm/Passes/PassBuilder.h"
#include "llvm/Passes/PassPlugin.h"
#include "llvm/Support/JSON.h"
#include "llvm/Support/MD5.h"
#include "llvm/Support/raw_ostream.h"
#include <map>
#include <set>
#include <string>
#include <vector>

using namespace llvm;

namespace {
class InventoryPass : public PassInfoMixin<InventoryPass> {
public:
  PreservedAnalyses run(Module &M, ModuleAnalysisManager &) {
    std::map<const Function *, std::set<std::string>> Callers;
    std::map<const Function *, std::set<const Function *>> Graph;
    const Function *Entry = M.getFunction("main");
    for (Function &F : M)
      for (BasicBlock &BB : F)
        for (Instruction &I : BB)
          if (auto *CB = dyn_cast<CallBase>(&I))
            if (const Function *C = CB->getCalledFunction()) {
              Callers[C].insert(F.getName().str());
              if (!C->isDeclaration()) Graph[&F].insert(C);
            }
    SmallPtrSet<const Function *, 32> Reachable;
    std::vector<const Function *> Work;
    if (Entry) { Reachable.insert(Entry); Work.push_back(Entry); }
    while (!Work.empty()) {
      const Function *F = Work.back(); Work.pop_back();
      for (const Function *C : Graph[F])
        if (Reachable.insert(C).second) Work.push_back(C);
    }
    for (Function &F : M) {
      if (F.isDeclaration()) continue;
      unsigned instructions = 0;
      bool reads = false, writes = false, mayThrow = false;
      std::set<std::string> callees, globals, externals, allocations;
      for (BasicBlock &BB : F) for (Instruction &I : BB) {
        ++instructions;
        reads |= I.mayReadFromMemory(); writes |= I.mayWriteToMemory(); mayThrow |= I.mayThrow();
        if (auto *CB = dyn_cast<CallBase>(&I)) if (const Function *C = CB->getCalledFunction()) {
          callees.insert(C->getName().str());
          if (C->isDeclaration()) externals.insert(C->getName().str());
          if (C->getName() == "malloc" || C->getName() == "calloc" || C->getName() == "realloc" || C->getName() == "free") allocations.insert(C->getName().str());
        }
        for (Use &U : I.operands())
          if (auto *G = dyn_cast<GlobalValue>(U.get()->stripPointerCasts()))
            if (!isa<Function>(G)) globals.insert(G->getName().str());
      }
      std::string IR; raw_string_ostream IRStream(IR); F.print(IRStream); IRStream.flush();
      MD5 Hasher; Hasher.update(IR); MD5::MD5Result Digest; Hasher.final(Digest);
      SmallString<32> Hex; MD5::stringifyResult(Digest, Hex);
      auto strings = [](const std::set<std::string> &Values) {
        json::Array A; for (const auto &V : Values) A.push_back(V); return A;
      };
      json::Object Effects{{"reads_memory", reads}, {"writes_memory", writes}, {"may_throw", mayThrow}};
      json::Object Allocation{{"calls", strings(allocations)}, {"call_count", static_cast<int64_t>(allocations.size())}};
      json::Object O{
        {"function", F.getName()}, {"module", M.getModuleIdentifier()},
        {"application_owner", "http_service_A"}, {"normalized_ir_hash", Hex.str()},
        {"machine_code_hash", nullptr}, {"machine_code_stage", "post-link similarity analysis"},
        {"estimated_code_size_bytes", static_cast<int64_t>(instructions) * 4},
        {"callers", strings(Callers[&F])}, {"callees", strings(callees)},
        {"referenced_globals", strings(globals)}, {"effects", std::move(Effects)},
        {"external_calls", strings(externals)}, {"allocation_behavior", std::move(Allocation)},
        {"reachable", Reachable.contains(&F)}};
      errs() << formatv("{0}\n", json::Value(std::move(O)));
    }
    return PreservedAnalyses::all();
  }
};
}

extern "C" LLVM_ATTRIBUTE_WEAK PassPluginLibraryInfo llvmGetPassPluginInfo() {
  return {LLVM_PLUGIN_API_VERSION, "PfaasInventory", LLVM_VERSION_STRING,
          [](PassBuilder &PB) { PB.registerPipelineParsingCallback(
            [](StringRef Name, ModulePassManager &MPM, ArrayRef<PassBuilder::PipelineElement>) {
              if (Name != "pfaas-inventory") return false; MPM.addPass(InventoryPass()); return true;
            }); }};
}
