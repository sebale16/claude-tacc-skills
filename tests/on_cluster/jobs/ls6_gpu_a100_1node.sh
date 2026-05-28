#!/bin/bash
#SBATCH -J test-ls6-gpu-a100-1node
#SBATCH -p gpu-a100-dev
#SBATCH -N 1
#SBATCH --ntasks-per-node 1
#SBATCH -t 00:05:00
#SBATCH -A ${TACC_ALLOCATION:-development}
#SBATCH -o ls6_gpu_a100_1node.%j.out

# No --gres: GPUs are allocated by partition on LS6
hostname
module load cuda/12.2
nvidia-smi
echo "GPU count: $(nvidia-smi --query-gpu=name --format=csv,noheader | wc -l)"
