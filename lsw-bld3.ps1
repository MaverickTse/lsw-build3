param(
    [string]$msysfolder = "C:\msys64"
)

# Enable TLS1.1 and 1.2
[System.Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls11

# Hardcoded constant section
$url_7z = "http://www.7-zip.org/a/7za920.zip"
$url_msys2base = "https://sourceforge.net/projects/msys2/files/Base/x86_64/"
$url_mingwbase = "https://sourceforge.net/projects/mingw-w64/files/Toolchains%20targetting%20Win32/"
$url_cmakebase = "https://cmake.org/download/"

# Functions

function Get-DiskSpace {
# Get Free Disk space on installation drive as GB
  param([string]$path)
  $drive = Split-Path -Path $path -Qualifier
  $drvfilter = "DeviceID='"+$drive+"'"
  $driveinfo = GWMI Win32_LogicalDisk -Filter $drvfilter
  $freespace = [Math]::Round($driveinfo.FreeSpace / 1GB)
  return $freespace
}

function Install-MSYS2 {
# Install MSYS2 to target folder
# Download Mingw-w64 if missing
  param([string]$path)
  $targetdrive = Split-Path -Path $path -Qualifier
  $temp = Join-Path -Path $targetdrive -ChildPath "msysinst"
  if(!(Test-Path -Path $path)){
    # Create a new installation if target folder does not exists
    $free = Get-DiskSpace -path $path
    if($free -lt 4){
      Write-Output "Need at least 4GB on installation drive!"
      Exit-PSSession 1
    }
    
    cd $targetdrive
    mkdir -Path $temp -Force | Out-Null
    cd $temp

    # Scrap Sourceforge download page for MSYS2
    # Requires TLS1.2
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    $url_msys2 = (Invoke-WebRequest -Uri $url_msys2base).Links | Where({$_.href -like "*.tar.xz*"}) | Select-Object -First 1 -ExpandProperty href
    #Write-Output $url_msys2

    # Download MSYS2 and 7zip
    Write-Output "Downloading 7zip and MSYS2"
    Start-BitsTransfer -Source $url_7z, $url_msys2 -Destination "7z.zip", "msys2.tar.xz"

    # Unpack 7zip
    Write-Output "Unpacking 7zip CLI"
    Expand-Archive -Path "./7z.zip" -DestinationPath "./" -Force

    # Unpack MSYS2
    Write-Output "Unpacking MSYS2"
    .\7za.exe x msys2.tar.xz | Out-Null
    # got msys2.tar
    rm msys2.tar.xz
    .\7za.exe x msys2.tar | Out-Null
    # Clean-up
    rm msys2.tar
    rm 7z.zip
    # Move to target folder
    mv msys64 $path

    # Initialize MSYS2
    # Ref: https://github.com/TeaCI/msys2-docker/blob/master/msys2-init
    Write-Output "Initializing MSYS2 installation..."
    cd $path
    .\msys2_shell.cmd -c "pacman -Syy --noconfirm --noprogressbar pacman" | Out-Null
    .\msys2_shell.cmd -c "pacman -Suu --needed --noconfirm --noprogressbar" | Out-Null
    .\msys2_shell.cmd -c "pacman -Suu --needed --noconfirm --noprogressbar && pacman -Scc --noconfirm" | Out-Null
    .\msys2_shell.cmd -c "pacman -S --needed --noconfirm --noprogressbar base-devel &&  pacman -Scc --noconfirm" | Out-Null
    .\msys2_shell.cmd -c "pacman -S --needed --noconfirm --noprogressbar VCS && pacman -Scc --noconfirm" | Out-Null
    .\msys2_shell.cmd -c "pacman -S --needed --noconfirm --noprogressbar yasm nasm nano p7zip unzip atool make pkg-config && pacman -Scc --noconfirm" | Out-Null
    .\msys2_shell.cmd -c "cp -f /usr/bin/false /usr/bin/tput" | Out-Null
    .\autorebase.bat | Out-Null
  
  }
  # End of MSYS2 base installation

  # Install CMake from Official Site
  # NEVER Install CMake package from pacman !!!
    cd $temp
    
    $url_cmake = (Invoke-WebRequest -Uri $url_cmakebase).Links | Where({$_.href -like "*x64.zip"})| Where ({$_.href -notlike "*rc*"}) | Select-Object -First 1 -ExpandProperty href
    Write-Output $url_cmake
    Invoke-WebRequest -Uri $url_cmake -OutFile "cmake.zip"
    Expand-Archive -Path "./cmake.zip" -DestinationPath "./" -Force
    $cmakeroot= ls -Name -Directory cmake*
    $cmakebin = Join-Path -Path $cmakeroot -ChildPath "/bin"
    $cmakeaclocal = Join-Path -Path $cmakeroot -ChildPath "/share/aclocal"
    $cmakesharefolder = ls -Name -Directory "$($cmakeroot)/share/cmake*"
    $cmakeshare = Join-Path -Path $cmakeroot -ChildPath "/share/$($cmakesharefolder)"
    Copy-Item -Path "$($cmakebin)\*.exe" -Destination $(Join-Path -Path $path -ChildPath "/usr/bin" )
    Copy-Item -Path "$($cmakeaclocal)\*.*" -Destination $(Join-Path -Path $path -ChildPath "/usr/share/aclocal")
    Copy-Item -Path $cmakeshare -Recurse -Container -Destination $(Join-Path -Path $path -ChildPath "/usr/share" )

  # Get Mingw-w64 SJLJ if missing
  $targetmingw = Join-Path -Path $path -ChildPath "i686-posix-sjlj"
  if(!(Test-Path -Path $targetmingw)){
    if(!(Test-Path -Path $temp)){
      mkdir -Path $temp -Force | Out-Null
    }
    cd $temp
    # Get Mingw-w64 Link
    $url_mingw = (Invoke-WebRequest -Uri $url_mingwbase).Links | Where({$_.href -like "*i686*posix-sjlj*"}) | Select-Object -First 1 -ExpandProperty href
    # Download Mingw-w64
    Write-Output "Downloading Mingw-w64 (32bit toolchain)"
    Start-BitsTransfer -Source $url_mingw -Destination i686-posix-sjlj.7z
    # DL 7zip if missing
    if(!(Test-Path -Path "./7za.exe")){
      Start-BitsTransfer -Source $url_7z -Destination "7z.zip"
      Expand-Archive -Path "./7z.zip" -DestinationPath "./" -Force
    }
    # Extract Mingw-w64
    ./7za.exe x i686-posix-sjlj.7z | Out-Null
    # Rename and move Mingw-w64
    $targetmingw = Join-Path -Path $path -ChildPath "i686-posix-sjlj"
    Write-Output $targetmingw
    mv mingw32 $targetmingw
  }
  cd $PSScriptRoot
  # Delete temp folder
  if(Test-Path -Path $temp){
    Remove-Item -Path $temp -Recurse -Force
  }
  # Copy build script
  Copy-Item -Path ".\*.sh" -Destination $(Join-Path -Path $path -ChildPath "/home/$($env:USERNAME)" )
  # Copy patch
  Copy-Item -Path ".\*.patch" -Destination $(Join-Path -Path $path -ChildPath "/home/$($env:USERNAME)" )
}



# MAIN
Clear-Host
Install-MSYS2 -path $msysfolder
Write-Output "Finished MSYS2 Setup"
Write-Output "Building..."
cd $msysfolder
$sw = [Diagnostics.Stopwatch]::StartNew()
.\msys2_shell.cmd -c "source ~/buildme.sh" | Out-Null
$sw.Stop()
$sw.Elapsed
Write-Output "AviUtl Plugins are inside ~/Sandbox/Install/lib"
Write-Output "L-SMASH binaries are inside ~/Sandbox/Install/bin"
Write-Output "To build updates, run $($msysfolder)/msys2.exe "
Write-Output "then invoke ./buildme "
