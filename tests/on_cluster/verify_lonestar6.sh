#!/usr/bin/env bash
# On-cluster verification for Lonestar6 (ls6).
# Run on ls6.tacc.utexas.edu — exits immediately if not on LS6.
#
# Usage:
#   bash verify_lonestar6.sh          # state checks + sbatch --test-only
#   bash verify_lonestar6.sh --run    # also submit jobs and wait for results
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
if [[ "${TACC_SYSTEM:-}" != "ls6" ]]; then
    echo "ERROR: This script must be run on Lonestar6 (TACC_SYSTEM=ls6). Current: '${TACC_SYSTEM:-unset}'"
    exit 1
fi

echo "=== Lonestar6 on-cluster verification ==="

# --- Identity ---
check_output_contains "architecture is x86_64" "x86_64" uname -m

# --- Partitions exist ---
for partition in development normal large gpu-a100 gpu-a100-dev gpu-h100 gpu-a100-small; do
    check_cmd "partition '$partition' exists" sinfo -p "$partition" --noheader
done

# --- Default partition ---
check_output_contains "default partition is 'development'" "development" \
    bash -c "scontrol show config | grep -i defaultpartition"

# --- No GRES on GPU partition ---
check_output_not_contains "gpu-a100 TRES does not track GPUs via gres" "gpu=" \
    bash -c "scontrol show partition gpu-a100 | grep -i tres"

# --- CUDA module versions ---
for version in cuda/11.4 cuda/12.0 cuda/12.2 cuda/12.8; do
    check_cmd "module $version is available" bash -c "module avail $version 2>&1 | grep -q $version"
done

# --- --gres rejected ---
echo "  checking --gres=gpu:1 is rejected on gpu-a100..."
gres_out=$(printf '#!/bin/bash\n#SBATCH -p gpu-a100\n#SBATCH --gres=gpu:1\nsleep 1\n' \
    | sbatch --test-only 2>&1) || true
if echo "$gres_out" | grep -qi "invalid generic resource"; then
    _pass "--gres=gpu:1 rejected with 'Invalid generic resource'"
else
    _fail "--gres=gpu:1 should be rejected but was not  (output: $gres_out)"
fi

# --- Template validation via sbatch --test-only ---
echo ""
echo "  --- sbatch --test-only validation ---"
for job in ls6_cpu_1node.sh ls6_gpu_a100_1node.sh ls6_gpu_a100_2node.sh ls6_gpu_small_1node.sh; do
    job_path="$JOBS_DIR/$job"
    out=$(sbatch --test-only "$job_path" 2>&1) || true
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
    for job in ls6_cpu_1node.sh ls6_gpu_a100_1node.sh ls6_gpu_small_1node.sh; do
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
