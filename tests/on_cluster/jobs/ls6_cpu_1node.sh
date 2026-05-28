#!/bin/bash
#SBATCH -J test-ls6-cpu-1node
#SBATCH -p development
#SBATCH -N 1
#SBATCH --ntasks-per-node 4
#SBATCH -t 00:05:00
#SBATCH -A ${TACC_ALLOCATION:-development}
#SBATCH -o ls6_cpu_1node.%j.out

hostname
echo "CPU cores available: $(nproc)"
echo "Architecture: $(uname -m)"
