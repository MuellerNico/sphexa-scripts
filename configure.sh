#!/bin/bash
module load stack/.2025-06-silent stack/2025-06
module load gcc/12.2.0 cmake/3.30.5 openmpi/4.1.7 hdf5/1.14.5 cuda/12.6.2
module list

REPO_ROOT="sphexa"
BUILD_DIR="build"

rm -rf "$BUILD_DIR/cpu" "$BUILD_DIR/cpu-debug" "$BUILD_DIR/gpu" "$BUILD_DIR/gpu-debug"

# CPU build
cmake -S "$REPO_ROOT" -B "$BUILD_DIR/cpu"

# CPU Debug build with ASAN+UBSAN. Sanitizers must be in both compile and link
# flags to be active at runtime.
cmake -S "$REPO_ROOT" -B "$BUILD_DIR/cpu-debug" \
    -DCMAKE_BUILD_TYPE=Debug \
    -DCMAKE_CXX_FLAGS="-fno-omit-frame-pointer -fsanitize=address,undefined" \
    -DCMAKE_C_FLAGS="-fno-omit-frame-pointer -fsanitize=address,undefined" \
    -DCMAKE_EXE_LINKER_FLAGS="-fsanitize=address,undefined"

# GPU build
CC=mpicc CXX=mpicxx cmake \
    -S "$REPO_ROOT" \
    -B "$BUILD_DIR/gpu" \
    -DCSTONE_WITH_GPU_AWARE_MPI=OFF \
    -DCMAKE_CUDA_FLAGS=-ccbin=mpicxx \
    -DCMAKE_CUDA_ARCHITECTURES="80;89" # RTX 4090 and A100

# GPU debug build for compute-sanitizer / cuda-gdb. Uses -lineinfo (cheap, gives
# source lines on errors) + host -g. Switch CUDA_FLAGS to "-G -g" if you need
# full device-side debugging — much slower but lets cuda-gdb step into kernels.
CC=mpicc CXX=mpicxx cmake \
    -S "$REPO_ROOT" \
    -B "$BUILD_DIR/gpu-debug" \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DCSTONE_WITH_GPU_AWARE_MPI=OFF \
    -DCMAKE_CUDA_FLAGS="-ccbin=mpicxx -lineinfo" \
    -DCMAKE_CXX_FLAGS="-g -fno-omit-frame-pointer" \
    -DCMAKE_CUDA_ARCHITECTURES="80;89"