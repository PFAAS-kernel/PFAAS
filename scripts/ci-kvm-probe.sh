#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
provider="${PFAAS_RUNNER_PROVIDER:-unknown-ci}"
mkdir -p verification
./scripts/build-freestanding.sh
python3 tools/experiment-runner/experiment_runner.py probe \
  --provider "$provider" --guest-image build/freestanding/pfaas-boot.img \
  --output "verification/ci-${provider}-capabilities.json" --require-kvm
