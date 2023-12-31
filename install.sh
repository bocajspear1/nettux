#!/bin/bash

if [ "$EUID" -ne 0 ]; then
    echo "Must be run as root"
    exit
fi

COLOR_RED="\e[1;31m"
COLOR_BLUE="\e[1;34m"
COLOR_GREEN="\e[1;32m"
COLOR_ORANGE="\e[1;33m"
COLOR_RESET="\e[0m"

apt-get update
echo -e "${COLOR_BLUE}Installing packages...${COLOR_RESET}"

echo "wireshark-common wireshark-common/install-setuid boolean true" | debconf-set-selections

DEBIAN_FRONTEND=noninteractive apt-get install -y virtualbox-guest-utils virtualbox-guest-x11 open-vm-tools-desktop python3-pip python3-venv mininet python3-tk wireshark tcpdump wget curl mousepad netcat-openbsd socat inetutils-traceroute software-properties-common gnupg apt-transport-https lsb-release

echo -e "${COLOR_BLUE}Installing FRR...${COLOR_RESET}"
# add GPG key
curl -s https://deb.frrouting.org/frr/keys.gpg | tee /usr/share/keyrings/frrouting.gpg > /dev/null

# possible values for FRRVER: frr-6 frr-7 frr-8 frr-9 frr-stable
# frr-stable will be the latest official stable release
FRRVER="frr-stable"
echo deb '[signed-by=/usr/share/keyrings/frrouting.gpg]' https://deb.frrouting.org/frr \
     $(lsb_release -s -c) $FRRVER | tee -a /etc/apt/sources.list.d/frr.list

# update and install FRR
apt update && apt install -y frr frr-pythontools

echo -e "${COLOR_BLUE}Installing Faucet...${COLOR_RESET}"
mkdir -p /etc/apt/keyrings/
curl -1sLf https://packagecloud.io/faucetsdn/faucet/gpgkey | gpg --dearmor -o /etc/apt/keyrings/faucet.gpg
echo "deb [signed-by=/etc/apt/keyrings/faucet.gpg] https://packagecloud.io/faucetsdn/faucet/$(lsb_release -si | awk '{print tolower($0)}')/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/faucet.list
apt-get update
apt-get install -y faucet python-faucet

echo -e "${COLOR_BLUE}Enabling forwarding...${COLOR_RESET}"
echo "net.ipv4.ip_forward=1" | tee --append /etc/sysctl.conf
echo "net.ipv6.conf.all.forwarding=1" | tee --append /etc/sysctl.conf
sysctl -p

echo -e "${COLOR_BLUE}Installing custom scripts...${COLOR_RESET}"
chmod +x ./scripts/*
cp ./scripts/* /usr/local/bin/

echo -e "${COLOR_BLUE}Installing custom apps...${COLOR_RESET}"
cp -r ./apps/minieditng /opt/minieditng

echo -e "${COLOR_BLUE}Installing custom .desktop files...${COLOR_RESET}"
cp ./desktop/* /usr/share/applications/

# https://askubuntu.com/questions/944685/pasting-external-text-into-xterm-or-uxterm
echo -e "${COLOR_BLUE}Install xterm copy-paste fixes...${COLOR_RESET}"
for homedir in /home/*; do cp ./configs/Xresources "${homedir}/.Xresources"; done

cp ./configs/Xresources /root/.Xresources

echo -e "${COLOR_BLUE}Install topologies${COLOR_RESET}"
mkdir -p /opt/topologies
cp ./examples/* /opt/topologies
chmod 444 /opt/topologies/*


echo -e "${COLOR_BLUE}Using Firefox DEB to save space from snaps...${COLOR_RESET}"
snap remove --purge firefox
apt remove --autoremove firefox

add-apt-repository -y ppa:mozillateam/ppa
apt update

echo '
Package: *
Pin: release o=LP-PPA-mozillateam
Pin-Priority: 1001
' | tee /etc/apt/preferences.d/mozilla-firefox


echo 'Unattended-Upgrade::Allowed-Origins:: "LP-PPA-mozillateam:${distro_codename}";' | sudo tee /etc/apt/apt.conf.d/51unattended-upgrades-firefox

apt-get install -y firefox
