#!/bin/bash

#@ /etc/strongswan/ipsec-vti.sh (Centos) or /etc/strongswan.d/ipsec-vti.sh (Ubuntu)

# AWS VPC Hardware VPN Strongswan updown Script

# Usage Instructions:
# Add "install_routes = no" to /etc/strongswan/strongswan.d/charon.conf or /etc/strongswan.d/charon.conf
# Add "install_virtual_ip = no" to /etc/strongswan/strongswan.d/charon.conf or /etc/strongswan.d/charon.conf
# For Ubuntu: Add "leftupdown=/etc/strongswan.d/ipsec-vti.sh" to /etc/ipsec.conf
# For RHEL/Centos: Add "leftupdown=/etc/strongswan/ipsec-vti.sh" to /etc/strongswan/ipsec.conf
# For RHEL/Centos 6 and below: git clone git://git.kernel.org/pub/scm/linux/kernel/git/shemminger/iproute2.git && cd iproute2 && make && cp ./ip/ip /usr/local/sbin/ip

# Adjust the below according to the Generic Gateway Configuration file provided to you by AWS.
# Sample: http://docs.aws.amazon.com/AmazonVPC/latest/NetworkAdminGuide/GenericConfig.html

IP=$(which ip)
IPTABLES=$(which iptables)



PLUTO_MARK_OUT_ARR=(${PLUTO_MARK_OUT//// })
PLUTO_MARK_IN_ARR=(${PLUTO_MARK_IN//// })

L1=/tmp/ipsec_vti_${PLUTO_CONNECTION}

echo IP=$(which ip) > $L1
echo IPTABLES=$(which iptables) >> $L1
env >> $L1
echo "PLUTO_MARK_OUT_ARR=$PLUTO_MARK_OUT_ARR" >> $L1
echo "PLUTO_MARK_IN_ARR=$PLUTO_MARK_IN_ARR" >> $L1
echo "PLUTO_MARK_OUT_ARR0=${PLUTO_MARK_OUT_ARR[0]}" >> $L1
echo "PLUTO_MARK_IN_ARR0=${PLUTO_MARK_IN_ARR[0]}"  >> $L1

case "$PLUTO_CONNECTION" in
  AWS-VPC-TUNNEL-1)
    VTI_INTERFACE=vti1
    VTI_LOCALADDR=169.254.218.82/30 #${pTunnel1CgwInsideIpAddress}
    VTI_REMOTEADDR=169.254.218.81/30 #${pTunnel1VgwInsideIpAddress}
    ;;
  AWS-VPC-TUNNEL-2)
    VTI_INTERFACE=vti2
    VTI_LOCALADDR=169.254.180.66/30 # ${pTunnel2CgwInsideIpAddress}
    VTI_REMOTEADDR=169.254.180.65/30 #${pTunnel2VgwInsideIpAddress}
    ;;
esac

        echo "$IP link add ${VTI_INTERFACE} type vti local ${PLUTO_ME} remote ${PLUTO_PEER} okey ${PLUTO_MARK_OUT_ARR[0]} ikey ${PLUTO_MARK_IN_ARR[0]}" >>$L1
        echo "sysctl -w net.ipv4.conf.${VTI_INTERFACE}.disable_policy=1" >>$L1
        echo "sysctl -w net.ipv4.conf.${VTI_INTERFACE}.rp_filter=2 || sysctl -w net.ipv4.conf.${VTI_INTERFACE}.rp_filter=0" >>$L1
        echo "$IP addr add ${VTI_LOCALADDR} remote ${VTI_REMOTEADDR} dev ${VTI_INTERFACE}" >>$L1
        echo "$IP link set ${VTI_INTERFACE} up mtu 1436" >>$L1
        echo "$IPTABLES -t mangle -I FORWARD -o ${VTI_INTERFACE} -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu" >>$L1
        echo "$IPTABLES -t mangle -I INPUT -p esp -s ${PLUTO_PEER} -d ${PLUTO_ME} -j MARK --set-xmark ${PLUTO_MARK_IN}" >>$L1
        echo "$IP route flush table 220" >>$L1

case "${!PLUTO_VERB}" in
    up-client)
        #$IP tunnel add ${VTI_INTERFACE} mode vti local ${PLUTO_ME} remote ${PLUTO_PEER} okey ${PLUTO_MARK_OUT_ARR[0]} ikey ${PLUTO_MARK_IN_ARR[0]}
        
        

        
        
        
        $IP link add ${VTI_INTERFACE} type vti local ${PLUTO_ME} remote ${PLUTO_PEER} okey ${PLUTO_MARK_OUT_ARR[0]} ikey ${PLUTO_MARK_IN_ARR[0]}
        sysctl -w net.ipv4.conf.${VTI_INTERFACE}.disable_policy=1
        sysctl -w net.ipv4.conf.${VTI_INTERFACE}.rp_filter=2 || sysctl -w net.ipv4.conf.${VTI_INTERFACE}.rp_filter=0
        $IP addr add ${VTI_LOCALADDR} remote ${VTI_REMOTEADDR} dev ${VTI_INTERFACE}
        $IP link set ${VTI_INTERFACE} up mtu 1436
        $IPTABLES -t mangle -I FORWARD -o ${VTI_INTERFACE} -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
        $IPTABLES -t mangle -I INPUT -p esp -s ${PLUTO_PEER} -d ${PLUTO_ME} -j MARK --set-xmark ${PLUTO_MARK_IN}
        $IP route flush table 220
        #/etc/init.d/bgpd reload || /etc/init.d/quagga force-reload bgpd
        ;;
    down-client)
      #$IP tunnel del ${VTI_INTERFACE}
      $IP link del ${VTI_INTERFACE}
      $IPTABLES -t mangle -D FORWARD -o ${VTI_INTERFACE} -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
      $IPTABLES -t mangle -D INPUT -p esp -s ${PLUTO_PEER} -d ${PLUTO_ME} -j MARK --set-xmark ${PLUTO_MARK_IN}
      ;;
esac

# Enable IPv4 forwarding
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv4.conf.eth0.disable_xfrm=1
sysctl -w net.ipv4.conf.eth0.disable_policy=1