#!/bin/bash
#SBATCH --job-name=GPUMD
#SBATCH --partition=4V100
#SBATCH --nodes=1
#SBATCH --ntasks=1          # Nodes * GPUs-per-node * Ranks-per-GPU
#SBATCH --gpus-per-node=4   # Specify the GPUs-per-node
#SBATCH --qos=rush-gpu      # Depending on your needs [Priority: rush-* > improper-* = huge-* > flood-* = ultimate-*]

nvidia-smi dmon -s pucvmte -o T > nvdmon_job-$SLURM_JOB_ID.log &

source {{ENV_SCRIPT}}

# nep
gpumd
