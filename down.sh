#!/bin/bash

CLIENT="client"
SERVER="server"
BAD_GUY="bad_guy"

# Kill all tcpdump processes which we have started
ps auxw | grep 'tcpdump.*mvl.*pcap' | grep -v grep | awk '{print $2}' | xargs kill

# Kill all network namespaces
ip netns del ${CLIENT}.ns
ip netns del ${SERVER}.ns
ip netns del ${BAD_GUY}.ns
