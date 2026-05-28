#!/bin/bash
#SBATCH -J test-ls6-gpu-a100-2node
#SBATCH -p gpu-a100
#SBATCH -N 2
#SBATCH --ntasks-per-node 1
#SBATCH -t 00:05:00
#SBATCH -A ${TACC_ALLOCATION:-development}
#SBATCH -o ls6_gpu_a100_2node.%j.out

# No --gres: GPUs are allocated by partition on LS6
# Each node gets all 3 A100s
hostname
module load cuda/12.2
nvidia-smi --query-gpu=name --format=csv,noheader
