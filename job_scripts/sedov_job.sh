#!/bin/bash

#SBATCH --job-name=sedov
#SBATCH --output=logs/sphexa-%j.out
#SBATCH --error=logs/sphexa-%j.err

#SBATCH --nodes=1
#SBATCH --ntasks=4
#SBATCH --cpus-per-task=8
#SBATCH --mem-per-cpu=2048
#SBATCH --time=04:00:00
#SBATCH --gpus=rtx_4090:4

REPO_ROOT="sphexa"
BUILD_DIR="build/gpu"
OUT_DIR="out/$SLURM_JOB_ID"
EXECUTABLE="$BUILD_DIR/main/src/sphexa/sphexa-cuda"

module load stack/.2025-06-silent stack/2025-06
module load gcc/12.2.0 cmake/3.30.5 cuda/12.6.2 openmpi/4.1.7 hdf5/1.14.5
module load python/3.13.0
module list

make -C "$BUILD_DIR" clean
make -C "$BUILD_DIR" -j sphexa-cuda

mkdir -p $OUT_DIR

export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK

ARGS=(
    --init sedov-magneto
    --prop magneto-ve
    --glass data/50c.h5
    -n 250
    -s 0.021
    -w 0.02
    --wextra 0.005,0.01
    -f x,y,z,rho,h,Bx,By,Bz,alpha_B,gradB_norm
    -o "$OUT_DIR/dump.h5"
    -op "$OUT_DIR/profile"
)

# log metadata
{
    echo "Simulation: Sedov alpha_B=0.0"
    echo "start: $(date -Iseconds)"
    echo "slurm: $SLURM_JOB_ID"
    echo "command: $EXECUTABLE ${ARGS[*]}"
} >> "$OUT_DIR/info.log"

# run
$EXECUTABLE "${ARGS[@]}"

# Post-run metadata + plotting
python "$REPO_ROOT/scripts/log_run_info.py" "$OUT_DIR/info.log" "$OUT_DIR/dump.h5"
python "$REPO_ROOT/scripts/plot_constants.py" "$OUT_DIR/constants.txt"
# python "$REPO_ROOT/scripts/plot_profile.py" "logs/sphexa-$SLURM_JOB_ID.out" --out-dir "$OUT_DIR"
python "$REPO_ROOT/scripts/plot_slice.py" "$OUT_DIR/dump.h5" --all --axis y --cmap bone_r
python "$REPO_ROOT/scripts/plot_slice.py" "$OUT_DIR/dump.h5" --all --axis y --field magneto::alpha_B --cmap viridis