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

## Contributing

If something is wrong or missing for your cluster, open an issue or PR. The skill file is `tacc-hpc.md`.
