#!/usr/bin/env bash
# On-cluster verification for Vista.
# Run on vista.tacc.utexas.edu — exits immediately if not on Vista.
#
# Usage:
#   bash verify_vista.sh          # state checks + sbatch --test-only
#   bash verify_vista.sh --run    # also submit jobs and wait for results
set -euo pipefail

JOBS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/jobs" && pwd)"
RUN_JOBS=false
[[ "${1:-}" == "--run" ]] && RUN_JOBS=true

PASS=0
FAIL=0
_pass() { echo "  PASS  $1"; PASS=$((PASS + 1)); }
_fail() { echo "  FAIL  $1"; FAIL=$((FAIL + 1)); }

check_cmd() {
    local desc="$1"; shift
    if "$@" &>/dev/null; then _pass "$desc"; else _fail "$desc"; fi
}

check_output_contains() {
    local desc="$1" pattern="$2"; shift 2
    local out
    out=$("$@" 2>&1) || true
    if echo "$out" | grep -q "$pattern"; then _pass "$desc"; else _fail "$desc  (pattern: $pattern)"; fi
}

check_output_not_contains() {
    local desc="$1" pattern="$2"; shift 2
    local out
    out=$("$@" 2>&1) || true
    if echo "$out" | grep -q "$pattern"; then _fail "$desc  (unexpected: $pattern)"; else _pass "$desc"; fi
}

# --- Guard ---
if [[ "${TACC_SYSTEM:-}" != "vista" ]]; then
    echo "ERROR: This script must be run on Vista (TACC_SYSTEM=vista). Current: '${TACC_SYSTEM:-unset}'"
    exit 1
fi

# --- Allocation detection ---
# Pick the first allocation from taccinfo (or accept one from the environment).
# Used for --gres rejection test and sbatch --test-only calls.
if [[ -z "${TACC_ALLOCATION:-}" ]]; then
    TACC_ALLOCATION=$(/usr/local/etc/taccinfo 2>/dev/null | grep -oP '\|\s+\K[A-Z][A-Z0-9]+(?=\s+\d)' | head -1)
fi
if [[ -z "${TACC_ALLOCATION:-}" ]]; then
    echo "ERROR: Could not detect a TACC allocation. Set TACC_ALLOCATION=<name> and retry."
    exit 1
fi
echo "  (using allocation: $TACC_ALLOCATION)"

echo "=== Vista on-cluster verification ==="

# --- Identity & architecture ---
check_output_contains "architecture is aarch64 (ARM)" "aarch64" uname -m

# --- Partitions exist ---
for partition in gh-dev gh gg; do
    check_cmd "partition '$partition' exists" sinfo -p "$partition" --noheader
done

# --- Default partition ---
# Vista marks the default with '*' in sinfo; scontrol show config has no DefaultPartition line.
check_output_contains "default partition is 'gh-dev'" "gh-dev" \
    bash -c "sinfo -o '%P' | grep '\*'"

# --- No GRES on GPU partition ---
check_output_not_contains "gh partition TRES does not track GPUs via gres" "gpu=" \
    bash -c "scontrol show partition gh | grep -i tres"

# --- Default modules ---
for mod in gcc/15.1.0 cuda/12.5 openmpi/5.0.5 python3/3.11.8 nvpl cmake/3.31.5; do
    check_cmd "module $mod is available" bash -c "module avail $mod 2>&1 | grep -q ${mod%%/*}"
done

# --- Additional CUDA versions ---
for version in cuda/11.8 cuda/12.9 cuda/13.0 cuda/13.1; do
    check_cmd "module $version is available" bash -c "module avail $version 2>&1 | grep -q ${version#*/}"
done

# --- python3 loaded by default ---
check_output_contains "python3 is loaded by default" "python3" \
    bash -c "module list 2>&1"

# --- QOS entries ---
for qos in qgh4k qgg4k; do
    check_cmd "QOS '$qos' exists" bash -c "sacctmgr -n show qos $qos | grep -q $qos"
done

# --- --gres rejected ---
echo "  checking --gres=gpu:1 is rejected on gh..."
gres_out=$(printf '#!/bin/bash\n#SBATCH -p gh\n#SBATCH -N 1\n#SBATCH -t 01:00:00\n#SBATCH -A %s\n#SBATCH --gres=gpu:1\nsleep 1\n' "$TACC_ALLOCATION" \
    | sbatch --test-only 2>&1) || true
if echo "$gres_out" | grep -qi "invalid generic resource\|gres"; then
    _pass "--gres=gpu:1 rejected with 'Invalid generic resource'"
else
    _fail "--gres=gpu:1 should be rejected but was not  (output: $gres_out)"
fi

# --- Template validation via sbatch --test-only ---
echo ""
echo "  --- sbatch --test-only validation ---"
for job in vista_cpu_1node.sh vista_gpu_1node.sh vista_gpu_2node.sh; do
    job_path="$JOBS_DIR/$job"
    out=$(sbatch --test-only --account="$TACC_ALLOCATION" "$job_path" 2>&1) || true
    if echo "$out" | grep -qi "error\|invalid\|failed"; then
        _fail "$job accepted by scheduler  (output: $out)"
    else
        _pass "$job accepted by scheduler"
    fi
done

# --- Optional real submission ---
if $RUN_JOBS; then
    echo ""
    echo "  --- submitting jobs (--run mode) ---"
    declare -A job_ids
    for job in vista_cpu_1node.sh vista_gpu_1node.sh; do
        job_path="$JOBS_DIR/$job"
        jid=$(sbatch "$job_path" 2>&1 | grep -oP '(?<=Submitted batch job )\d+') || true
        if [[ -n "$jid" ]]; then
            _pass "$job submitted (job $jid)"
            job_ids[$job]=$jid
        else
            _fail "$job submission failed"
        fi
    done

    echo "  waiting for jobs to complete..."
    for job in "${!job_ids[@]}"; do
        jid="${job_ids[$job]}"
        for _ in $(seq 1 60); do
            state=$(squeue -j "$jid" -h -o "%T" 2>/dev/null) || true
            [[ -z "$state" ]] && break
            sleep 5
        done
        exit_code=$(sacct -j "$jid" --format=ExitCode --noheader | head -1 | tr -d ' ') || true
        if [[ "$exit_code" == "0:0" ]]; then
            _pass "$job completed successfully (job $jid)"
        else
            _fail "$job exited with code $exit_code (job $jid)"
        fi
    done
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
