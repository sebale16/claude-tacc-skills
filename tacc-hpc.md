---
name: tacc-hpc
description: >
  Manage jobs, modules, and filesystems on TACC HPC clusters (Lonestar6, Frontera, Vista, Stampede3).
  Automatically detects whether you are on a TACC system and which cluster. Knows each cluster's
  partitions, GPU/CPU hardware, job limits, filesystem layout, and Slurm quirks so you never
  generate invalid sbatch directives.
---

# TACC HPC Manager

You are an expert at managing workloads on TACC (Texas Advanced Computing Center) HPC clusters.

## Detecting the environment

Before doing any TACC-specific work, determine where you are:

1. Check `$TACC_SYSTEM` — set on all TACC login and compute nodes (e.g. `ls6`, `frontera`, `vista`, `stampede3`).
2. Check `hostname -f` — TACC hostnames match `*.tacc.utexas.edu`.
3. If neither is set, you are **not on TACC**. If the user wants to reach a TACC cluster, they must SSH first:
   ```
   ssh <username>@<cluster>.tacc.utexas.edu
   ```
   Common hostnames: `ls6.tacc.utexas.edu`, `frontera.tacc.utexas.edu`, `vista.tacc.utexas.edu`, `stampede3.tacc.utexas.edu`.

Always run the detection step silently at the start of any TACC-related task. Use `$TACC_SYSTEM` to select the correct cluster profile below.

## Filesystem layout (all clusters)

| Path | Env var | Quota | Backed up | Purged | Use for |
|------|---------|-------|-----------|--------|---------|
| `/home1/<allocation>/<user>` | `$HOME` | 10 GB | Yes | No | Dotfiles, small configs, SSH keys |
| `/work/<allocation>/<user>/<system>` | `$WORK` | 1 TB | No | No | Software installs, venvs, datasets, persistent project files |
| `/scratch/<allocation>/<user>` | `$SCRATCH` | Unlimited | No | Yes (files untouched >10 days) | Job I/O, temporary large files |
| `$STOCKYARD` | `$STOCKYARD` | (same as /work) | No | No | Cross-cluster shared work directory (parent of per-system $WORK) |

**Key rules:**
- Never write large files or job output to `$HOME` — it has a 10 GB hard quota.
- Use `$WORK` for anything that must persist (model weights, venvs, datasets).
- Use `$SCRATCH` for job I/O — it is on a fast parallel filesystem (Lustre or BeeGFS) but files are **purged** if untouched for 10 days.
- `$STOCKYARD` (`/work/<allocation>/<user>`) is shared across clusters. `$WORK` is `$STOCKYARD/<system>`.
- Run `/usr/local/etc/taccinfo` to check current quotas and allocation balances.

## Login nodes vs compute nodes

**Login nodes** are shared and monitored. Acceptable uses:
- Editing files, git operations, small compilations
- Transferring data (scp, rsync, wget)
- Submitting and monitoring jobs (`sbatch`, `squeue`, `sacct`)
- Short interactive tests (< 1 min, < 1 GB memory)
- Running Claude Code (see below)

**Never do on login nodes:**
- Run GPU workloads (no GPUs on login nodes)
- Long-running or memory-intensive processes (pip install of large packages, model downloads, compilation)
- Multi-node MPI jobs
- `nvidia-smi` (no GPUs available)

**Before running any bash command that could be heavy** (pip install, wget/curl for large files, compilation, anything that might take more than ~1 minute), route it through `idev` or `sbatch` instead. Running it directly on a login node risks having the whole session killed by TACC's process monitor.

**For interactive GPU/compute work**, use `idev`:
```bash
idev -p gpu-a100 -N 1 -n 1 -t 01:00:00    # LS6 example
idev -p gh-dev   -N 1 -n 1 -t 01:00:00    # Vista example
```

## Running Claude Code on TACC

Claude Code itself is lightweight (API calls + file edits) and won't trigger TACC's process monitor. However, the bash commands it runs on your behalf can — and if TACC kills a subprocess, it can take down the whole Claude Code session.

**Recommended setup: tmux on a login node**

Run Claude Code inside a `tmux` session so it survives SSH disconnections and won't be lost if your terminal drops:
```bash
tmux new -s claude      # start a named session
# ... or reattach to an existing one:
tmux attach -t claude
```

This is more persistent than running inside `idev` — idev sessions have a 2-hour wall time on most partitions and will kill everything when they expire.

**How Claude Code should handle heavy commands:**

| Task | Right approach |
|------|---------------|
| File edits, git, squeue, sacct | Run directly on login node |
| pip install, conda, uv sync | Run inside `idev` or as a one-off `sbatch` job |
| Model downloads (HuggingFace, wget) | Run inside `idev` or `sbatch` |
| Compilation (make, cmake) | Run inside `idev` or `sbatch` |
| GPU workloads, training, inference | Always `sbatch` or `idev -p gpu-*` |

When a task falls in the "heavy" category, Claude Code should tell the user what it wants to run and suggest wrapping it in `idev` rather than executing directly. Example:
```bash
# Instead of running directly:
pip install -r requirements.txt

# Start an idev session first:
idev -p development -N 1 -n 1 -t 00:30:00
# then run inside it
```

## Cluster profiles

### Lonestar6 (ls6)

**CPU-only nodes (normal, development, large):**
- 2x Intel Xeon 8380 (Ice Lake), 128 cores/node
- 256 GB RAM
- No GPUs

**GPU A100 nodes (gpu-a100, gpu-a100-dev):**
- 2x AMD EPYC 7763 (Milan), 128 cores/node
- 256 GB RAM
- **3x NVIDIA A100 40GB per node**
- No GRES in Slurm — GPUs are allocated by partition, not `--gres`

**GPU H100 nodes (gpu-h100):**
- 2x AMD EPYC 9334 (Genoa), 96 cores/node
- 256 GB RAM
- **3x NVIDIA H100 80GB per node**
- No GRES in Slurm

**GPU A100 small (gpu-a100-small):**
- Virtual nodes, 32 cores, 15 GB RAM
- 1 GPU slice per node

**Partitions and limits:**

| Partition | Nodes | Max nodes/job | Max wall | Max jobs | Max queued | Use case |
|-----------|-------|---------------|----------|----------|------------|----------|
| `development` (default) | 18 | 8 | 2 hr | 1 | 3 | Quick tests, debugging |
| `normal` | 513 | 64 | 48 hr | 20 | 100 | Production CPU jobs |
| `large` | 513+ | 256 | 48 hr | 1 | 4 | Large-scale CPU jobs |
| `gpu-a100` | 73 | 8 | 48 hr | 8 | 32 | Production GPU (A100) jobs |
| `gpu-a100-dev` | 4 | 2 | 2 hr | 1 | 3 | Quick GPU tests |
| `gpu-h100` | 4 | 1 | 48 hr | 1 | 4 | H100 GPU jobs |
| `gpu-a100-small` | 24 | 1 | 48 hr | 3 | 12 | Single-GPU or small GPU jobs |
| `vm-small` | 28 | 1 | 48 hr | 4 | 16 | Lightweight/VM workloads |

**Partition → QOS mapping (limits are enforced by QOS, not partition directly):**

| Partition | QOS | Max running | Max submitted | Max nodes/job | Max wall |
|-----------|-----|-------------|---------------|---------------|----------|
| `development` | `qdevelopment` | 1 | 3 | 8 | 2 hr |
| `normal` | `qnormal` | 20 | 100 | 64 | 48 hr |
| `large` | `qlarge` | 1 | 4 | 256 | 48 hr |
| `gpu-a100` | `qa100` | 8 | 32 | 8 | 48 hr |
| `gpu-a100-dev` | `qa100development` | 1 | 3 | 2 | 2 hr |
| `gpu-h100` | `qh100` | 1 | 4 | 1 | 48 hr |
| `gpu-a100-small` | `qa100small` | 3 | 12 | 1 | 48 hr |
| `vm-small` | `qsmall` | 4 | 16 | 1 | 48 hr |

**LS6 Slurm quirks:**
- **No `--gres` flag.** GPUs are allocated by choosing the GPU partition. Using `--gres=gpu:N` will cause `sbatch` to fail with "Invalid generic resource (gres) specification."
- All 3 GPUs on a node are allocated to the job — you cannot request fewer than 3 (except on `gpu-a100-small`).
- Default partition is `development`, not `normal`.
- CUDA modules available: 11.3, 11.4 (default), 12.0, 12.2, 12.8.

### Frontera

**CPU nodes (normal, development, large, small):**
- 2x Intel Xeon 8280 (Cascade Lake), 56 cores/node
- 192 GB RAM
- No GPUs on CPU nodes

**GPU nodes (rtx):**
- 4x NVIDIA Quadro RTX 5000 per node
- Uses `--gres=gpu:N` (1-4)

**Partitions and limits:**

| Partition | Max nodes/job | Max wall | Use case |
|-----------|---------------|----------|----------|
| `development` | 40 | 2 hr | Quick tests |
| `normal` | 512 | 48 hr | Production CPU jobs |
| `large` | 2048 | 48 hr | Large-scale jobs (requires justification) |
| `small` | 2 | 48 hr | Small jobs |
| `rtx` | 22 | 48 hr | GPU jobs |
| `rtx-dev` | 2 | 2 hr | Quick GPU tests |

**Frontera Slurm quirks:**
- `--gres=gpu:N` IS required for GPU partitions (rtx, rtx-dev).
- CPU nodes have no GPUs at all.
- Default modules include `intel/19` and `impi/19`.

### Vista

Vista has two node types: Grace-Hopper (GPU) and Grace-Grace (CPU-only). Both are ARM (aarch64).

**Grace-Hopper nodes (gh, gh-dev partitions):**
- 1x NVIDIA GH200 superchip per node: 72 ARM (Grace) cores + 1 H100 96GB GPU
- ~480 GB unified CPU+GPU memory (NVLink-C2C connected)
- A small subset of nodes have the `gh400` feature tag (~576 GB unified memory variant)
- No NVSwitch — each node has exactly 1 GPU

**Grace-Grace nodes (gg partition):**
- 2x NVIDIA Grace CPU per node (no GPU)
- 144 ARM cores, ~480 GB LPDDR5X memory
- CPU-only ARM workloads; useful for ARM-native compilation and memory-intensive CPU jobs

**Partitions and limits:**

| Partition | Nodes | Max nodes/job | Max wall | Max jobs | Max queued | Use case |
|-----------|-------|---------------|----------|----------|------------|----------|
| `gh-dev` **(default)** | 20 | 8 | 2 hr | 1 | 3 | Quick GPU tests, interactive dev |
| `gh` | 576 | 64 | 48 hr | 20 | 40 | Production GPU (GH200) jobs |
| `gg` | 251 | 32 | 48 hr | 20 | 40 | Production CPU-only ARM jobs |

QOS suffixed `4k` (e.g. `qgh4k`, `qgg4k`) are available for large-memory jobs and cap at 8 nodes; use `#SBATCH --qos=qgh4k` alongside `-p gh` when needed.

**Default modules on Vista:**
`gcc/15.1.0`, `cuda/12.5` (default; 12.9 is also common), `openmpi/5.0.5`, `python3/3.11.8`, `nvpl/26.1`, `cmake/3.31.5`

Available CUDA versions: `11.8`, `12.4`, `12.5` (D), `12.6`, `12.8`, `12.9`, `13.0`, `13.1`

Note: the Python module on Vista is **`python3`**, not `python`. Use `module load python3` (loaded by default).

**Vista Slurm quirks:**
- **ARM (aarch64) architecture** — binaries compiled on x86 clusters (LS6, Frontera, Stampede3) will not run. Recompile natively or use ARM-compatible containers.
- **No `--gres` flag** — GRES is `(null)` on all Vista partitions. GPUs are allocated by partition (`gh`, `gh-dev`), not via `--gres`.
- Each `gh`/`gh-dev` node has exactly 1 GH200 GPU.
- Default partition is `gh-dev` (unlike most TACC clusters where it is `development`).
- CUDA 12.x required (12.5 is default; load a newer version explicitly if needed).
- `nvpl` (NVIDIA Performance Libraries) provides ARM-optimized BLAS/LAPACK — prefer over Intel MKL which is not available on ARM.
- For interactive GPU work: `idev -p gh-dev -N 1 -n 1 -t 01:00:00`

**Template (GPU job on Vista):**
```bash
#!/bin/bash
#SBATCH -J my-job
#SBATCH -p gh
#SBATCH -N 1
#SBATCH --ntasks-per-node 1
#SBATCH -t 02:00:00
#SBATCH -A <allocation>

module load cuda/12.5
source $WORK/my-venv/bin/activate

# Your commands here
```

**Template (CPU-only ARM job on Vista):**
```bash
#!/bin/bash
#SBATCH -J my-cpu-job
#SBATCH -p gg
#SBATCH -N 1
#SBATCH --ntasks-per-node 144
#SBATCH -t 02:00:00
#SBATCH -A <allocation>

# No CUDA needed; nvpl provides optimized BLAS/LAPACK
module load nvpl

# Your commands here
```

### Stampede3

**CPU nodes (normal, development, large, small):**
- Intel Xeon 8480+ (Sapphire Rapids), 112 cores/node
- 128 GB RAM

**GPU nodes (gpu-h100):**
- 2x Intel Xeon 8480+ (Sapphire Rapids), 112 cores/node
- 256 GB RAM
- **2x NVIDIA H100 80GB per node**

**Partitions and limits:**

| Partition | Max nodes/job | Max wall | Use case |
|-----------|---------------|----------|----------|
| `development` | 8 | 2 hr | Quick tests |
| `normal` | 128 | 48 hr | Production CPU jobs |
| `large` | 256 | 48 hr | Large-scale CPU jobs |
| `small` | 4 | 48 hr | Small jobs |
| `gpu-h100` | 4 | 48 hr | GPU (H100) jobs |
| `gpu-h100-dev` | 2 | 2 hr | Quick GPU tests |

**Stampede3 Slurm quirks:**
- Check `sinfo -o "%P %G"` for current GRES configuration before using `--gres`.
- CUDA 12.x modules available.

## Managing allocations

TACC allocations are named project accounts (e.g. `ASC24027`) that charge SUs (service units) for compute time. Every job must specify one via `#SBATCH -A <allocation>`.

**Listing your allocations with balances and expiry:**
```bash
/usr/local/etc/taccinfo
```
Output shows each allocation name, remaining SUs, and expiry date. Use this to decide which allocation to charge.

**Choosing between multiple allocations — session-scoped selection:**

At the start of each session, run `taccinfo` once, pick an allocation, and remember it for the rest of the conversation. Never ask again after the first choice.

- If the user has exactly one allocation: use it silently, no prompt needed.
- If the user has multiple allocations: show the `taccinfo` output once and ask which to use. After they answer, treat that as the session allocation — use it in all subsequent job scripts and `sbatch` commands without re-asking.
- If the user explicitly names a different allocation mid-session, switch to that one for the remainder of the session.

When choosing, prefer allocations with more remaining SUs and later expiry dates. Surface the tradeoffs (nearly-empty balance, expiring soon) so the user can make an informed call.

**Checking partition and QOS constraints per allocation:**
```bash
sacctmgr show associations user=$USER format=Account,Partition,QOS,MaxJobs,MaxWall -P
```
This shows whether an allocation is restricted to specific partitions or QOS levels. Most TACC allocations use `qdefault` with no partition restriction, but some (especially allocation-specific private partitions) require a particular account.

**Specifying the allocation:**

Hardcode it directly in the job script:
```bash
#SBATCH -A ASC24027
```

Or override on the command line (takes precedence over the script's `#SBATCH -A`):
```bash
sbatch --account=ASC24027 myjob.sh
```

**Important:** Do NOT use shell variable syntax like `${TACC_ALLOCATION:-development}` in `#SBATCH` directives. Slurm's `#SBATCH` parser does not expand shell variables — the literal string becomes the account name and will fail with "Unknown project."

**Private/allocation-linked partitions:**

Some allocations unlock partitions that are not in the standard cluster profiles. These appear in `sinfo` output but are invisible to users without the matching allocation. Examples seen on LS6:

| Partition | CPUs/node | RAM | Max wall | Notes |
|-----------|-----------|-----|----------|-------|
| `NuclearEnergy` | 256 | ~502 GB | 5 days | High-memory specialized nodes |
| `NuclearEnergy-dev` | 256 | ~502 GB | 5 days | Dev queue for same nodes |
| `TIE` | 128 | — | 5 days | Allocation-specific partition |

If the user sees unfamiliar partitions in `sinfo`, check which allocation gives access by running `sacctmgr show associations` and matching the partition column. Always use `sinfo -p <partition>` to inspect hardware before submitting to an unfamiliar partition.

## Writing sbatch scripts

**Always follow this process:**

1. Identify the target cluster from `$TACC_SYSTEM`.
2. Select the appropriate partition based on the workload (CPU vs GPU, job size, time needed).
3. Check the cluster profile above for:
   - Whether `--gres` is needed or forbidden
   - GPUs per node (to set tensor/pipeline parallelism correctly)
   - Max wall time and max nodes
   - Core count per node (for `--ntasks-per-node` or `--cpus-per-task`)
4. Set `#SBATCH -A <allocation>` — if the user has multiple allocations, ask which to use (see Managing allocations above).

**Template (GPU job on LS6):**
```bash
#!/bin/bash
#SBATCH -J my-job
#SBATCH -p gpu-a100
#SBATCH -N 1
#SBATCH --ntasks-per-node 1
#SBATCH -t 02:00:00
#SBATCH -A <allocation>

module load cuda/12.8

# Your commands here
```

**Template (GPU job on Frontera):**
```bash
#!/bin/bash
#SBATCH -J my-job
#SBATCH -p rtx
#SBATCH -N 1
#SBATCH --ntasks-per-node 1
#SBATCH --gres=gpu:4
#SBATCH -t 02:00:00
#SBATCH -A <allocation>

module load cuda/11.4

# Your commands here
```

**Common mistakes to avoid:**
- Using `--gres gpu:N` (space instead of `=`) — always use `--gres=gpu:N`.
- Using `--gres` on LS6 or Vista — neither uses GRES.
- Requesting more nodes than the partition allows.
- Requesting more time than the partition allows.
- Writing output to `$HOME` instead of `$SCRATCH` or `$WORK`.
- Forgetting `module load cuda/<version>` before GPU work.
- Using `#SBATCH -n` (total tasks) when you mean `#SBATCH --ntasks-per-node`.

## Job limits

On all TACC clusters, per-user job limits are enforced by **QOS** (Quality of Service), not directly by partition. Each partition maps to a QOS that sets the binding constraints. The cluster profile tables above list the resulting "Max jobs" (running at once) and "Max queued" (total submitted including pending) for each partition. To see the QOS-level limits for the cluster you are on, use the discovery command below.

**Checking current limits (live, authoritative):**
```bash
sacctmgr show qos format=Name,MaxWall,MaxNodes,MaxSubmitJobsPerUser,MaxJobsPerUser -P
```

**Checking your current usage:**
```bash
# Jobs running and queued right now
squeue -u $USER -o "%.10i %.9P %.20j %.8T %.10M %.6D"

# Count by state
squeue -u $USER -h -o "%T" | sort | uniq -c
```

**What happens when you hit a limit:**
- Submitting beyond `MaxSubmitPU` → `sbatch` is rejected immediately with "Job violates accounting/QOS policy."
- Running jobs beyond `MaxJobsPU` → job is held in `PENDING` state with reason `QOSMaxJobsPerUserLimit` until a running job finishes.

**Array jobs count differently:** each array task counts as a separate job against both limits. A 50-task array on `normal` (MaxJobsPU=20) will have 20 tasks running and 30 held at any time.

## Discovering cluster state at runtime

When you are unsure about the current cluster's configuration or the profiles above may be outdated, run these discovery commands:

```bash
# Detect cluster
echo $TACC_SYSTEM

# List partitions with hardware info
sinfo -o "%P %l %c %m %G %a"

# Find the default partition (marked with * — scontrol show config does NOT expose DefaultPartition on LS6/Vista)
sinfo -o "%P" | grep '\*'

# Check if a partition uses GRES
sinfo -p <partition> -o "%N %G" | head -5

# See job limits per QOS
sacctmgr show qos format=Name,MaxWall,MaxNodes,MaxSubmit,MaxJobsPerUser -p

# Check node hardware
scontrol show node <nodename>

# List available modules
module avail <keyword>
module spider <keyword>

# Check allocations and quotas
/usr/local/etc/taccinfo

# See what's running
squeue -u $USER
showq -u $USER

# Check completed job details
sacct -j <jobid> --format=JobID,Elapsed,State,MaxRSS,MaxVMSize,ExitCode
```

## Module management

TACC uses Lmod. Key commands:
- `module load <name>` / `module unload <name>`
- `module list` — show loaded modules
- `module avail` — list all available modules
- `module spider <name>` — search for a module across all hierarchies
- `module swap <old> <new>` — replace a loaded module

**Default loaded modules** (most clusters): `intel`, `impi`, `autotools`, `cmake`, `pmix`, `xalt`, `TACC`, `python`.

When a user needs a specific tool (e.g., CUDA, GCC), always check `module avail <tool>` or `module spider <tool>` first — don't assume versions.

**Critical: `module load` does NOT always load the latest version.** It loads the version marked `(D)` (default), which may be old. Always run `module avail <name>` to see available versions and which is default before loading.

**Critical: Loading one module can silently unload or swap others.** Lmod enforces a "one family per type" rule — for example, loading `gcc` will unload `intel`, loading a different MPI will swap out `impi`. This can break a user's existing environment.

**Before running any `module load` command:**
1. Run `module spider <name>/<version>` to check what the module requires and what it conflicts with.
2. Show the user the output so they can see dependencies and potential conflicts.
3. Warn the user explicitly if loading the module will unload or swap any currently loaded modules.
4. Let the user confirm before proceeding.

**Critical: Modules can have hidden dependencies.** A module may only become available after loading a prerequisite (e.g., a compiler or MPI module). `module avail` won't show it, and `module load` will fail with "not found." Always use `module spider <name>/<version>` to reveal required parent modules.

Example: `module spider hdf5/1.14.0` might show it requires `gcc/12.2.0` and `openmpi/4.1.4` to be loaded first.

**Workflow before loading any module:**
```bash
# 1. Find all available versions
module spider <name>

# 2. Check dependencies and conflicts for the specific version
module spider <name>/<version>

# 3. Show the user the spider output — it lists:
#    - Required parent modules that must be loaded first
#    - Which module families it belongs to (and thus what it will swap out)

# 4. Check what's currently loaded
module list

# 5. Load prerequisites first, then the target module — only after user confirms
module load <prerequisite>
module load <name>/<version>
```

## Python environment management

TACC clusters provide a system Python via `module load python` (loaded by default on most clusters). **Only `venv` is available out of the box.** There is no `conda`, `pyenv`, or `uv` preinstalled.

**Vista exception:** the module is `python3`, not `python`. It is loaded by default as `python3/3.11.8`. Use `module load python3` explicitly if needed.

**Creating a virtual environment:**
```bash
python3 -m venv $WORK/my-venv
source $WORK/my-venv/bin/activate
pip install --upgrade pip
```

- Always create venvs in `$WORK`, not `$HOME` (quota) or `$SCRATCH` (purged).
- The system `pip` may be outdated — upgrade it immediately after creating a venv.

**uv (optional, faster alternative):**
`uv` is not installed on TACC systems. If the user wants to use `uv` for faster dependency management, **ask them first** before installing it — it requires a manual install:
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```
This installs to `~/.local/bin/uv`. After install, `uv venv` and `uv pip install` can replace the standard `venv`/`pip` workflow.

Do not assume `uv` is available. Do not install it without the user's confirmation.

**Key rules:**
- Default to `python3 -m venv` + `pip` unless the user explicitly requests `uv`.
- `conda` is not available on TACC (no module, no system install). Do not suggest it.
- If a project has a `pyproject.toml` or `uv.lock`, ask the user if they have `uv` installed before using `uv`-specific commands.

## Network restrictions

**Compute nodes on TACC clusters generally cannot reach the internet.** Any command that requires network access will fail silently or hang inside a batch job:
- `pip install` / `uv pip install`
- `wget`, `curl`
- `git clone` / `git pull`
- HuggingFace `from_pretrained()` auto-downloads
- `apptainer pull` (container image downloads)

**Everything must be pre-downloaded on login nodes before submitting a job.**

- **Python packages:** Install into venvs on login nodes. If packages are needed offline, use `pip download -d ./pkgs <package>` then `pip install --no-index --find-links=./pkgs <package>` inside the job.
- **HuggingFace models:** Set `HF_HOME=$WORK/hf-cache` and run the download on a login node:
  ```bash
  python -c "from transformers import AutoModel; AutoModel.from_pretrained('model-name')"
  ```
  Or use `huggingface-cli download`. The job script should set the same `HF_HOME` so it finds the cached files.
- **Container images:** Pull/build SIF files on login nodes, store in `$WORK`.
- **Git repos:** Clone on login nodes to `$WORK` or `$SCRATCH`.

If a job fails with connection timeouts or DNS errors, this is almost always the cause.

## Containers (Apptainer)

TACC uses **Apptainer** (formerly Singularity). **Docker is not available** on any TACC cluster — no Docker daemon runs on shared HPC systems.

**Loading Apptainer:**
```bash
module load tacc-apptainer
```
Note: the default version may be old (e.g., 1.1.8). Check `module avail tacc-apptainer` and load a specific newer version if needed.

**Running a container with GPU access:**
```bash
apptainer exec --nv container.sif <command>
```
The `--nv` flag passes through NVIDIA GPUs and drivers. Required for any GPU workload inside a container.

**Bind mounts:**
- `$HOME` is mounted automatically inside the container.
- `$WORK` and `$SCRATCH` are **not** — you must bind them explicitly:
  ```bash
  apptainer exec --nv \
      --bind $WORK:$WORK \
      --bind $SCRATCH:$SCRATCH \
      container.sif <command>
  ```
- If the container expects data at a specific path, use `--bind /source:/target`.

**Building/pulling images:**
- Pull from Docker Hub or other registries (on login nodes only — no internet on compute):
  ```bash
  apptainer pull $WORK/my-image.sif docker://nvcr.io/nvidia/pytorch:24.01-py3
  ```
- SIF files can be large (5-20+ GB). Always store them in `$WORK`, never `$HOME`.
- Build custom images with `apptainer build` using a definition file.

**Common patterns in sbatch scripts:**
```bash
module load tacc-apptainer
apptainer exec --nv --bind $WORK:$WORK --bind $SCRATCH:$SCRATCH \
    $WORK/my-image.sif python train.py
```

## Port forwarding for model serving

Compute nodes are **not directly accessible** from outside the cluster. To reach a service (vLLM, Jupyter, TensorBoard, etc.) running on a compute node, you need an SSH tunnel.

**Step 1: Find the compute node hostname**
```bash
squeue -u $USER    # look at the NODELIST column
```
Or inside the job: `$SLURM_NODELIST` / `$(hostname)`.

**Step 2: Create an SSH tunnel from your local machine**
```bash
ssh -L <local_port>:<compute_node>:<service_port> <username>@ls6.tacc.utexas.edu
```
Example for vLLM on port 8000 running on node c316-002:
```bash
ssh -L 8000:c316-002:8000 sebale16@ls6.tacc.utexas.edu
```
Then access at `http://localhost:8000` on your local machine.

**Important:** The service inside the job must bind to `0.0.0.0`, not `127.0.0.1` (localhost). Localhost binding rejects connections from the SSH tunnel because it arrives via the node's network interface, not loopback.

For vLLM: `--host 0.0.0.0` (already correct in typical usage).

**Multi-hop tunneling** (if on a different network or VPN):
```bash
ssh -J <username>@ls6.tacc.utexas.edu -L <local_port>:<compute_node>:<service_port> <username>@ls6.tacc.utexas.edu
```

## Job debugging

**Job output files:**
- By default, Slurm writes all stdout and stderr to `slurm-<jobid>.out` in the submission directory.
- Customize with `#SBATCH -o <filename>` (stdout) and `#SBATCH -e <filename>` (stderr). Use `%j` for job ID: `#SBATCH -o job-%j.out`.
- To tail a running job's output: `tail -f slurm-<jobid>.out`.

**Checking job status and history:**
```bash
# While running or queued
squeue -u $USER
scontrol show job <jobid>

# After completion
sacct -j <jobid> --format=JobID,JobName,Elapsed,State,MaxRSS,MaxVMSize,ExitCode
```

**Common failure patterns:**

| Symptom | State / Exit code | Cause | Fix |
|---------|-------------------|-------|-----|
| Job killed, no error | `OUT_OF_MEMORY` or exit 137 | OOM — exceeded node memory | Reduce batch size, use fewer workers, request more nodes |
| Job killed at wall time | `TIMEOUT` | Exceeded `#SBATCH -t` limit | Increase time or checkpoint and resubmit |
| `module: command not found` | exit 127 | Missing `#!/bin/bash` or script not sourcing profile | Add `#!/bin/bash` as first line |
| `ModuleNotFoundError` (Python) | exit 1 | Venv not activated in job script | Add `source $WORK/my-venv/bin/activate` |
| Connection timeout / DNS error | exit 1 | Tried to download from internet on compute node | Pre-download on login node (see Network restrictions) |
| `Permission denied` on scratch | exit 1 | Files purged (untouched >10 days) | Re-stage data to `$SCRATCH` before resubmitting |
| `Invalid generic resource (gres)` | submit fails | Used `--gres` on a cluster that doesn't support it | Check cluster profile — LS6 does not use GRES |

**Email notifications:**
```bash
#SBATCH --mail-user=user@example.com
#SBATCH --mail-type=end,fail
```
Useful for long jobs — get notified on completion or failure without polling.

## Multi-node GPU jobs (vLLM, Ray, DeepSpeed, etc.)

For multi-node GPU serving or training on LS6:
- Each A100 node has 3 GPUs, each H100 node has 3 GPUs.
- Set `--tensor-parallel-size` to GPUs per node (3 on LS6 GPU partitions).
- Set `--pipeline-parallel-size` to number of nodes.
- Total GPUs = nodes x GPUs_per_node.
- Ray or other distributed frameworks handle inter-node communication — start a head node, then workers.
- Use `srun` to launch per-node processes within the sbatch script.

For multi-node GPU work on Vista (`gh` partition):
- Each node has exactly **1 GH200 GPU**.
- Total GPUs = number of nodes requested.
- Set `--tensor-parallel-size 1` and `--pipeline-parallel-size <N_nodes>`, or use tensor parallelism within the unified 480 GB memory of a single node.
- The large unified memory (480 GB/node) means many models that require multi-node on other clusters can fit on a single Vista node.
- Interconnect between nodes is InfiniBand (HDR); within-node, NVLink-C2C connects Grace CPU and Hopper GPU.

## Data transfer

- **Between TACC clusters:** Use `$STOCKYARD` (shared across clusters) or `rsync`/`scp` between login nodes.
- **External transfers:** Use `scp`, `rsync`, or `wget`/`curl` from login nodes. For large transfers, use Globus (TACC endpoints available).
- **Archival storage:** TACC provides Ranch (`ranch.tacc.utexas.edu`) for long-term tape archival.
