#!/bin/bash

#SBATCH --job-name=sphexa-gpu-debug
#SBATCH --output=logs/sphexa-gpu-debug-%j.out
#SBATCH --error=logs/sphexa-gpu-debug-%j.err

#SBATCH --gpus=rtx_4090:1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem-per-cpu=4096
#SBATCH --time=01:00:00

REPO_ROOT="sphexa"
BUILD_DIR="build/gpu-debug"
OUT_DIR="out/debug/$SLURM_JOB_ID"
EXECUTABLE="$BUILD_DIR/main/src/sphexa/sphexa-cuda"

module load stack/.2025-06-silent stack/2025-06
module load gcc/12.2.0 cmake/3.30.5 cuda/12.6.2 openmpi/4.1.7 hdf5/1.14.5
module list

make -C "$BUILD_DIR" -j sphexa-cuda

mkdir -p $OUT_DIR

echo "=== Node info ==="
echo "Hostname:        $(hostname)"
echo "SLURM nodelist:  $SLURM_JOB_NODELIST"
echo "SLURM partition: $SLURM_JOB_PARTITION"
echo "CPUs allocated:  $SLURM_CPUS_PER_TASK"

echo "=== CPU ==="
lscpu | grep -E 'Model name|Architecture|CPU\(s\):|Socket|Thread|Core|MHz|Flags'

echo "=== Memory ==="
free -h

echo "=== GPU ==="
nvidia-smi
nvidia-smi --query-gpu=name,driver_version,memory.total,compute_cap --format=csv

echo "=== Build info ==="
file "$EXECUTABLE"
readelf -p .comment "$EXECUTABLE" | head
echo "================="

export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK

# Pick a tool: memcheck (default) | racecheck | synccheck | initcheck.
# memcheck catches OOB device access, misaligned access, invalid free, leaks.
# initcheck catches reads of uninitialized device memory (good follow-up).
TOOL=${TOOL:-memcheck}

# --launch-timeout is per-kernel; bump if your kernels are slow under sanitizer.
# --report-api-errors=all surfaces failed CUDA API calls that are normally swallowed.
# --print-limit prevents truncation when many errors fire.
compute-sanitizer \
    --tool "$TOOL" \
    --launch-timeout 120 \
    --report-api-errors all \
    --print-limit 200 \
    --error-exitcode 42 \
    "$EXECUTABLE" \
    --init kelvin-helmholtz-magneto \
    --prop magneto-ve \
    --glass data/30c.h5 \
    -n 30 \
    -s 5 \
    -w 5 \
    -f x,y,z,rho,p,h,Bx,By,Bz \
    -o $OUT_DIR/dump.h5 \
    -op $OUT_DIR/profile
