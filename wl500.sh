#!/bin/sh

# 1. wget -O /tmp/wl500.sh http://dl.dropbox.com/u/737652/wl500.sh
# 2. sh /tmp/wl500.sh

IPV4_ADDRESS=""
WAN6_IFNAME="six1"

main()
{
    ipv6_proto=$(echo -n `nvram get ipv6_proto`)
        
    if [ "$ipv6_proto" != "ttk_6to4" ]; then
        set_nvram_vars
        echo "Done. Router will reboot."
        read
        autorun
        reboot
        exit  
    else
        sleep 15
        configure_tunnel
        configure_wan_default_gateway
        fix_ipv6_config
    fi
}
set_nvram_vars()
{
    if [ "$IPV4_ADDRESS" == "" ]; then
        IPV4_ADDRESS=$(echo -n `nvram get wan0_ipaddr`)
    fi
    ip=$(echo -n `printf '%02X:' ${IPV4_ADDRESS//./ } | awk -F: '{print($1$2":"$3$4)}'`)
    nvram set ipv6_proto="ttk_6to4"
    nvram set ipv6_sit_mtu="1280"
    nvram set ipv6_sit_ttl="64"
    nvram set ipv6_sit_relay="192.88.99.127"
    nvram set ipv6_lan_netsize="64"
    nvram set ipv6_wan_netsize="128"
    nvram set ipv6_lan_addr="2a02:2560:$ip::1"
    nvram set ipv6_wan_addr="2a02:2560:$ip::abcd"
    nvram set ipv6_radvd_enable="1"
    nvram commit
}

configure_tunnel()
{
    ipv6_sit_ttl=$(echo -n `nvram get ipv6_sit_ttl`)
    ipv6_sit_mtu=$(echo -n `nvram get ipv6_sit_mtu`)
    wan0_ipaddr=$(echo -n `nvram get wan0_ipaddr`) # IP
    ip tunnel add $WAN6_IFNAME mode sit remote any local $wan0_ipaddr ttl $ipv6_sit_ttl
    ip link set mtu $ipv6_sit_mtu dev $WAN6_IFNAME up
}

configure_wan_default_gateway()
{
    ipv6_sit_relay=$(echo -n ::`nvram get ipv6_sit_relay`)
    ip -6 route add default via $ipv6_sit_relay metric 1 dev $WAN6_IFNAME
}
fix_ipv6_config()
{
    lan_ifname=$(echo -n `nvram get lan_ifname`) # br0
    addrstr="$(echo -n `nvram get ipv6_wan_addr`)/$(echo -n `nvram get ipv6_wan_netsize`)"
    ip -6 addr del $addrstr dev vlan1
    ip -6 addr add $addrstr dev $WAN6_IFNAME
}
autorun()
{
    mkdir -p /usr/local/sbin/
    mv /tmp/wl500.sh /usr/local/sbin/post-boot
    chmod +x /usr/local/sbin/post-boot
    flashfs save && flashfs commit && flashfs enable
}
main
