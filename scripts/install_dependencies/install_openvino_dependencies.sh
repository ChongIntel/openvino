#!/bin/bash

# Copyright (C) 2018-2022 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

set -e

#===================================================================================================
# Option parsing

default_comp=(core dev python myriad cl_compiler)
all_comp=(${default_comp[@]} opencv_req opencv_opt)
os=${os:-auto}

# public options
interactive=yes
dry=
extra=
print=
comp=()

# private options
keepcache=
selftest=

while :; do
    case $1 in
        -h|-\?|--help)
            echo "Options:"
            echo "  -y          non-interactive run (off)"
            echo "  -n          dry-run, assume no (off)"
            echo "  -c=<name>   install component <name>, can be repeated (${all_comp[*]})"
            echo "  -e          add extra repositories (RHEL 8) (off)"
            echo "  -p          print package list and exit (off)"
            exit
            ;;
        -y) interactive= ;;
        -n) dry=yes ;;
        -c=?*) comp+=("${1#*=}") ;;
        -e) extra=yes ;;
        -p) print=yes ;;
        --selftest) selftest=yes ;;
        --keepcache) keepcache=yes ;;
        *) break ;;
    esac
    shift
done

# No components selected - install default
if [ ${#comp[@]} -eq 0 ]; then
    comp=(${default_comp[@]})
fi

#===================================================================================================
#  Selftest

if [ -n "$selftest" ] ; then
    for image in ubuntu:18.04 ubuntu:20.04 ubuntu:21.10 ubuntu:22.04 redhat/ubi8 ; do
        for opt in  "-h" "-p" "-e -p" "-n" "-n -e" "-y" "-y -e" ; do
            echo "||"
            echo "|| Test $image / '$opt'"
            echo "||"
            SCRIPT_DIR="$( cd "$( dirname "$(realpath "${BASH_SOURCE[0]}")" )" >/dev/null 2>&1 && pwd )"
            docker run -it --rm \
                --volume ${SCRIPT_DIR}:/scripts:ro,Z  \
                --volume yum-cache:/var/cache/yum \
                --volume apt-cache:/var/cache/apt/archives \
                -e DEBIAN_FRONTEND=noninteractive \
                $image \
                bash /scripts/${0##*/} $opt --keepcache
            echo "||"
            echo "|| Completed: $image / '$opt'"
            echo "||"
        done
    done
    echo "Self test finished, to remove temporary docker volumes run:
        'docker volume rm yum-cache apt-cache'"
    exit 0
fi

#===================================================================================================
# OS detection

if [ "$os" == "auto" ] ; then
    os=$( . /etc/os-release ; echo "${ID}${VERSION_ID}" )
    if [[ "$os" =~ "rhel8".* ]] ; then
      os="rhel8"
    fi
    case $os in
        rhel8|rhel9.1|\
        raspbian9|debian9|ubuntu18.04|\
        raspbian10|debian10|ubuntu20.04|ubuntu20.10|ubuntu21.04|\
        raspbian11|debian11|ubuntu21.10|ubuntu22.04|\
        raspbian12|debian12|ubuntu22.10) [ -z "$print" ] && echo "Detected OS: ${os}" ;;
        *) echo "Unsupported OS: ${os:-detection failed}" >&2 ; exit 1 ;;
    esac
fi

#===================================================================================================
# Collect packages

extra_repos=()

if [ "$os" == "raspbian9" ] || [ "$os" == "debian9" ] ; then

    # proper versions of cmake and python should be installed separately, because the defaults are:
    # - python version is 3.5
    # - cmake version is 3.7.2
    # which are not supported by OpenVINO

    pkgs_core=()
    pkgs_python=()
    pkgs_dev=(pkg-config g++ gcc libc6-dev libgflags-dev zlib1g-dev nlohmann-json-dev make curl sudo)
    pkgs_myriad=(libusb-1.0-0)
    pkgs_cl_compiler=()

elif [ "$os" == "ubuntu18.04" ] ; then

    pkgs_core=(libtbb2 libpugixml1v5)
    pkgs_opencv_req=(libgtk-3-0 libgl1)
    pkgs_python=(python3 libpython3.6 python3-venv python3-pip)
    pkgs_dev=(cmake pkg-config g++ gcc libc6-dev libgflags-dev zlib1g-dev nlohmann-json-dev make curl sudo)
    pkgs_myriad=(libusb-1.0-0)
    pkgs_cl_compiler=(libtinfo5)
    pkgs_opencv_opt=(
        gstreamer1.0-plugins-bad
        gstreamer1.0-plugins-base
        gstreamer1.0-plugins-good
        gstreamer1.0-plugins-ugly
        gstreamer1.0-tools
        libavcodec57
        libavformat57
        libavresample3
        libavutil55
        libgstreamer1.0-0
        libswscale4
    )

elif [ "$os" == "ubuntu20.04" ] || [ "$os" == "debian10" ] || [ "$os" == "raspbian10" ] ||
     [ "$os" == "ubuntu21.10" ] || [ "$os" == "ubuntu22.04" ] || [ "$os" == "debian11" ] || [ "$os" == "raspbian11" ] ||
     [ "$os" == "ubuntu22.10" ] || [ "$os" == "debian12" ] || [ "$os" == "raspbian12" ]; then

    pkgs_core=(libpugixml1v5)
    pkgs_opencv_req=(libgtk-3-0 libgl1)
    pkgs_python=(python3 python3-venv python3-pip)
    pkgs_dev=(cmake pkg-config g++ gcc libc6-dev libgflags-dev zlib1g-dev nlohmann-json3-dev make curl sudo)
    pkgs_myriad=(libusb-1.0-0)
    pkgs_cl_compiler=(libtinfo5)
    pkgs_opencv_opt=(
        gstreamer1.0-plugins-bad
        gstreamer1.0-plugins-base
        gstreamer1.0-plugins-good
        gstreamer1.0-plugins-ugly
        gstreamer1.0-tools
        libavcodec58
        libavformat58
        libavutil56
        libgstreamer1.0-0
        libswscale5
    )

    if [ "$os" == "debian10" ] || [ "$os" == "raspbian10" ] ; then
        pkgs_core=(${pkgs_core[@]} libtbb2)
        pkgs_python=(${pkgs_python[@]} libpython3.7)
    elif [ "$os" == "ubuntu20.04" ] || [ "$os" == "ubuntu20.10" ] || [ "$os" == "ubuntu21.04" ] ; then
        pkgs_core=(${pkgs_core[@]} libtbb2)
        pkgs_python=(${pkgs_python[@]} libpython3.8)
        pkgs_opencv_opt=(${pkgs_opencv_opt[@]} libavresample4)
    elif [ "$os" == "ubuntu21.10" ] ||
         [ "$os" == "debian11" ] || [ "$os" == "raspbian11" ] ; then
        pkgs_core=(${pkgs_core[@]} libtbb2)
        pkgs_python=(${pkgs_python[@]} libpython3.9)
    elif [ "$os" == "ubuntu22.04" ] || [ "$os" == "ubuntu22.10" ] ||
         [ "$os" == "debian12" ] || [ "$os" == "raspbian12" ] ; then
        pkgs_core=(${pkgs_core[@]} libtbb12)
        pkgs_python=(${pkgs_python[@]} libpython3.10)
    fi

elif [ "$os" == "rhel8" ] || [ "$os" == "rhel9.1" ] ; then

    if [ "$os" == "rhel9.1" ] ; then
        pkgs_python=(python39 python3-pip)
    elif [ "$os" == "rhel8" ] ; then
        pkgs_python=(python38 python38-pip)
    fi

    pkgs_core=(libtbb2 libpugixml1v5)
    pkgs_opencv_req=(gtk3)
    pkgs_dev=(
        gcc gcc-c++ make glibc libstdc++ libgcc cmake pkg-config zlib-devel curl sudo
        https://vault.centos.org/centos/8/PowerTools/x86_64/os/Packages/gflags-2.1.2-6.el8.x86_64.rpm
    )
    pkgs_myriad=()
    pkgs_opencv_opt=(
        https://vault.centos.org/centos/8/AppStream/x86_64/os/Packages/libcdio-2.0.0-3.el8.x86_64.rpm
        https://vault.centos.org/centos/8/AppStream/x86_64/os/Packages/libtheora-1.1.1-21.el8.x86_64.rpm
        https://vault.centos.org/centos/8/AppStream/x86_64/os/Packages/opus-1.3-0.4.beta.el8.x86_64.rpm
        http://mirror.centos.org/centos/8-stream/AppStream/x86_64/os/Packages/orc-0.4.28-3.el8.x86_64.rpm
        http://mirror.centos.org/centos/8-stream/AppStream/x86_64/os/Packages/libglvnd-gles-1.3.4-1.el8.x86_64.rpm
        https://vault.centos.org/centos/8/AppStream/x86_64/os/Packages/libdvdread-5.0.3-9.el8.x86_64.rpm
        http://mirror.centos.org/centos/8-stream/AppStream/x86_64/os/Packages/libvisual-0.4.0-25.el8.x86_64.rpm
        https://vault.centos.org/centos/8/AppStream/x86_64/os/Packages/liba52-0.7.4-32.el8.x86_64.rpm
        https://vault.centos.org/centos/8/AppStream/x86_64/os/Packages/libdvdread-5.0.3-9.el8.x86_64.rpm
        https://vault.centos.org/centos/8/AppStream/x86_64/os/Packages/libXv-1.0.11-7.el8.x86_64.rpm
        https://vault.centos.org/centos/8/AppStream/x86_64/os/Packages/taglib-1.11.1-8.el8.x86_64.rpm
        https://vault.centos.org/centos/8/AppStream/x86_64/os/Packages/mpg123-libs-1.25.10-2.el8.x86_64.rpm
        https://vault.centos.org/centos/8/AppStream/x86_64/os/Packages/lame-libs-3.100-6.el8.x86_64.rpm
        https://vault.centos.org/centos/8/BaseOS/x86_64/os/Packages/libgudev-232-4.el8.x86_64.rpm
        https://vault.centos.org/centos/8/AppStream/x86_64/os/Packages/libv4l-1.14.2-3.el8.x86_64.rpm
        https://vault.centos.org/centos/8/AppStream/x86_64/os/Packages/speex-1.2.0-1.el8.x86_64.rpm
        https://vault.centos.org/centos/8/AppStream/x86_64/os/Packages/libraw1394-2.1.2-5.el8.x86_64.rpm
        https://vault.centos.org/centos/8/AppStream/x86_64/os/Packages/libsrtp-1.5.4-8.el8.x86_64.rpm
        https://vault.centos.org/centos/8/AppStream/x86_64/os/Packages/libvpx-1.7.0-8.el8.x86_64.rpm
        https://vault.centos.org/centos/8/AppStream/x86_64/os/Packages/wavpack-5.1.0-15.el8.x86_64.rpm
        https://vault.centos.org/centos/8/AppStream/x86_64/os/Packages/libiec61883-1.2.0-18.el8.x86_64.rpm
        https://vault.centos.org/centos/8/AppStream/x86_64/os/Packages/libshout-2.2.2-19.el8.x86_64.rpm
        https://vault.centos.org/centos/8/AppStream/x86_64/os/Packages/twolame-libs-0.3.13-12.el8.x86_64.rpm
        https://vault.centos.org/centos/8/AppStream/x86_64/os/Packages/libavc1394-0.5.4-7.el8.x86_64.rpm
        https://vault.centos.org/centos/8/AppStream/x86_64/os/Packages/libdv-1.0.0-27.el8.x86_64.rpm
        https://vault.centos.org/centos/8/AppStream/x86_64/os/Packages/libdvdnav-5.0.3-8.el8.x86_64.rpm
        https://vault.centos.org/centos/8/AppStream/x86_64/os/Packages/webrtc-audio-processing-0.3-9.el8.x86_64.rpm
        https://vault.centos.org/centos/8/AppStream/x86_64/os/Packages/gstreamer1-plugins-base-1.16.1-2.el8.x86_64.rpm
        https://vault.centos.org/centos/8/AppStream/x86_64/os/Packages/gstreamer1-1.16.1-2.el8.x86_64.rpm
        https://vault.centos.org/centos/8/AppStream/x86_64/os/Packages/gstreamer1-plugins-bad-free-1.16.1-1.el8.x86_64.rpm
        https://vault.centos.org/centos/8/AppStream/x86_64/os/Packages/gstreamer1-plugins-good-1.16.1-2.el8.x86_64.rpm
        https://vault.centos.org/centos/8/AppStream/x86_64/os/Packages/gstreamer1-plugins-ugly-free-1.16.1-1.el8.x86_64.rpm
        https://vault.centos.org/centos/8/AppStream/x86_64/os/Packages/soundtouch-2.0.0-3.el8.x86_64.rpm
    )
    extra_repos+=(https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm)

else
    echo "Internal script error: invalid OS (${os}) after check (package selection)" >&2
    exit 3
fi

#===================================================================================================
# Gather packages and print list

pkgs=()
for comp in ${comp[@]} ; do
    var=pkgs_${comp}[@]
    pkgs+=(${!var})
done

if [ ${#pkgs[@]} -eq 0 ]; then
    if  [ -n "$print" ] ; then
        echo "No packages to install" >&2
        exit 1
    else
        echo "No packages to install"
        exit 0
    fi
fi

if  [ -n "$print" ] ; then
    echo "${pkgs[*]}"
    exit 0
fi

#===================================================================================================
# Actual installation

if [ $EUID -ne 0 ]; then
    echo "ERROR: this script must be run as root to install 3rd party packages." >&2
    echo "Please try again with \"sudo -E $0\", or as root." >&2
    exit 1
fi

iopt=

if [ "$os" == "debian9" ] || [ "$os" == "raspbian9" ] || [ "$os" == "ubuntu18.04" ] ||
   [ "$os" == "debian10" ] || [ "$os" == "raspbian10" ] || [ "$os" == "ubuntu20.04" ] || [ "$os" == "ubuntu20.10" ] || [ "$os" == "ubuntu21.04" ] ||
   [ "$os" == "debian11" ] || [ "$os" == "raspbian11" ] || [ "$os" == "ubuntu21.10" ] || [ "$os" == "ubuntu22.04" ] ||
   [ "$os" == "debian12" ] || [ "$os" == "raspbian12" ] || [ "$os" == "ubuntu22.10" ] ; then

    [ -z "$interactive" ] && iopt="-y"
    [ -n "$dry" ] && iopt="--dry-run"
    [ -n "$keepcache" ] && rm -f /etc/apt/apt.conf.d/docker-clean

    apt-get update && apt-get install -y --no-install-recommends $iopt ${pkgs[@]}

elif [ "$os" == "rhel8" ] || [ "$os" == "rhel9.1" ] ; then

    [ -z "$interactive" ] && iopt="--assumeyes"
    [ -n "$dry" ] && iopt="--downloadonly"
    [ -n "$keepcache" ] && iopt="$iopt --setopt=keepcache=1"
    [ ${#extra_repos[@]} -ne 0 ] && yum localinstall $iopt --nogpgcheck ${extra_repos[@]}

    yum install $iopt ${pkgs[@]}

else
    echo "Internal script error: invalid OS (${os}) after check (package installation)" >&2
    exit 3
fi

exit 0
