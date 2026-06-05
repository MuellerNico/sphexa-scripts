#!/bin/bash

#SBATCH --job-name=sphexa-cpu-debug
#SBATCH --output=logs/sphexa-cpu-debug-%j.out
#SBATCH --error=logs/sphexa-cpu-debug-%j.err

#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem-per-cpu=2048
#SBATCH --time=01:00:00

REPO_ROOT="sphexa"
BUILD_DIR="build/cpu-debug"
OUT_DIR="out/debug/$SLURM_JOB_ID"
EXECUTABLE="$BUILD_DIR/main/src/sphexa/sphexa"

module load stack/.2025-06-silent stack/2025-06
module load gcc/12.2.0 cmake/3.30.5 openmpi/4.1.7 hdf5/1.14.5
module list

make -C "$BUILD_DIR" -j sphexa

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
grep MemTotal /proc/meminfo

echo "=== Build info ==="
file "$EXECUTABLE"
readelf -p .comment "$EXECUTABLE" | head
ldd "$EXECUTABLE" | grep -i sanitiz
echo "================="

export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK

# Sanitizer runtime options:
# - detect_leaks=0: OpenMP/MPI leak on shutdown, drowns out the real signal
# - abort_on_error=1: dump core where the bug fires instead of trying to continue
# - print_stacktrace=1 (UBSAN): full backtrace on every UB hit
export ASAN_OPTIONS=detect_leaks=0:abort_on_error=1:halt_on_error=1
export UBSAN_OPTIONS=print_stacktrace=1:abort_on_error=1:halt_on_error=1

$EXECUTABLE \
    --init sedov-magneto \
    --prop magneto-ve \
    --glass data/50c.h5 \
    -n 50 \
    -s 5 \
    -w 5 \
    -f x,y,z,rho,p,h \
    -o $OUT_DIR/dump.h5 \
    -op $OUT_DIR/profile