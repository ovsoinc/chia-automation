#!/bin/sh

# update system and install deps
sudo apt update
sudo apt upgrade -y
sudo apt-get install tmux iftop git -y

# install zenith
curl -s https://api.github.com/repos/bvaisvil/zenith/releases/latest | grep browser_download_url | grep linux | cut -d '"' -f 4 | wget -qi -
rm zenith.x86_64-unknown-linux-musl.tgz.sha256
mv zenith.x86_64-unknown-linux-musl.tgz zenith.linux.tgz
tar xvf zenith.linux.tgz
chmod +x zenith
sudo mv zenith /usr/local/bin
rm zenith.linux.tgz

# go home and install chia
cd ~
git clone https://github.com/Chia-Network/chia-blockchain.git -b latest --recurse-submodules
cd chia-blockchain
sh install.sh

# activate and init chia
. ./activate
chia init
cd ..

# install plotman
sudo mkdir -p /home/ubuntu/tmpplots
sudo chmod 0777 /home/ubuntu/tmpplots
sudo mkdir -p /home/chia/chia/logs
sudo chmod 0777 /home/chia/chia/logs
pip install --force-reinstall git+https://github.com/ericaltendorf/plotman@main
mkdir -p  /home/ubuntu/.config/plotman
