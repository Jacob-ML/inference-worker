<p align="center">
    <img src="https://raw.githubusercontent.com/ggml-org/llama.cpp/master/media/llama1-icon-transparent.png" alt="llama.cpp logo" width="128">
</p>

# Serverless llama.cpp inference worker for RunPod

[![Runpod badge](https://api.runpod.io/badge/Jacob-ML/inference-worker)](https://console.runpod.io/hub/Jacob-ML/inference-worker)

This repository contains a serverless inference worker for running llama.cpp models on RunPod. It uses the `llama-server` image to provide an API for interacting with the models.
The following OpenAI API endpoints are supported:

- `v1/models`
- `v1/chat/completions`
- `v1/completions`

Streaming responses is also supported.

## Setup

For the setup to work best, it is recommended to use a network volume attached to all workers which stores the model GGUFs and then reference those files in the launch arguments.
Make sure your RunPod worker has access to the network volume, i.e. is located in the correct data center.

## Configuration

The worker can be configured via environment variables set in the RunPod hub configuration:

- `LLAMA_SERVER_CMD_ARGS`: Command line arguments (argv) for the `llama-server` binary. Example: `-hf /path/to/model.gguf:Q4_K_M -ctx_size 4096`. **IMPORTANT**: Please do not define the port argument here, as the worker will always use port `3098` automatically.
- `MAX_CONCURRENCY`: Maximum number of concurrent requests the worker can handle. Default is `8`.

## License

Please see the [LICENSE](./LICENSE) file for more information.
