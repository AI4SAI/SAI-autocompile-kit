#!/bin/bash
#SBATCH --job-name=DP-train
#SBATCH --partition=4V100
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --gpus-per-node=1
#SBATCH --qos=improper-gpu

nvidia-smi dmon -s pucvmte -o T > nvdmon_job-$SLURM_JOB_ID.log &

source {{ENV_SCRIPT}}

export OMP_NUM_THREADS=2
export DP_INTERFACE_PREC=low
dp train input.json
dp freeze -o graph.pb
dp compress -i graph.pb -o compressed.pb