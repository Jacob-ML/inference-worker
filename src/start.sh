#!/bin/bash

# fail on error:
set -e -o pipefail

# This script starts the llama-server with the command line arguments
# specified in the environment variable LLAMA_SERVER_CMD_ARGS, ensuring
# that the server listens on port 3098. It also starts the handler.py
# script after the server is up and running.

cleanup() {
    echo "Cleaning up..."
    pkill -P $$ # Kill all child processes of the current script
    exit 0
}

CACHED_LLAMA_ARGS=""

find_cached_path() {
    local model_path
    model_path=$(python ./find_cached.py "$LLAMA_CACHED_MODEL" "$LLAMA_CACHED_GGUF_PATH")
    if [ $? -ne 0 ] || [ -z "$model_path" ]; then
        echo "start.sh: Error: Could not resolve cached model path. Check that LLAMA_CACHED_MODEL and LLAMA_CACHED_GGUF_PATH are correct and the model is fully cached on the network volume."
        exit 1
    fi
    CACHED_LLAMA_ARGS="-m $model_path"
}

# check if $LLAMA_CACHED_MODEL is set and not empty
if [ -n "$LLAMA_CACHED_MODEL" ]; then
    echo "start.sh: Caching is enabled. Finding cached model path..."
    find_cached_path

    echo "start.sh: Using cached model with arguments: $CACHED_LLAMA_ARGS"
else
    echo "start.sh: WARNING: Caching is disabled. Please visit the inference-worker README and docs to learn more."
fi

# check if $LLAMA_SERVER_CMD_ARGS is set
if [ -z "$LLAMA_SERVER_CMD_ARGS" ]; then
    echo "start.sh: Warning: LLAMA_SERVER_CMD_ARGS is not set. Defaulting to -hf unsloth/gemma-3-270m-it-GGUF:IQ2_XXS --ctx-size 512 -ngl 999"
    LLAMA_SERVER_CMD_ARGS="-hf unsloth/gemma-3-270m-it-GGUF:IQ2_XXS --ctx-size 512 -ngl 999"
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
# it contains a.e. "-hf modelname --ctx-size 4096 -ngl 999".

echo "start.sh: Running /app/llama-server $CACHED_LLAMA_ARGS $LLAMA_SERVER_CMD_ARGS --port 3098"

touch llama.server.log

# We need to pass these arguments to llama-server verbatim.
LD_LIBRARY_PATH=/app /app/llama-server $CACHED_LLAMA_ARGS $LLAMA_SERVER_CMD_ARGS --port 3098 2>&1 | tee llama.server.log &

LLAMA_SERVER_PID=$! # store the process ID (PID) of the background command

tries_so_far=0

check_server_is_running() {
    echo "Checking if llama-server is running..."
    if curl -s -f http://localhost:3098/v1/ > /dev/null; then
        return 0 # Success
    else
        return 1 # Failure
    fi

    tries_so_far=$((tries_so_far + 1))

}

echo "start.sh: Waiting for llama-server to start..."

# Wait for the server to start
while ! check_server_is_running; do
    sleep 1
    if [ $tries_so_far -ge 15 ]; then
        echo "*ERROR* llama-server did not start!"
        exit 1
    fi
done

echo "start.sh: llama-server is up and running, delegating to the handler script."

python3 -u handler.py $1