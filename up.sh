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

# Create MACVLAN interfaces (bridge mode is important)
ip link add name ${CLIENT}.mvl link $BASE_IF type macvlan mode bridge
ip link add name ${SERVER}.mvl link $BASE_IF type macvlan mode bridge
ip link add name ${BAD_GUY}.mvl link $BASE_IF type macvlan mode bridge

# Create new network namespaces
ip netns add ${CLIENT}.ns
ip netns add ${SERVER}.ns
ip netns add ${BAD_GUY}.ns

# Move MACVLAN interfaces into dedicated namespaces
ip link set ${CLIENT}.mvl netns ${CLIENT}.ns
ip link set ${SERVER}.mvl netns ${SERVER}.ns
ip link set ${BAD_GUY}.mvl netns ${BAD_GUY}.ns

# Bring them up
ip netns exec ${CLIENT}.ns ip link set up dev ${CLIENT}.mvl
ip netns exec ${SERVER}.ns ip link set up dev ${SERVER}.mvl
ip netns exec ${BAD_GUY}.ns ip link set up dev ${BAD_GUY}.mvl

# Bring lo interfaces up
ip netns exec ${CLIENT}.ns ip link set up dev lo
ip netns exec ${SERVER}.ns ip link set up dev lo
ip netns exec ${BAD_GUY}.ns ip link set up dev lo

# Run tcpdump on MACVLAN devices
ip netns exec ${CLIENT}.ns sh -c "tcpdump -nn -i ${CLIENT}.mvl -s0 -w ${CLIENT}.pcap &"
ip netns exec ${SERVER}.ns sh -c "tcpdump -nn -i ${SERVER}.mvl -s0 -w ${SERVER}.pcap &"
ip netns exec ${BAD_GUY}.ns sh -c "tcpdump -nn -i ${BAD_GUY}.mvl -s0 -w ${BAD_GUY}.pcap &"

# Finally, set IP addresses
ip netns exec ${CLIENT}.ns ip a add ${CLIENT_IPV4}/${PREFIX_IPV4} dev ${CLIENT}.mvl
ip netns exec ${SERVER}.ns ip a add ${SERVER_IPV4}/${PREFIX_IPV4} dev ${SERVER}.mvl
ip netns exec ${BAD_GUY}.ns ip a add ${BAD_GUY_IPV4}/${PREFIX_IPV4} dev ${BAD_GUY}.mvl
