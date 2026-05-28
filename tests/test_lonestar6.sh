#!/usr/bin/env bash
# Tests for the Lonestar6 (ls6) section of tacc-hpc.md
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$TESTS_DIR/lib.sh"

echo "=== Lonestar6 tests ==="

# --- Hardware ---
assert_contains "documents A100 40GB GPU"          "A100 40GB"
assert_contains "documents H100 80GB GPU"          "H100 80GB"
assert_contains "documents cpu-only Ice Lake nodes" "Ice Lake"
assert_contains "documents 128 cores/node for CPU"  "128 cores/node"

# --- Partitions ---
assert_contains "documents development partition"  "| \`development\`"
assert_contains "documents normal partition"       "| \`normal\`"
assert_contains "documents large partition"        "| \`large\`"
assert_contains "documents gpu-a100 partition"     "| \`gpu-a100\`"
assert_contains "documents gpu-a100-dev partition" "| \`gpu-a100-dev\`"
assert_contains "documents gpu-h100 partition"     "| \`gpu-h100\`"
assert_contains "documents gpu-a100-small partition" "| \`gpu-a100-small\`"

# --- Key Slurm quirks ---
assert_contains "documents no --gres quirk"       "No \`--gres\` flag"
assert_contains "documents gres failure message"  "Invalid generic resource (gres) specification"
assert_contains "documents all 3 GPUs allocated per node" "All 3 GPUs on a node are allocated"
assert_contains "documents default partition is development" "Default partition is \`development\`"

# --- CUDA versions ---
assert_contains "documents CUDA 11.4 default"  "11.4 (default)"
assert_contains "documents CUDA 12.0"          "12.0"
assert_contains "documents CUDA 12.2"          "12.2"
assert_contains "documents CUDA 12.8"          "12.8"

# --- idev example for LS6 ---
assert_contains "documents idev example for gpu-a100" "idev -p gpu-a100"

# --- Sbatch templates must not use --gres ---
echo "  checking LS6 sbatch code blocks do not use --gres..."
CODE_BLOCKS=$(awk '/^### Lonestar6/,/^### Frontera/' "$SKILL_FILE" \
    | awk '/^```bash/{found=1; next} /^```/{found=0; next} found{print}')
if echo "$CODE_BLOCKS" | grep -q -- '--gres'; then
    _fail "LS6 sbatch code blocks must not contain --gres"
else
    _pass "LS6 sbatch code blocks do not contain --gres"
fi

summary
