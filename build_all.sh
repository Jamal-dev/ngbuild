#!/usr/bin/env bash
# Avoid -u (nounset) because some conda activate/deactivate hooks
# reference optional variables and fail under nounset.
set -eo pipefail

# One-command builder for Netgen, NGSolve, and ngsxfem into a clean conda env.
#
# Default locations:
#   - Conda env name: xfemcustom
#   - Install prefix: the conda env itself (no system pollution)
#   - Source and build directories: ${HOME}/Documents/xfemcustom/{src,build}
#
# Usage examples:
#   bash scripts/build_all.sh
#   bash scripts/build_all.sh --env xfemcustom --python 3.11 --root "$HOME/Documents/xfemcustom"
#   bash scripts/build_all.sh --rebuild   # force reconfigure and rebuild

ENV_NAME="xfemcustom"
PY_VER="3.11"
ROOT_DIR="${HOME}/Documents/xfemcustom"
REBUILD=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      ENV_NAME="$2"; shift 2;;
    --python)
      PY_VER="$2"; shift 2;;
    --root)
      ROOT_DIR="$2"; shift 2;;
    --rebuild)
      REBUILD=1; shift 1;;
    -h|--help)
      echo "Usage: $0 [--env NAME] [--python 3.11|3.12] [--root DIR] [--rebuild]"; exit 0;;
    *)
      echo "Unknown arg: $1"; exit 1;;
  esac
done

SRC_DIR="${ROOT_DIR}/src"
BUILD_DIR="${ROOT_DIR}/build"

mkdir -p "${SRC_DIR}" "${BUILD_DIR}"

echo "Using:" 
echo "  ENV_NAME = ${ENV_NAME}"
echo "  PY_VER   = ${PY_VER}"
echo "  ROOT_DIR = ${ROOT_DIR}"

if ! command -v conda >/dev/null 2>&1; then
  echo "Error: conda not found in PATH." >&2
  exit 1
fi

# Create env if missing
if ! conda env list | awk '{print $1}' | grep -qx "${ENV_NAME}"; then
  echo "Creating conda env ${ENV_NAME} (python=${PY_VER}) ..."
  conda create -y -n "${ENV_NAME}" python="${PY_VER}" -c conda-forge
fi

echo "Installing build dependencies into env ..."
# IMPORTANT: pin pybind11 to 2.12.* to match Netgen's vendored pybind11 (prevents ABI mismatch)
conda install -y -n "${ENV_NAME}" -c conda-forge \
  cmake ninja pkg-config make git \
  compilers ccache \
  eigen "pybind11=2.12.*" "pybind11-global=2.12.*" \
  occt tbb \
  openblas lapack \
  zlib \
  swig \
  pip

# Resolve python and prefix inside the env
PYTHON_BIN="$(conda run -n "${ENV_NAME}" python -c 'import sys; print(sys.executable)')"
CONDA_PREFIX_DIR="$(conda run -n "${ENV_NAME}" python -c 'import os; print(os.environ["CONDA_PREFIX"])')"

echo "Python: ${PYTHON_BIN}"
echo "Install prefix: ${CONDA_PREFIX_DIR}"

# Clone sources if missing
pushd "${SRC_DIR}" >/dev/null
  if [[ ! -d netgen ]]; then
    echo "Cloning Netgen ..."
    git clone --depth 1 https://github.com/NGSolve/netgen
  fi
  if [[ ! -d ngsolve ]]; then
    echo "Cloning NGSolve ..."
    git clone --depth 1 https://github.com/NGSolve/ngsolve
  fi
  if [[ ! -d ngsxfem ]]; then
    echo "Cloning ngsxfem ..."
    git clone --depth 1 https://github.com/ngsxfem/ngsxfem
  fi
popd >/dev/null

export CMAKE_PREFIX_PATH="${CONDA_PREFIX_DIR}:${CMAKE_PREFIX_PATH:-}"

configure_and_build() {
  local name="$1"; shift
  local src="$1"; shift
  local bld="$1"; shift
  echo "\n==> Configuring ${name} ..."
  if [[ ${REBUILD} -eq 1 && -d "${bld}" ]]; then
    rm -rf "${bld}"
  fi
  mkdir -p "${bld}"
  conda run -n "${ENV_NAME}" cmake -G Ninja \
    -S "${src}" -B "${bld}" "$@"
  echo "\n==> Building ${name} ..."
  conda run -n "${ENV_NAME}" cmake --build "${bld}" -j"$(nproc)"
  echo "\n==> Installing ${name} ..."
  conda run -n "${ENV_NAME}" cmake --install "${bld}"
}

# Build Netgen (no GUI, with OCC from conda)
configure_and_build netgen \
  "${SRC_DIR}/netgen" \
  "${BUILD_DIR}/netgen" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="${CONDA_PREFIX_DIR}" \
  -DUSE_OCC=ON \
  -DUSE_GUI=OFF \
  -DUSE_SUPERBUILD=OFF \
  -DPYTHON_EXECUTABLE="${PYTHON_BIN}" \
  -DOpenCASCADE_DIR="${CONDA_PREFIX_DIR}" \
  -DCMAKE_CXX_STANDARD=17

# Build NGSolve
configure_and_build ngsolve \
  "${SRC_DIR}/ngsolve" \
  "${BUILD_DIR}/ngsolve" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="${CONDA_PREFIX_DIR}" \
  -DNETGEN_DIR="${CONDA_PREFIX_DIR}" \
  -DUSE_GUI=OFF \
  -DUSE_MKL=OFF \
  -DUSE_OPENBLAS=ON \
  -DUSE_OCC=ON \
  -DPYTHON_EXECUTABLE="${PYTHON_BIN}" \
  -DCMAKE_CXX_STANDARD=17

# Build ngsxfem
configure_and_build ngsxfem \
  "${SRC_DIR}/ngsxfem" \
  "${BUILD_DIR}/ngsxfem" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="${CONDA_PREFIX_DIR}" \
  -DNGSOLVE_DIR="${CONDA_PREFIX_DIR}" \
  -DPYTHON_EXECUTABLE="${PYTHON_BIN}" \
  -DCMAKE_CXX_STANDARD=17

echo "\n==> Validating Python imports in env ${ENV_NAME} ..."
conda run -n "${ENV_NAME}" python - << 'PY'
import sys
print('Python:', sys.version)
import ngsolve
print('NGSolve:', ngsolve.__version__)
import ngsxfem
print('ngsxfem:', getattr(ngsxfem, '__file__', 'ok'))
try:
    import netgen.occ
    print('netgen.occ available')
except Exception as e:
    print('Warning: netgen.occ import failed:', e)
PY

echo "\n==> Done. To rebuild only ngsxfem quickly:"
echo "   bash scripts/rebuild_ngsxfem.sh --env ${ENV_NAME} --root ${ROOT_DIR}"
echo "==> To run your example with this env:"
echo "   bash scripts/run_example.sh --env ${ENV_NAME}"
