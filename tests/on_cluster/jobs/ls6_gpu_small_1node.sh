#!/bin/bash
#SBATCH -J test-ls6-gpu-small-1node
#SBATCH -p gpu-a100-small
#SBATCH -N 1
#SBATCH --ntasks-per-node 1
#SBATCH -t 00:05:00
#SBATCH -A ${TACC_ALLOCATION:-development}
#SBATCH -o ls6_gpu_small_1node.%j.out

# gpu-a100-small: virtual node with 1 GPU slice (32 cores, 15 GB RAM)
# No --gres needed
hostname
module load cuda/12.2
nvidia-smi
echo "GPU count: $(nvidia-smi --query-gpu=name --format=csv,noheader | wc -l)"
