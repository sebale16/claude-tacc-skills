# Claude Code TACC Skills

[Claude Code](https://docs.anthropic.com/en/docs/claude-code) custom skill for working on [TACC](https://www.tacc.utexas.edu/) HPC clusters. Teaches Claude Code the specifics of each cluster so it generates correct sbatch scripts, module commands, and filesystem paths without trial and error.

> **Accuracy note:** The Vista and Lonestar6 profiles are verified against live cluster data. Frontera and Stampede3 profiles are based on documentation and may be out of date — verify partition limits and GRES config with `sinfo` before relying on them.

## What it knows

- **Cluster profiles** — Lonestar6, Frontera, Vista, Stampede3: partitions, GPU/CPU hardware, job limits, Slurm quirks (e.g. LS6 and Vista don't use `--gres`)
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
mkdir -p ~/.claude/skills
ln -sf $STOCKYARD/claude-skills/tacc-hpc.md ~/.claude/skills/tacc-hpc.md
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
