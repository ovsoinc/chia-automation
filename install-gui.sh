#!/bin/sh

sudo apt-get update
sudo apt-get upgrade -y

# Install git
sudo apt install git -y

# Checkout the source and install
git clone https://github.com/Chia-Network/chia-blockchain.git -b latest --recurse-submodules
cd chia-blockchain

sh install.sh

. ./activate

# The GUI requires you have Ubuntu Desktop or a similar windowing system installed.
# You can not install and run the GUI as root

chmod +x ./install-gui.sh
./install-gui.sh

cd chia-blockchain-gui
npm run electron &
