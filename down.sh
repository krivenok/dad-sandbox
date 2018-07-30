#!/bin/bash

CLIENT="client"
SERVER="server"
BAD_GUY="bad_guy"

# Kill all processes which we have started (e.g. tcpdump)
ip netns pids ${CLIENT}.ns | xargs kill
ip netns pids ${SERVER}.ns | xargs kill
ip netns pids ${BAD_GUY}.ns | xargs kill

# Kill all network namespaces
ip netns del ${CLIENT}.ns
ip netns del ${SERVER}.ns
ip netns del ${BAD_GUY}.ns
