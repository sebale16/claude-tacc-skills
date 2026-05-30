# Claude Code TACC Skills

[Claude Code](https://docs.anthropic.com/en/docs/claude-code) custom skill for working on [TACC](https://www.tacc.utexas.edu/) HPC clusters. Teaches Claude Code the specifics of each cluster so it generates correct sbatch scripts, module commands, and filesystem paths without trial and error.

> **Accuracy note:** The Vista and Lonestar6 profiles are verified against live cluster data. Frontera and Stampede3 profiles are based on documentation and may be out of date — verify partition limits and GRES config with `sinfo` before relying on them.

## Typical workflow

You're on a login node (or connected via SSH), Claude Code is running in a `tmux` session, and you invoke `/tacc-hpc`. From there:

1. **Environment detection** — Claude silently checks `$TACC_SYSTEM` to know which cluster you're on, then picks up your allocation from `taccinfo`. If you have multiple allocations, it asks once and remembers for the session.

2. **Writing job scripts** — You describe what you want to run ("train this model on 2 GPU nodes for 4 hours") and Claude generates a correct `sbatch` script with the right partition, wall time, node count, and directives for *this specific cluster* — no `--gres` on LS6/Vista, correct CUDA module version, output to `$SCRATCH` not `$HOME`, etc.

3. **Module management** — Before loading anything, Claude runs `module spider` to check dependencies and conflicts, warns you if loading a module will silently swap out something you already have loaded, and only proceeds after you confirm.

4. **Submitting and monitoring** — Claude submits the job, watches `squeue`, and when it fails tails the output file and maps the symptom (exit 137, TIMEOUT, `ModuleNotFoundError`) to a concrete fix.

5. **Interactive GPU work** — For quick tests that don't need a full batch job, Claude issues the right `idev` command for your cluster and partition.

6. **Heavy commands on login nodes** — If you ask Claude to `pip install` or download a model, it catches that it's on a login node and proposes wrapping the command in `idev` or a one-off `sbatch` job instead of running it directly and risking a kill from TACC's process monitor.

7. **Model serving / port forwarding** — For vLLM or Jupyter running on a compute node, Claude walks you through the SSH tunnel from your local machine and ensures the service binds to `0.0.0.0` so the tunnel can reach it.

**What it prevents**

Without the skill Claude would guess — and guess wrong — on things like using `--gres` on LS6 (rejected), writing to `$HOME` (quota hit), trying to `pip install` inside a batch job (no internet on compute nodes), or loading a CUDA module without its hidden prerequisite. The skill bakes in the per-cluster quirks so those errors don't happen in the first place.

## What it knows

- **Cluster profiles** — Lonestar6, Frontera, Vista, Stampede3: partitions, GPU/CPU hardware, job limits, Slurm quirks (e.g. LS6 and Vista don't use `--gres`)
- **Allocations** — reads `taccinfo` at session start, picks an allocation once (asking if you have multiple), and reuses it for the rest of the session; knows per-partition QOS limits and surfaces private/allocation-linked partitions
- **Filesystem layout** — `$HOME`, `$WORK`, `$SCRATCH`, `$STOCKYARD` quotas and purge policies
- **Module management** — version defaults, silent swaps, hidden dependencies via `module spider`
- **Python environments** — `venv`/`pip` by default, optional `uv` install
- **Containers** — Apptainer (not Docker), GPU passthrough, bind mounts
- **Network restrictions** — compute nodes can't reach the internet; pre-download everything
- **Port forwarding** — SSH tunnels for model serving (vLLM, Jupyter, etc.)
- **Job debugging** — output files, `sacct`, common failure patterns (OOM, timeout, gres errors)
- **Auto-detection** — identifies which cluster you're on via `$TACC_SYSTEM`

## Install

```bash
git clone git@github.com:sebale16/claude-tacc-skills.git $STOCKYARD/claude-skills
# Claude Code discovers each personal skill as ~/.claude/skills/<name>/SKILL.md
mkdir -p ~/.claude/skills/tacc-hpc
ln -sfn $STOCKYARD/claude-skills/tacc-hpc.md ~/.claude/skills/tacc-hpc/SKILL.md
```

Since `$STOCKYARD` is shared across all TACC clusters, you only clone once and symlink on each cluster.

## Verifying cluster accuracy

The `tests/on_cluster/` directory contains scripts that verify the skill's documented values against live cluster state. Run them after SSH-ing into the respective cluster:

```bash
# On Lonestar6:
bash $STOCKYARD/claude-skills/tests/on_cluster/verify_lonestar6.sh

# On Vista:
bash $STOCKYARD/claude-skills/tests/on_cluster/verify_vista.sh
```

Each script checks:
- Partitions exist and match documented names
- Default partition is correct
- GPUs are **not** tracked via `--gres` (LS6 and Vista allocate GPUs by partition)
- `--gres=gpu:N` submissions are rejected with the expected error
- Module versions listed in the skill are actually available
- Architecture (`x86_64` on LS6, `aarch64` on Vista)

It also runs `sbatch --test-only` against the job templates in `tests/on_cluster/jobs/` to confirm the scheduler accepts them. Templates cover:

| Script | Cluster | Partition | Nodes | GPUs |
|--------|---------|-----------|-------|------|
| `ls6_cpu_1node.sh` | LS6 | `development` | 1 | none |
| `ls6_gpu_a100_1node.sh` | LS6 | `gpu-a100-dev` | 1 | 3× A100 |
| `ls6_gpu_a100_2node.sh` | LS6 | `gpu-a100` | 2 | 3× A100/node |
| `ls6_gpu_small_1node.sh` | LS6 | `gpu-a100-small` | 1 | 1 GPU slice |
| `vista_cpu_1node.sh` | Vista | `gg` | 1 | none (ARM) |
| `vista_gpu_1node.sh` | Vista | `gh-dev` | 1 | 1× GH200 |
| `vista_gpu_2node.sh` | Vista | `gh` | 2 | 1× GH200/node |

Add `--run` to actually submit the jobs and poll for completion via `sacct` (consumes allocation time):

```bash
bash tests/on_cluster/verify_vista.sh --run
```

## Contributing

If something is wrong or missing for your cluster, open an issue or PR. The skill file is `tacc-hpc.md`.
