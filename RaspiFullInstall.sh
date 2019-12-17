#!/bin/bash

# A Script to setup the cascoda-sdk on a fresh Raspberry Pi

# Function to die with error
die() { echo "Error: " "$*" 1>&2 ; exit 1; }

# Use apt to update and get required packages
sudo apt update -y || die "sudo apt update"
sudo apt upgrade -y || die "sudo apt upgrade"
sudo apt install automake gcc g++ git vim libtool lsb-release make libhidapi-dev libncurses5-dev -y || die "sudo apt install"

# Check if cmake is already installed
CMAKE_VER=$(cmake --version 2> /dev/null | awk '
	/cmake version/{
		n=split($3,version,".");
		if(version[1] > 3 || (version[1] == 3 && version[2] >= 13))
		{
			print "done"
		}
		else
		{
			print "install"
		}
	}')

# If not installed, check how best to install it
if [ "$CMAKE_VER" == install ] || [ -z "$CMAKE_VER" ]
then
	# Check if the apt version of cmake is sufficient
	CMAKE_VER=$(apt-cache policy cmake | awk '
	/Candidate/{
		n=split($2,version,".");
		if(version[1] > 3 || (version[1] == 3 && version[2] >= 13))
		{
			print "apt"
		}
		else 
		{
			print "source"
		}
	}')
fi

if [ "$CMAKE_VER" == source ]
then
	# Download latest cmake source, build, install
	echo "Installing CMake from source"
	CMAKE_TARGET_VER=cmake-3.14.2
	wget https://github.com/Kitware/CMake/releases/download/v3.14.2/${CMAKE_TARGET_VER}.tar.gz || die "downloading cmake"
	tar -xf ${CMAKE_TARGET_VER}.tar.gz || die "extracting cmake"
	cd ${CMAKE_TARGET_VER}
	./bootstrap || die "bootstrap cmake"
	make -j4 || die "making cmake"
	sudo make install || die "installing cmake"
	cd ../
	CMAKE_VER="done"
fi

if [ "$CMAKE_VER" == apt ]
then
	# Install cmake from apt
	echo "Installing CMake from apt"
	sudo apt install cmake || die "installing cmake from apt"
	# Install ccmake (we allow this to fail)
	sudo apt install cmake-curses-gui
	CMAKE_VER="done"
fi

if [ "$CMAKE_VER" != done ]
then
	die "CMake could not be installed!"
else
	echo "CMake installed!"
fi

# Add chili usb to the udev rules (So chili dongle can be used without sudo)
echo 'SUBSYSTEMS=="usb", ATTRS{idVendor}=="0416", ATTRS{idProduct}=="5020", ACTION=="add", MODE="0666"' | sudo tee /etc/udev/rules.d/99-cascoda.rules > /dev/null
sudo udevadm control --reload-rules && sudo udevadm trigger

# Clone the Cascoda sdk, set up build dir, configure
# Pull if already exists, otherwise clone.
if [ -d cascoda-sdk/.git ]
then
	git pull -C cascoda-sdk || die "Failed to pull"
else
	git clone https://github.com/Cascoda/cascoda-sdk.git cascoda-sdk || die "Failed to clone"
fi

# Make a build directory and cd in
MACHINE_NAME="$(uname -m)"
mkdir build-${MACHINE_NAME}
cd build-${MACHINE_NAME}

# Configure with cmake
cmake ../cascoda-sdk || die "Failed to configure"

# Build
make -j4 || die "Failed to build"

echo "Cascoda binaries built into ./build-${MACHINE_NAME}/bin"
# Now all of the binaries are installed in ./bin/
# and can be run for instance ./bin/serial-adapter
