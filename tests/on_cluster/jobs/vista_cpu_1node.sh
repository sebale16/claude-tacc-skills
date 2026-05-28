#!/bin/bash
#SBATCH -J test-vista-cpu-1node
#SBATCH -p gg
#SBATCH -N 1
#SBATCH --ntasks-per-node 4
#SBATCH -t 00:05:00
#SBATCH -A ${TACC_ALLOCATION:-development}
#SBATCH -o vista_cpu_1node.%j.out

# Grace-Grace node: ARM CPU only, no GPU
hostname
echo "Architecture: $(uname -m)"
echo "CPU cores available: $(nproc)"
module load nvpl
echo "nvpl loaded successfully"
