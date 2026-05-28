#!/bin/bash
#SBATCH -J test-vista-gpu-2node
#SBATCH -p gh
#SBATCH -N 2
#SBATCH --ntasks-per-node 1
#SBATCH -t 00:05:00
#SBATCH -A ${TACC_ALLOCATION:-development}
#SBATCH -o vista_gpu_2node.%j.out

# 2x Grace-Hopper nodes: 1 GH200 per node (2 GPUs total across nodes)
# No --gres: GPUs are allocated by partition on Vista
hostname
echo "Architecture: $(uname -m)"
module load cuda/12.5
nvidia-smi --query-gpu=name --format=csv,noheader
