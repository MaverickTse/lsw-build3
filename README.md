# lsw-build3 (2018)
Powershell and MSYS2-based L-SMASH Works build script.

Currently, this build AviUtl and VapourSynth plugins **ONLY**.

## Usage

Run the powershell script `lsw-bld3.ps1` with or without parameter. When invoked without a parameter, MSYS2 will be installed to `C:\MSYS64`. To specify installation folder, provide the folder path as a parameter.

No user intervention is required if everything goes smoothly. :tada:

## Building updates
Run `msys2.exe` then run the bash script `buildme.sh`

## Customization
The included bash script should be easy to customize as each function has detailed comments. Nevertheless, there are a few variables worthy to note:


| VARIABLE | USAGE |
|:--------:|:-----:|
|FORCE_REBUILD|When set to 1, will force every components to rebuild, even if git updates nothing|
|PATH_SANDBOX|The folder holding all the sources, libs and built file|
|PATH_PREFIX |Install destination for build scripts|
|URL_XXXXX   |Set where the sources should be downloaded from|

## Adding Components
The build instructions for each component are wrapped in individual functions that looks like:
```bash
PkgLSMASH()
{
	cd $HOME
	BuildPackage lsmash $URL_LSMASH "" 1 0 "" $FORCE_REBUILD
	pkg-config liblsmash --libs 
}
```
The key is `BuildPackage` with arguments `<name> <download URL> <extra build commands> <0 for out-of-source build> <1 to skip make install> <folder with patches> <1 to force rebuild>`. Note that the patching facilities may not work due to `-p0`. Note that `BuildPackage` does not work if `configure` or `CMakeLists.txt` resides in some strange location, as in the case of L-SMASH Works.

## Precautions
* MSYS2 internal change often, and may break without notice :fu: . Though this script is more robust than lsw-build2.
* FFmpeg API also changed quite a bit in recent time. Also breaks without notice :fu: .
* **DO NOT INSTALL CMake via PACMAN**. The CMake that comes with pacman has no MSYS Makefile generator :fu: .

## Peace-of-mind
Unlike lsw-build2, **these scripts makes no modification to MSYS2 internals**. You can go ahead to install gcc toolchains with pacman :tada:, just don't install cmake.
