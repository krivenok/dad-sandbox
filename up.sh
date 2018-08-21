#!/bin/bash

BASE_IF=$1

if [[ -z $BASE_IF ]] ; then
  echo "usage: up.sh <BASE_INTERFACE>"
  exit 1
fi

CLIENT="client"
SERVER="server"
BAD_GUY="bad_guy"

CLIENT_IPV4=10.5.5.5
SERVER_IPV4=10.5.5.10
# Bad guy has the same IP as our server
BAD_GUY_IPV4=10.5.5.10
PREFIX_IPV4=24

VLAN=10
VLAN_CLIENT_IPV4=10.10.10.5
VLAN_SERVER_IPV4=10.10.10.10
# Bad guy has the same IP as our server
VLAN_BAD_GUY_IPV4=10.10.10.10
VLAN_PREFIX_IPV4=24

ARP_FILTER=1
ARP_IGNORE=1

# Create MACVLAN interfaces (bridge mode is important)
ip link add name ${CLIENT}.mvl link $BASE_IF type macvlan mode bridge
ip link add name ${SERVER}.mvl link $BASE_IF type macvlan mode bridge
ip link add name ${BAD_GUY}.mvl link $BASE_IF type macvlan mode bridge

# Create MACVLAN interfaces to be used as a parent of VLAN interfaces (bridge mode is important)
ip link add name ${CLIENT}.vmvl link $BASE_IF type macvlan mode bridge
ip link add name ${SERVER}.vmvl link $BASE_IF type macvlan mode bridge
ip link add name ${BAD_GUY}.vmvl link $BASE_IF type macvlan mode bridge

# Create new network namespaces
ip netns add ${CLIENT}.ns
ip netns add ${SERVER}.ns
ip netns add ${BAD_GUY}.ns

# Set ARP filter mode
ip netns exec ${CLIENT}.ns sysctl -w net.ipv4.conf.all.arp_filter=$ARP_FILTER
ip netns exec ${SERVER}.ns sysctl -w net.ipv4.conf.all.arp_filter=$ARP_FILTER
ip netns exec ${BAD_GUY}.ns sysctl -w net.ipv4.conf.all.arp_filter=$ARP_FILTER

# Set ARP ignore mode
ip netns exec ${CLIENT}.ns sysctl -w net.ipv4.conf.all.arp_ignore=$ARP_IGNORE
ip netns exec ${SERVER}.ns sysctl -w net.ipv4.conf.all.arp_ignore=$ARP_IGNORE
ip netns exec ${BAD_GUY}.ns sysctl -w net.ipv4.conf.all.arp_ignore=$ARP_IGNORE

# Move MACVLAN interfaces into dedicated namespaces
ip link set ${CLIENT}.mvl netns ${CLIENT}.ns
ip link set ${SERVER}.mvl netns ${SERVER}.ns
ip link set ${BAD_GUY}.mvl netns ${BAD_GUY}.ns

ip link set ${CLIENT}.vmvl netns ${CLIENT}.ns
ip link set ${SERVER}.vmvl netns ${SERVER}.ns
ip link set ${BAD_GUY}.vmvl netns ${BAD_GUY}.ns

# Bring them up
ip netns exec ${CLIENT}.ns ip link set up dev ${CLIENT}.mvl
ip netns exec ${SERVER}.ns ip link set up dev ${SERVER}.mvl
ip netns exec ${BAD_GUY}.ns ip link set up dev ${BAD_GUY}.mvl

ip netns exec ${CLIENT}.ns ip link set up dev ${CLIENT}.vmvl
ip netns exec ${SERVER}.ns ip link set up dev ${SERVER}.vmvl
ip netns exec ${BAD_GUY}.ns ip link set up dev ${BAD_GUY}.vmvl

# Bring lo interfaces up
ip netns exec ${CLIENT}.ns ip link set up dev lo
ip netns exec ${SERVER}.ns ip link set up dev lo
ip netns exec ${BAD_GUY}.ns ip link set up dev lo

# Create VLAN interfaces
ip netns exec ${CLIENT}.ns ip link add name ${CLIENT}.vmvl.$VLAN link ${CLIENT}.vmvl type vlan id $VLAN
ip netns exec ${SERVER}.ns ip link add name ${SERVER}.vmvl.$VLAN link ${SERVER}.vmvl type vlan id $VLAN
ip netns exec ${BAD_GUY}.ns ip link add name ${BAD_GUY}.vmvl.$VLAN link ${BAD_GUY}.vmvl type vlan id $VLAN

# Bring VLAN interfaces up
ip netns exec ${CLIENT}.ns ip link set up dev ${CLIENT}.vmvl.$VLAN
ip netns exec ${SERVER}.ns ip link set up dev ${SERVER}.vmvl.$VLAN
ip netns exec ${BAD_GUY}.ns ip link set up dev ${BAD_GUY}.vmvl.$VLAN

# Run tcpdump on MACVLAN devices
ip netns exec ${CLIENT}.ns sh -c "tcpdump -nn -i ${CLIENT}.mvl -s0 -w ${CLIENT}.pcap &"
ip netns exec ${SERVER}.ns sh -c "tcpdump -nn -i ${SERVER}.mvl -s0 -w ${SERVER}.pcap &"
ip netns exec ${BAD_GUY}.ns sh -c "tcpdump -nn -i ${BAD_GUY}.mvl -s0 -w ${BAD_GUY}.pcap &"

ip netns exec ${CLIENT}.ns sh -c "tcpdump -nn -i ${CLIENT}.vmvl -s0 -w ${CLIENT}2.pcap &"
ip netns exec ${SERVER}.ns sh -c "tcpdump -nn -i ${SERVER}.vmvl -s0 -w ${SERVER}2.pcap &"
ip netns exec ${BAD_GUY}.ns sh -c "tcpdump -nn -i ${BAD_GUY}.vmvl -s0 -w ${BAD_GUY}2.pcap &"

# Run tcpdump on VLAN devices
ip netns exec ${CLIENT}.ns sh -c "tcpdump -nn -i ${CLIENT}.vmvl.$VLAN -s0 -w ${CLIENT}2_vlan${VLAN}.pcap &"
ip netns exec ${SERVER}.ns sh -c "tcpdump -nn -i ${SERVER}.vmvl.$VLAN -s0 -w ${SERVER}2_vlan${VLAN}.pcap &"
ip netns exec ${BAD_GUY}.ns sh -c "tcpdump -nn -i ${BAD_GUY}.vmvl.$VLAN -s0 -w ${BAD_GUY}2_vlan${VLAN}.pcap &"

# Finally, set IP addresses
ip netns exec ${CLIENT}.ns ip a add ${CLIENT_IPV4}/${PREFIX_IPV4} dev ${CLIENT}.mvl
ip netns exec ${SERVER}.ns ip a add ${SERVER_IPV4}/${PREFIX_IPV4} dev ${SERVER}.mvl
ip netns exec ${BAD_GUY}.ns ip a add ${BAD_GUY_IPV4}/${PREFIX_IPV4} dev ${BAD_GUY}.mvl

ip netns exec ${CLIENT}.ns ip a add ${VLAN_CLIENT_IPV4}/${VLAN_PREFIX_IPV4} dev ${CLIENT}.vmvl.$VLAN
ip netns exec ${SERVER}.ns ip a add ${VLAN_SERVER_IPV4}/${VLAN_PREFIX_IPV4} dev ${SERVER}.vmvl.$VLAN
ip netns exec ${BAD_GUY}.ns ip a add ${VLAN_BAD_GUY_IPV4}/${VLAN_PREFIX_IPV4} dev ${BAD_GUY}.vmvl.$VLAN
