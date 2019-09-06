#!/bin/bash

# A Script to setup the cascoda-sdk on a fresh Raspberry Pi

# Use apt to update and get required packages
sudo apt update -y
sudo apt upgrade -y
sudo apt install automake gcc g++ git vim libtool lsb-release make libhidapi-dev libncurses5-dev -y

# Download latest cmake source, build, install
CMAKE_TARGET_VER=cmake-3.14.2
wget https://github.com/Kitware/CMake/releases/download/v3.14.2/${CMAKE_TARGET_VER}.tar.gz
tar -xf ${CMAKE_TARGET_VER}.tar.gz
cd ${CMAKE_TARGET_VER}
./bootstrap
make -j4
sudo make install
cd ../

#Add chili usb to the udev rules (So chili dongle can be used without sudo)
echo "SUBSYSTEMS==\"usb\", ATTRS{idVendor}==\"0416\", ATTRS{idProduct}==\"5020\", ACTION==\"add\", MODE=\"0666\"" > tmpfile
sudo mv tmpfile /etc/udev/rules.d/99-cascoda.rules
sudo udevadm control --reload-rules && udevadm trigger

# Clone the Cascoda sdk, set up build dir, configure
git clone https://github.com/Cascoda/cascoda-sdk.git
MACHINE_NAME="$(uname -m)"
mkdir build-${MACHINE_NAME}
cd build-${MACHINE_NAME}
cmake ../cascoda-sdk

# Build
make -j4

# Now all of the binaries are installed in ./bin/
# and can be run for instance ./bin/serial-adapter
