#!/usr/bin/env bash
# Tests for the Vista section of tacc-hpc.md
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$TESTS_DIR/lib.sh"

echo "=== Vista tests ==="

# --- Hardware ---
assert_contains "documents GH200 superchip"           "GH200 superchip"
assert_contains "documents Grace-Hopper node type"    "Grace-Hopper"
assert_contains "documents Grace-Grace node type"     "Grace-Grace"
assert_contains "documents ARM (aarch64) architecture" "ARM (aarch64)"
assert_contains "documents 72 ARM cores per gh node"  "72 ARM (Grace) cores"
assert_contains "documents unified memory ~480 GB"    "480 GB"
assert_contains "documents 1 H100 96GB GPU per gh node" "1 H100 96GB"
assert_contains "documents 144 ARM cores on gg nodes" "144 ARM cores"
assert_contains "documents gh400 feature tag"         "gh400"

# --- Partitions ---
assert_contains "documents gh-dev partition (default)" "| \`gh-dev\` **(default)**"
assert_contains "documents gh partition"               "| \`gh\`"
assert_contains "documents gg partition"               "| \`gg\`"

# --- Partition limits ---
assert_contains "documents gh-dev max 8 nodes/job"    "gh-dev"
assert_contains "documents gh max 64 nodes/job"       "| \`gh\` "
assert_contains "documents gg max 32 nodes/job"       "| \`gg\` "

# --- QOS ---
assert_contains "documents qgh4k large-memory QOS"    "qgh4k"
assert_contains "documents qgg4k QOS"                 "qgg4k"

# --- Default modules ---
assert_contains "documents gcc/15.1.0 as default"     "gcc/15.1.0"
assert_contains "documents cuda/12.5 as default"      "cuda/12.5"
assert_contains "documents openmpi/5.0.5"             "openmpi/5.0.5"
assert_contains "documents python3/3.11.8"            "python3/3.11.8"
assert_contains "documents nvpl/26.1"                 "nvpl/26.1"
assert_contains "documents cmake/3.31.5"              "cmake/3.31.5"

# --- Available CUDA versions ---
assert_contains "documents CUDA 11.8 available"  "11.8"
assert_contains "documents CUDA 12.9 available"  "12.9"
assert_contains "documents CUDA 13.0 available"  "13.0"
assert_contains "documents CUDA 13.1 available"  "13.1"

# --- Slurm quirks ---
assert_contains "documents no --gres on Vista"        "No \`--gres\` flag"
assert_contains "documents GRES is null on Vista"     "GRES is \`(null)\`"
assert_contains "documents default partition is gh-dev" "Default partition is \`gh-dev\`"
assert_contains "documents ARM incompatibility with x86 binaries" "binaries compiled on x86 clusters"
assert_contains "documents nvpl as MKL alternative"   "nvpl"

# --- python3 module note ---
assert_contains "documents python3 module name (not python)" "python3\`, not \`python\`"

# --- idev example ---
assert_contains "documents idev example for gh-dev" "idev -p gh-dev"

# --- Sbatch templates: syntax validity ---
assert_sbatch_templates_valid "Vista"

# --- Sbatch templates must not use --gres ---
echo "  checking Vista sbatch code blocks do not use --gres..."
CODE_BLOCKS=$(awk '/^### Vista/,/^### Stampede3/' "$SKILL_FILE" \
    | awk '/^```bash/{found=1; next} /^```/{found=0; next} found{print}')
if echo "$CODE_BLOCKS" | grep -q -- '--gres'; then
    _fail "Vista sbatch code blocks must not contain --gres"
else
    _pass "Vista sbatch code blocks do not contain --gres"
fi

# --- GPU template uses gh partition (not gh-dev for production) ---
assert_contains "GPU job template targets gh partition" "#SBATCH -p gh"

# --- CPU template targets gg partition ---
assert_contains "CPU job template targets gg partition" "#SBATCH -p gg"

summary
