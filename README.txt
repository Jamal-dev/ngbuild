Build overview
--------------

These scripts create an isolated conda env, build and install Netgen, NGSolve and ngsxfem into that env, and provide quick rebuild + run helpers.

Commands
 - One-shot build (env + clone + build + install):
   bash scripts/build_all.sh

   Options:
     --env NAME       Conda env name (default: xfemcustom)
     --python VER     Python 3.11 or 3.12 (default: 3.11)
     --root DIR       Root for sources/builds (default: ~/Documents/xfemcustom)
     --rebuild        Force a clean reconfigure of all three projects

 - Rebuild only ngsxfem quickly:
   bash scripts/rebuild_ngsxfem.sh --env xfemcustom --root ~/Documents/xfemcustom

 - Run the local example after install:
   bash scripts/run_example.sh --env xfemcustom

What gets installed and where
 - Everything installs into the conda env prefix ($CONDA_PREFIX of the chosen env).
 - No global paths are modified. CMake finds dependencies via CMAKE_PREFIX_PATH=$CONDA_PREFIX.

Notes
 - These builds assume Linux and a recent conda-forge toolchain (compilers, cmake, ninja).
 - The scripts enable OCC (OpenCascade) via the conda package 'occt' and disable GUIs to avoid Qt dependencies.
 - If you need GUI builds, enable USE_GUI=ON for Netgen/NGSolve and add Qt packages to the env.

