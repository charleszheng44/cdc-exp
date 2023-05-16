#!/usr/bin/env bash

# Function to handle SIGHUP signal
handle_sighup() {
    echo "Received INT signal."
    # Add code to handle SIGHUP signal
    exit 0
}

# Set up trap to call handle_sighup function on SIGHUP
trap handle_sighup INT

while true; do
    sleep 1
done 
