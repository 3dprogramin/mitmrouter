#!/bin/bash

# VARIABLES
BR_IFACE="br0"
WAN_IFACE="enp10s0u2u1u2"

# wifi
WIFI_SSID="mywifi"
WIFI_PASSWORD="ultrasecure"
WIFI_IFACE="wlp4s0"

# 'virtual' LAN settings
LAN_IP="192.168.200.1"
LAN_SUBNET="255.255.255.0"
LAN_DHCP_START="192.168.200.10"
LAN_DHCP_END="192.168.200.200"
LAN_DNS_SERVER="1.1.1.1"

# config files
DNSMASQ_CONF="tmp_dnsmasq.conf"
HOSTAPD_CONF="tmp_hostapd.conf"

# SSL mitm proxy port
SSL_PORT=8081

# remove config files
rm -f $DNSMASQ_CONF
rm -f $HOSTAPD_CONF

# check if the user provided the correct arguments
if [ "$1" != "up" ] && [ "$1" != "down" ] || [ $# != 1 ]; then
    echo "missing required argument"
    echo "$0: <up/down>"
    exit
fi


# kill all services that might interfere
echo "== stop router services"
sudo killall wpa_supplicant
sudo killall dnsmasq
sudo killall sslsplit

# reset the network interfaces
echo "== reset all network interfaces"
sudo ifconfig $BR_IFACE 0.0.0.0
sudo ifconfig $BR_IFACE down
sudo ifconfig $WIFI_IFACE 0.0.0.0
sudo ifconfig $WIFI_IFACE down
sudo brctl delbr $BR_IFACE

if [ $1 = "up" ]; then
    # stop ufw firewall
    sudo systemctl stop ufw

    echo "== create dnsmasq config file"
    echo "interface=${BR_IFACE}" > $DNSMASQ_CONF
    echo "dhcp-range=${LAN_DHCP_START},${LAN_DHCP_END},${LAN_SUBNET},12h" >> $DNSMASQ_CONF
    echo "dhcp-option=6,${LAN_DNS_SERVER}" >> $DNSMASQ_CONF
    
    echo "create hostapd config file"
    echo "interface=${WIFI_IFACE}" > $HOSTAPD_CONF
    echo "bridge=${BR_IFACE}" >> $HOSTAPD_CONF
    echo "ssid=${WIFI_SSID}" >> $HOSTAPD_CONF
    echo "country_code=US" >> $HOSTAPD_CONF
    echo "hw_mode=g" >> $HOSTAPD_CONF
    echo "channel=11" >> $HOSTAPD_CONF
    echo "wpa=2" >> $HOSTAPD_CONF
    echo "wpa_passphrase=${WIFI_PASSWORD}" >> $HOSTAPD_CONF
    echo "wpa_key_mgmt=WPA-PSK" >> $HOSTAPD_CONF
    echo "wpa_pairwise=CCMP" >> $HOSTAPD_CONF
    echo "ieee80211n=1" >> $HOSTAPD_CONF
    #echo "ieee80211w=1" >> $HOSTAPD_CONF # PMF
    
    echo "== bring up interfaces and bridge"
    sudo ifconfig $WIFI_IFACE up
    sudo ifconfig $WAN_IFACE up
    sudo brctl addbr $BR_IFACE
    sudo ifconfig $BR_IFACE up
    
    echo "== setup iptables"
    sudo iptables --flush
    sudo iptables -t nat --flush
    sudo iptables -t nat -A POSTROUTING -o $WAN_IFACE -j MASQUERADE
    sudo iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
    sudo iptables -A FORWARD -i $BR_IFACE -o $WAN_IFACE -j ACCEPT
    
    # Add SSLsplit redirection rule
    # comment this two lines if you don't want to intercept SSL traffic (you can still view it with WireShark, but encrypted)
    echo "== setting up SSLsplit for traffic interception"
    sudo iptables -t nat -A PREROUTING -i $BR_IFACE -p tcp --dport 443 -j REDIRECT --to-ports $SSL_PORT
    
    echo "== setting static IP on bridge interface"
    sudo ifconfig br0 inet $LAN_IP netmask $LAN_SUBNET
    
    # start dnsmasq and hostapd
    echo "== starting dnsmasq"
    sudo dnsmasq -C $DNSMASQ_CONF

    echo "== starting hostapd"
    sudo hostapd $HOSTAPD_CONF
else
    # bring down the network
    echo "== bringing down the network and cleaning up"
    sudo killall hostapd
    sudo killall dnsmasq
    sudo killall sslsplit
    sudo ifconfig $BR_IFACE down
    sudo brctl delbr $BR_IFACE
    sudo iptables --flush
    sudo iptables -t nat --flush

    # start ufw firewall
    sudo systemctl start ufw
fi
