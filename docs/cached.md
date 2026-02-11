# Using cached models

## Introduction

The classic way of loading a model from the Hugging Face Hub with the `LLAMA_SERVER_CMD_ARGS` is as follows:

```bash
-hf /path/to/model.gguf:Q4_K_M --ctx-size 4096 # etc...
```

However, this will cause every worker to download the model from the Hugging Face Hub every time it is started, which can be slow and inefficient.

A naive way to cache the model would be to store it on a network volume in RunPod and reference the model files this way:

```bash
-m /runpod-volume/model.gguf --ctx-size 4096 # etc...
```

Unfortunately, network volume performance is often not sufficient for loading large models, leading to long load times. RunPod introduced a [caching mechanism](https://docs.runpod.io/serverless/endpoints/model-caching) to solve this problem.

The `inference-worker` for llama.cpp now supports this caching mechanism.

## How to use the new caching mechanism

It ships the `src/find_cached.py` script which can be used to reference any Hugging Face model of your choice and get its cached path on the local worker storage.

Here is how the script can be used independently (which you will likely never need to do):

```bash
python3 src/find_cached.py HF_MODEL_ID GGUF_PATH_IN_REPO
```

Example:

```bash
python3 src/find_cached.py unsloth/gemma-3-270m-it-GGUF gemma-3-270m-it-Q8_0.gguf
```

Or, if your model is in a folder (an edge case nobody seems to be thinking about, driving me absolutely crazy):

```bash
python3 src/find_cached.py jacob-ml/jacob-24b models/jacob-24b-q4_k_m.gguf
```

We will now integrate this into our workflow. Hang tight.

## Step-by-step guide

1.  First of all, please enter the Hugging Face URL of the model you want to use in RunPod's `Model` field of your worker settings.

    Example: For the model `unsloth/gemma-3-270m-it-GGUF`, you would enter `https://huggingface.co/unsloth/gemma-3-270m-it-GGUF`.

2.  Now, in the environment variables, do NOT enter the `-hf` argument as before and also do NOT define `-m` in the `LLAMA_SERVER_CMD_ARGS`. The inference worker will take care of that for you.

    Instead, set the `LLAMA_CACHED_MODEL` to the model ID, a.e. `unsloth/gemma-3-270m-it-GGUF`. Then, set the `LLAMA_CACHED_GGUF_PATH` to the path of the GGUF file in the repository, e.g. `gemma-3-270m-it-Q8_0.gguf`.

3. Finally, in the `LLAMA_SERVER_CMD_ARGS`, you can now simply add the other arguments you want to use, e.g.:

    ```bash
    --ctx-size 4096 --temp 0.7 --top-p 0.9
    ```

4.  Done! The rest will be handled by the inference worker automatically. When the worker starts, it will resolve the cached model path and launch `llama-server` with the correct arguments.
