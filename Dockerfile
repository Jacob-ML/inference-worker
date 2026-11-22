# Use an official ggml-org/llama.cpp image as the base image
FROM ghcr.io/ggml-org/llama.cpp:server-cuda

ENV PYTHONUNBUFFERED=1

# Set up the working directory
WORKDIR /

RUN DEBIAN_FRONTEND=noninteractive apt-get update --yes --quiet \
    && DEBIAN_FRONTEND=noninteractive apt-get install --yes --quiet --no-install-recommends \
        software-properties-common \
        gpg-agent \
        build-essential \
        apt-utils \
    && DEBIAN_FRONTEND=noninteractive apt-get install --reinstall --yes \
        ca-certificates \
    && DEBIAN_FRONTEND=noninteractive apt-get install --yes --quiet --no-install-recommends \
        bash \
        curl \
        git \
        python3-setuptools \
        python3-pip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*


# Set the working directory
WORKDIR /work

# Add my src as /work
ADD ./src /work

# Install runpod and its dependencies
RUN pip install --ignore-installed --break-system-packages --upgrade -r requirements.txt 
RUN chmod +x /work/start.sh
    
# Set the entrypoint
ENTRYPOINT ["/bin/sh", "-c", "/work/start.sh"]

# can use this to preload a model
#ENV MODEL_NAMES="qwen3.8:27b-mtp-q4_K_M"
#RUN chmod +x /work/preload_model.sh \
#    && /work/preload_model.sh
