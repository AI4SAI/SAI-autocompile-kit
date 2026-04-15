#!/bin/bash
#SBATCH --job-name=MACE
#SBATCH --partition=4V100
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --gpus-per-node=1
#SBATCH --qos=improper-gpu

nvidia-smi dmon -s pucvmte -o T > nvdmon_job-$SLURM_JOB_ID.log &

source {{ENV_SCRIPT}}

mace_run_train --config config.yaml
