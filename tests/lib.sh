#!/usr/bin/env bash
# Minimal test helper: assert_contains, assert_not_contains, assert_bash_valid

PASS=0
FAIL=0
SKILL_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/tacc-hpc.md"

_pass() { echo "  PASS  $1"; PASS=$((PASS + 1)); }
_fail() { echo "  FAIL  $1"; FAIL=$((FAIL + 1)); }

assert_contains() {
    local description="$1" pattern="$2"
    if grep -qF "$pattern" "$SKILL_FILE"; then
        _pass "$description"
    else
        _fail "$description  (missing: $(printf '%q' "$pattern"))"
    fi
}

assert_not_contains() {
    local description="$1" pattern="$2" section_start="$3" section_end="$4"
    local content
    if [[ -n "$section_start" && -n "$section_end" ]]; then
        content=$(awk "/^### $section_start/,/^### $section_end/" "$SKILL_FILE")
    else
        content=$(cat "$SKILL_FILE")
    fi
    if echo "$content" | grep -qF "$pattern"; then
        _fail "$description  (unexpectedly found: $(printf '%q' "$pattern"))"
    else
        _pass "$description"
    fi
}

# Extract all fenced bash code blocks that look like sbatch scripts from a section
# and validate their syntax with bash -n
assert_sbatch_templates_valid() {
    local section="$1"
    local tmpdir
    tmpdir=$(mktemp -d)
    local i=0

    # Extract text between section header and next same-level header
    awk "/^### $section/{found=1} found && /^### / && !/^### $section/{exit} found{print}" "$SKILL_FILE" \
    | awk '/^```bash/{found=1; next} /^```/{found=0; next} found{print}' \
    | awk '/^#!\/bin\/bash/{i++; file=sprintf("'"$tmpdir"'/script_%03d.sh", i)} file{print > file}'

    local count=0
    for f in "$tmpdir"/script_*.sh; do
        [[ -f "$f" ]] || continue
        count=$((count + 1))
        if bash -n "$f" 2>/dev/null; then
            _pass "$section: sbatch template $count has valid bash syntax"
        else
            _fail "$section: sbatch template $count has invalid bash syntax"
            bash -n "$f"
        fi
    done

    if [[ $count -eq 0 ]]; then
        _fail "$section: no sbatch templates found"
    fi

    rm -rf "$tmpdir"
}

summary() {
    echo ""
    echo "Results: $PASS passed, $FAIL failed"
    [[ $FAIL -eq 0 ]]
}
