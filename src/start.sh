#!/bin/bash

# fail on error:
set -e -o pipefail

# This script starts the llama-server with the command line arguments
# specified in the environment variable LLAMA_SERVER_CMD_ARGS, ensuring
# that the server listens on port 3098. It also starts the handler.py
# script after the server is up and running.

cleanup() {
    echo "start.sh: Cleaning up..."
    pkill -P $$ # kill all child processes of the current script
    exit 0
}

# check if the substring /workspace is in LLAMA_SERVER_CMD_ARGS
if [[ "$LLAMA_SERVER_CMD_ARGS" != *"/workspace"* ]]; then
    echo "start.sh: Tip: For reduced downloads and faster startup times, consider using a model stored in a network volume mounted to /workspace."
fi

# check if the substring --port is in LLAMA_SERVER_CMD_ARGS and if yes, raise an error:
if [[ "$LLAMA_SERVER_CMD_ARGS" == *"--port"* ]]; then
    echo "start.sh: Error: You must not define --port in LLAMA_SERVER_CMD_ARGS, as port 3098 is required."
    exit 1
fi

# trap exit signals and call the cleanup function
trap cleanup SIGINT SIGTERM

# kill any existing llama-server processes
echo "start.sh: Stopping existing llama-server instances (if any)..."
{
    pkill llama-server 2>/dev/null
} || {
    echo "start.sh: No llama-server running"
}

# we have a string with all the command line arguments in the env var LLAMA_SERVER_CMD_ARGS;
# it contains a.e. "-hf modelname --ctx-size 4096".

echo "start.sh: Running llama-server $LLAMA_SERVER_CMD_ARGS --port 3098"

touch llama.server.log

# We need to pass these arguments to llama-server verbatim.
LD_LIBRARY_PATH=/app /app/llama-server $LLAMA_SERVER_CMD_ARGS --port 3098 2>&1 | tee llama.server.log &

LLAMA_SERVER_PID=$! # store the process ID (PID) of the background command

check_server_is_running() {
    echo "start.sh: Checking if llama-server is done initializing..."

    if cat llama.server.log | grep -q "listening"; then
        return 0 # success
    else
        return 1 # failure
    fi
}

echo "start.sh: Waiting for llama-server to start..."

# wait for the server to start
while ! check_server_is_running; do
    sleep 5
done

echo "start.sh: llama-server is up and running, delegating to the handler script."

python -u handler.py $1
