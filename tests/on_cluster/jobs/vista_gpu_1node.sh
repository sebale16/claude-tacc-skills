#!/bin/bash
#SBATCH -J test-vista-gpu-1node
#SBATCH -p gh-dev
#SBATCH -N 1
#SBATCH --ntasks-per-node 1
#SBATCH -t 00:05:00
#SBATCH -A ${TACC_ALLOCATION:-development}
#SBATCH -o vista_gpu_1node.%j.out

# Grace-Hopper node: 1 GH200 GPU, ARM (aarch64)
# No --gres: GPUs are allocated by partition on Vista
hostname
echo "Architecture: $(uname -m)"
module load cuda/12.5
nvidia-smi
echo "GPU count: $(nvidia-smi --query-gpu=name --format=csv,noheader | wc -l)"
