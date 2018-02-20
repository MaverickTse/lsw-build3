#!/usr/bin/bash

FORCE_REBUILD=0

PATH_SANDBOX="$HOME/Sandbox"
PATH_SRC=$PATH_SANDBOX"/Src"
PATH_BLD=$PATH_SANDBOX"/BLD32"
PATH_PREFIX=$PATH_SANDBOX"/Install"

URL_ZLIB="https://github.com/madler/zlib.git"
URL_LCMS="https://github.com/mm2/Little-CMS.git"
URL_LIBPNG="https://github.com/glennrp/libpng.git"
URL_LIBTIFF="https://gitlab.com/libtiff/libtiff.git"
URL_OPENJPEG="https://github.com/uclouvain/openjpeg.git"
URL_LSMASH="https://github.com/l-smash/l-smash.git"
URL_FFMPEG="https://github.com/FFmpeg/FFmpeg.git"
URL_LSW="https://github.com/VFR-maniac/L-SMASH-Works.git"

printf "L-SMASH Works and FFmpeg Build Script (32bit) for MSYS2\n"
export MSYSTEM="MINGW32"
export MINGW_MOUNT_POINT="/i686-posix-sjlj"
export PATH="${MINGW_MOUNT_POINT}/bin:${PATH_PREFIX}/bin:$PATH"
export PKG_CONFIG_PATH="${PATH_PREFIX}/lib/pkgconfig:${PATH_PREFIX}/share/pkgconfig"
export ACLOCAL_PATH="${MINGW_MOUNT_POINT}/share/aclocal:/usr/share/aclocal"

export CC=gcc
export CXX=g++
export AR=ar
export WINDRES=windres

# NOTE: Uncommenting the following exports may cause build failures
#export CFLAGS=" -static -static-libgcc"
#export CPPFLAGS=" -static -static-libgcc -static-libstdc++"
#export CXXFLAGS=" -static -static-libgcc -static-libstdc++"
#export LDFLAGS=" -static "


GetDir()
# Get the path up to the directory
# Args:
#   $1: full/relative path
# Returns:
#	path to folder
{
	echo $(dirname $(readlink -f "$1"))
}

GetFilename()
# Get the filename from path
# Args:
#   $1: full/relative path
# Returns:
#	filename
{
	echo $(basename $(readlink -f "$1"))
}

BuildSystem()
# Guess what build system the folder is using
# Give preference to Cmake over autotools
# Args:
#   $1: folder path
# Returns:
#    1: CMAKE
#    2: Autotools with configure
#    4: Autotools without configure but with aclocal
#    8: A plain makefile
#  225: Unknown
{
	if [[ ! -d "$1" ]]; then
#		printf "%s is Missing" $1;
		echo 0;
		exit 0;
	fi
	
	if [[ -e "$1/CMakeLists.txt" ]]; then
#		printf "CMAKE";
		echo 1
		return;
	fi
	
	if [[ -e "$1/configure" ]]; then
#		printf "Configure";
		echo 2;
		return;
	fi
	
	if [[ -e "$1/aclocal.m4" ]]; then
#		printf "Autoreconf";
		echo 4;
		return;
	fi
	
	if [[ -e "$1/Makefile" ]]; then
#		printf "Make";
		echo 8;
		return;
	fi
#	printf "UNKNOWN";
	echo 255;
}

IsSVN()
# Determine if a URL points to a GIT/Subversion/Mercurial
# Args:
#   $1: the URL
# Returns:
#	0: No using version-management
#	1: GIT
#	2: Subversion
#	4: Mercurial
{
	if [[ $1 = *git* ]]; then
		echo 1;
		return;
	fi
	if [[ $1 = *svn* ]]; then
		echo 2;
		return;
	fi
	if [[ $1 = *hg* ]]; then
		echo 4;
		return;
	fi
	if [[ $1 = *mercurial* ]]; then
		echo 4;
		return;
	fi
	echo 0;
}

CreateFolder()
# Create the specified folder if missing
# Args:
#	$1: folder path
# Returns:
#	Exit if mkdir fails
{
	if [[ ! -d "$1" ]]; then
		mkdir -p "$1" || exit 1;
	fi
}

GitGet()
# Clone or update Git repo
# Args:
#	$1: package name
#	$2: URL
# Returns:
#	return 1 if newly cloned or updated
{
	local flag=0
	local pkgname=$1
	local url=$2
	local srcdir="$PATH_SRC/$pkgname"
	local originaldir=$(pwd)
	if [[ ! -d "$srcdir" ]]; then
		git clone --recursive $url $srcdir || exit 1;
		flag=1;
	else
		cd "$srcdir";
		local response=$(git pull|head -n1);
		if [[ $response != *Already* ]]; then
			flag=1;
		fi
	fi
	cd "$originaldir";
	echo $flag;
}

SVNGet()
# Clone or update Subversion repo
# Args:
#	$1: package name
#	$2: URL
# Returns:
#	return 1 if newly cloned or updated
{
	local flag=0
	local pkgname=$1
	local url=$2
	local srcdir="$PATH_SRC/$pkgname"
	local originaldir=$(pwd)
	if [[ ! -d "$srcdir" ]]; then
		svn checkout $url $srcdir || exit 1;
		flag=1;
	else
		cd "$srcdir";
		local response=$(svn update|wc -l);
		if [[ $response -gt 2 ]]; then
			flag=1;
		fi
	fi
	cd "$originaldir";
	echo $flag;
}

HGGet()
# Clone or update Mercurial repo
# Args:
#	$1: package name
#	$2: URL
# Returns:
#	return 1 if newly cloned or updated
{
	local flag=0
	local pkgname=$1
	local url=$2
	local srcdir="$PATH_SRC/$pkgname"
	local originaldir=$(pwd)
	if [[ ! -d "$srcdir" ]]; then
		hg clone $url $srcdir || exit 1;
		flag=1;
	else
		cd "$srcdir";
		local response=$(hg pull -u|wc -l);
		if [[ $response -gt 3 ]]; then
			flag=1;
		fi
	fi
	cd "$originaldir";
	echo $flag;
}

RepoGet()
# A Wrapper for GitGet, SVNGet and HGGet
# Calls approriate function depending on the URL
# Args:
#	$1: package name
#	$2: URL
# Returns:
#	return 1 if newly cloned or updated
{
	local pkgname=$1
	local url=$2
	local repoflag=$(IsSVN $url)
	local buildflag=0
	case $repoflag in
	"1")
		buildflag=$(GitGet $pkgname $url)
		;;
	"2")
		buildflag=$(SVNGet $pkgname $url)
		;;
	"3"|"4")
		buildflag=$(HGGet $pkgname $url)
		;;
	*)
		echo "Not a repo URL";
		exit 1;
		;;
	esac
	echo $buildflag
}

ArchiveGet()
# Download source archives, i.e. tar, zip, 7z...
# Depends on atool
# Args:
#	$1: package name
#	$2: URL
# Returns:
#	Always returns 1
{
	local pkgname=$1
	local url=$2
	local dltemp="$PATH_SANDBOX\DL"
	local originalfolder=$(pwd)
	if [[ -d "$dltemp" ]]; then
		rm -rf "$dltemp";
	fi
	CreateFolder "$dltemp"
	cd "$dltemp"
	wget "$url"
	local archivename=$(ls -p | grep -v '/$' | head -n1)
	atool -X ./expanded "$archivename"
	local cmakecount=$(find -O2 . -iwholename cmakelists.txt| wc -l)
	local configurecount=$(find -O2 . -iwholename configure| wc -l)
	local makecount=$(find -O2 . -iname makefile| wc -l)
	local firsttarget=""
	if [[ $cmakecount -gt 0 ]]; then
		firsttarget=$(find -O2 . -iwholename cmakelists.txt -printf "%d %p\n"|sort -n|perl -pe 's/^\d+\s//;'|head -n1)
	elif [[ $configurecount -gt 0 ]]; then
		firsttarget=$(find -O2 . -iwholename configure -printf "%d %p\n"|sort -n|perl -pe 's/^\d+\s//;'|head -n1)
	elif [[ $makecount -gt 0 ]]; then
		firsttarget=$(find -O2 . -iname makefile -printf "%d %p\n"|sort -n|perl -pe 's/^\d+\s//;'|head -n1)
	else
		exit 1
	fi
	local foldertomove=$(GetDir "$firsttarget")
	local movedest="$PATH_SRC/$pkgname"
	mv "$foldertomove" "$movedest" || exit 1
	cd "$originalfolder"
	rm -rf "$dltemp"
	echo 1
}

BuildPackage()
# Attempts to build a package
# Args:
#	$1: package name, no space
#	$2: Repo or archive URL
#	$3: extra arguments for CMake/configure
#	$4: set to 1 to disable out-of-source build
#	$5: set to 1 to disable Install step
#	$6: folder containing patch(es)
#	$7: set to 1 to force rebuild
# Returns:
#	None. This either fails and exits or proceed on success
{
	local pkgname=$1
	local url=$2
	local args=$3
	local outsrc=$4
	local noinst=$5
	local patchfolder=$6
	local rebuild=$7
	local srcfolder="$PATH_SRC/$pkgname"
	
	# Download and extract stuff
	local urltype=$(IsSVN $url)
	local buildflag=0
	cd "$HOME"
	case $urltype in
	"1"|"2"|"4")
		buildflag=$(RepoGet $pkgname $url)
		;;
	*)
		buildflag=$(ArchiveGet $pkgname $url)
		;;
	esac
	
	if [[ $rebuild -eq 1 ]]; then
		buildflag=1
	fi
	
	local buildsys=$(BuildSystem $srcfolder)
	echo "buildflag=${buildflag}"
	echo "buildsys=${buildsys}"
	# Patching
	if [[ -d "$patchfolder" ]]; then
		cp $patchfolder\*.patch $srcfolder
		cd "$srcfolder"
		for pfile in *.patch
		do
			patch -p0 -b -t -i $pfile
		done
		rm *.patch
		cd "$HOME"
	fi
	
	# Building
	if [[ $outsrc -eq 1 ]]; then
		cd "$srcfolder"
		case $buildsys in
		"1")
			if [[ $buildflag -eq 1 ]]; then
			cmake \
			 -G"MSYS Makefiles" \
			 -DCMAKE_INSTALL_PREFIX="${PATH_PREFIX}" \
			 -DCMAKE_BUILD_TYPE=Release \
			 $args || exit $?;
			 
			 make -j$(nproc) || exit $?;
			 fi
			 if [[ $noinst -ne 1 ]]; then
				make install || exit $?;
			 fi			 
			 ;;
		"2")
			if [[ $buildflag -eq 1 ]]; then
			./configure --prefix=$PATH_PREFIX  $args || exit $?;
			make -j$(nproc) || exit $?;
			fi
			if [[ $noinst -ne 1 ]]; then
				make install || exit $?;
			fi
			;;
		"4")
			if [[ $buildflag -eq 1 ]]; then
			autoreconf -ivf || exit $?
			./configure --prefix=$PATH_PREFIX  $args || exit $?;
			make -j$(nproc) || exit $?;
			fi
			if [[ $noinst -ne 1 ]]; then
				make install || exit $?;
			fi
			;;
		"8")
			if [[ $buildflag -eq 1 ]]; then
			$args make -j$(nproc) || exit $?;
			fi
			if [[ $noinst -ne 1 ]]; then
				make install || exit $?;
			fi
			;;
		*)
			exit 1;
			;;
		esac
	else
		local bldfolder="$PATH_BLD/$pkgname";
		CreateFolder "$bldfolder";
		cd "$bldfolder";
		case $buildsys in
		"1")
			if [[ $buildflag -eq 1 ]]; then
			cmake \
			 -G"MSYS Makefiles" \
			 -DCMAKE_INSTALL_PREFIX="${PATH_PREFIX}" \
			 -DCMAKE_BUILD_TYPE=Release \
			 $args $srcfolder || exit $?;
			 
			make -j$(nproc) || exit $?;
			fi
			if [[ $noinst -ne 1 ]]; then
				make install || exit $?;
			fi
			;;
		"2")
			if [[ $buildflag -eq 1 ]]; then
			source ${srcfolder}/configure --prefix=$PATH_PREFIX  $args || exit $?;
			make -j$(nproc) || exit $?;
			fi
			if [[ $noinst -ne 1 ]]; then
				make install || exit $?;
			fi
			;;
		"4")
			if [[ $buildflag -eq 1 ]]; then
			cd "$srcfolder";
			autoreconf -ivf || exit $?;
			cd "$bldfolder";
			source ${srcfolder}/configure --prefix=$PATH_PREFIX  $args || exit $?;
			make -j$(nproc) || exit $?;
			fi
			if [[ $noinst -ne 1 ]]; then
				make install || exit $?;
			fi
			;;
		*)
			# Note: a MakeFile-only build system usually can only be run in source folder
			# Correct me if I am wrong
			exit 1;
			;;
		esac
	fi
	cd "$HOME"
		
}

PkgZLIB()
{
	cd $HOME
	BuildPackage zlib $URL_ZLIB "" 0 0 "" $FORCE_REBUILD
	pkg-config zlib --libs 
}

PkgLSMASH()
{
	cd $HOME
	BuildPackage lsmash $URL_LSMASH "" 1 0 "" $FORCE_REBUILD
	pkg-config liblsmash --libs 
}

PkgFFMPEG()
{
	cd $HOME
	echo Building FFmpeg libraries. This will take quite a while.
	BuildPackage ffmpeg $URL_FFMPEG " --target-os=mingw32 --disable-shared --disable-debug --disable-programs --disable-doc --enable-static --enable-avresample --enable-gpl --enable-version3 --enable-runtime-cpudetect --enable-avisynth " 1 0 "" $FORCE_REBUILD
		
}

PkgLSWAVIUTL()
{
	# Since this dependece on a number of components, esp. FFmpeg. Always rebuild.
	cd $HOME
	GitGet lsw $URL_LSW
	cd "${PATH_SRC}/lsw/common"
	cp $HOME/LSWAviUtl*.patch ./
	for pfile in *.patch
		do
			patch -p0 -b -t -i $pfile
		done
	rm *.patch
	cd "${PATH_SRC}/lsw/AviUtl"
	./configure --prefix=$PATH_PREFIX  --extra-cflags="-static-libgcc -static-libstdc++" --extra-ldflags=" -static "|| exit $?
	make || exit $?
	printf "%d\n" $?
	cp ${PATH_SRC}/lsw/AviUtl/*.au? ${PATH_PREFIX}/lib || exit $?
	cd $HOME
	
}

PkgLSWVAP()
{
	# Since this depends on a number of components, esp. FFmpeg. Always rebuild.
	cd $HOME
	GitGet lsw $URL_LSW
	cd "${PATH_SRC}/lsw/VapourSynth"
	cp $HOME/LSWVAP*.patch ./
	for pfile in *.patch
		do
			patch -p0 -b -t -i $pfile
		done
	rm *.patch
	cd "${PATH_SRC}/lsw/VapourSynth"
	./configure --prefix=$PATH_PREFIX  --target-os=mingw32 --extra-cflags="-static-libgcc -static-libstdc++" --extra-ldflags=" -static "|| exit $?
	make || exit $?
	printf "%d\n" $?
	cp ${PATH_SRC}/lsw/VapourSynth/*.dll ${PATH_PREFIX}/lib || exit $?
	cd $HOME
	
}

########## MAIN STARTS HERE ###############
clear
cd $HOME
CreateFolder $PATH_SANDBOX
CreateFolder $PATH_SRC
CreateFolder $PATH_BLD
CreateFolder $PATH_PREFIX

PkgZLIB
PkgLSMASH
PkgFFMPEG
PkgLSWAVIUTL
PkgLSWVAP
