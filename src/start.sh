#!/bin/bash

# This script starts the llama-server with the command line arguments
# specified in the environment variable LLAMA_SERVER_CMD_ARGS, ensuring
# that the server listens on port 3098. It also starts the handler.py
# script after the server is up and running.

cleanup() {
    echo "Cleaning up..."
    pkill -P $$ # kill all child processes of the current script
    exit 0
}

# check if the substring /workspace is in LLAMA_SERVER_CMD_ARGS
if [[ "$LLAMA_SERVER_CMD_ARGS" != *"/workspace"* ]]; then
    echo "Tip: For reduced downloads and faster startup times, consider using a model stored in a network volume mounted to /workspace."
fi

# check if the substring -port is in LLAMA_SERVER_CMD_ARGS
if [[ "$LLAMA_SERVER_CMD_ARGS" != *"-port"* ]]; then
    echo "Error: You must not define -port in LLAMA_SERVER_CMD_ARGS, as port 3098 is required."
    exit 1
fi

# trap exit signals and call the cleanup function
trap cleanup SIGINT SIGTERM

# kill any existing llama-server processes
pgrep llama-server | xargs kill

# we have a string with all the command line arguments in the env var LLAMA_SERVER_CMD_ARGS;
# it contains a.e. "-hf modelname -ctx_size 4096".

# We need to pass these arguments to llama-server verbatim.
llama-server $LLAMA_SERVER_CMD_ARGS -port 3098 2>&1 | tee llama.server.log &

LLAMA_SERVER_PID=$! # store the process ID (PID) of the background command

check_server_is_running() {
    echo "Checking if llama-server is done initializing..."

    if cat llama.server.log | grep -q "listening"; then
        return 0 # success
    else
        return 1 # failure
    fi
}

# wait for the server to start
while ! check_server_is_running; do
    sleep 5
done

python -u handler.py $1
