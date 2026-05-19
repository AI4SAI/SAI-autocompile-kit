#!/bin/bash
#SBATCH --job-name=QE
#SBATCH --partition=4V100
#SBATCH --nodes=1
#SBATCH --ntasks=4          # Nodes * GPUs-per-node * Ranks-per-GPU
#SBATCH --gpus-per-node=4   # Specify the GPUs-per-node
#SBATCH --qos=rush-gpu      # Depending on your needs [Priority: rush-* > improper-* = huge-* > flood-* = ultimate-*]

# CUDA-MPS and Rank-Map settings
source /opt/sai_config/mps_mapping.d/${SLURM_JOB_PARTITION}.bash

# Below are executing commands
nvidia-smi dmon -s pucvmte -o T > nvdmon_job-$SLURM_JOB_ID.log &
source {{ENV_SCRIPT}}
mpirun -np $SLURM_NTASKS --map-by $MAP_OPT pw.x -in pw.in > pw.out

# Must explicitly exit
exit
