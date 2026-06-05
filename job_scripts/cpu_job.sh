#!/bin/bash

#SBATCH --job-name=sphexa-cpu
#SBATCH --output=logs/sphexa-cpu-%j.out
#SBATCH --error=logs/sphexa-cpu-%j.err

#SBATCH --ntasks=1
#SBATCH --cpus-per-task=128
#SBATCH --mem-per-cpu=1024
#SBATCH --time=04:00:00

REPO_ROOT="sphexa"
BUILD_DIR="build/cpu"
OUT_DIR="out/$SLURM_JOB_ID"
EXECUTABLE="$BUILD_DIR/main/src/sphexa/sphexa"

module load stack/.2025-06-silent stack/2025-06
module load gcc/12.2.0 cmake/3.30.5 openmpi/4.1.7 hdf5/1.14.5
module list

make -C "$BUILD_DIR" -j sphexa

mkdir -p $OUT_DIR

export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK

ARGS=(
    --init kelvin-helmholtz-magneto
    --prop magneto-ve
    --glass data/25c.h5
    -n 25
    -s 3.21
    -w 3.2
    --wextra 0.05,1,1.6,2,2.6
    -f x,y,z,rho,h,Bx,By,Bz,alpha_B,u
    -o "$OUT_DIR/dump.h5"
    -op "$OUT_DIR/profile"
)

# log metadata
{
    echo "start: $(date -Iseconds)"
    echo "slurm: $SLURM_JOB_ID"
    echo "command: $EXECUTABLE ${ARGS[*]}"
} >> "$OUT_DIR/info.log"

# run
$EXECUTABLE "${ARGS[@]}"

# Post-run metadata + plotting
python "$REPO_ROOT/scripts/log_run_info.py" "$OUT_DIR/info.log" "$OUT_DIR/dump.h5"
python "$REPO_ROOT/scripts/plot_constants.py" "$OUT_DIR/constants.txt"
python "$REPO_ROOT/scripts/plot_profile.py" "logs/sphexa-cpu-$SLURM_JOB_ID.out" --out-dir "$OUT_DIR"