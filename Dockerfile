ARG CUDA_IMAGE=nvidia/cuda:13.0.0-cudnn-runtime-ubuntu24.04
FROM ${CUDA_IMAGE}

ARG DEBIAN_FRONTEND=noninteractive
ARG COMFYUI_REPOSITORY=https://github.com/comfyanonymous/ComfyUI.git
ARG COMFYUI_REF=6ac8152fc80734b084d12865460e5e9a5d9a4e1b
ARG COMFYUI_MANAGER_REPOSITORY=https://github.com/Comfy-Org/ComfyUI-Manager.git
ARG COMFYUI_MANAGER_REF=main
ARG SAGEATTENTION_REPOSITORY=https://github.com/thu-ml/SageAttention.git
ARG SAGEATTENTION_REF=v2.2.0
ARG TORCH_INDEX_URL=https://download.pytorch.org/whl/cu130
ARG TORCH_CUDA_ARCH_LIST=
ARG PYTHON_BIN=python3
ARG INSTALL_SAGEATTENTION=0

ENV APP_HOME=/opt/generaitr/comfyui
ENV VENV_PATH=/opt/generaitr/venv
ENV COMFYUI_PORT=8190
ENV JUPYTER_PORT=8888
ENV COMFYUI_LISTEN_HOST=0.0.0.0
ENV COMFYUI_STATE_DIR=/workspace/comfyui-state
ENV COMFYUI_USE_SAGE_ATTENTION=${INSTALL_SAGEATTENTION}
ENV CUDA_HOME=/usr/local/cuda
ENV PATH=/usr/local/cuda/bin:${VENV_PATH}/bin:${PATH}
ENV LD_LIBRARY_PATH=/usr/local/cuda/lib64:${LD_LIBRARY_PATH}
ENV TORCH_CUDA_ARCH_LIST=${TORCH_CUDA_ARCH_LIST}
ENV PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:128
ENV PIP_NO_CACHE_DIR=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    ${PYTHON_BIN} \
    ${PYTHON_BIN}-venv \
    ${PYTHON_BIN}-dev \
    aria2 \
    build-essential \
    ca-certificates \
    ffmpeg \
    git \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender1 \
    ninja-build \
    curl \
    && rm -rf /var/lib/apt/lists/*

RUN ${PYTHON_BIN} -m venv ${VENV_PATH}

RUN pip install --upgrade pip setuptools wheel

RUN git clone ${COMFYUI_REPOSITORY} ${APP_HOME} \
    && cd ${APP_HOME} \
    && git checkout ${COMFYUI_REF}

RUN cd ${APP_HOME} \
    && grep -Ev '^(torch|torchsde|torchvision|torchaudio)([<>=!~].*)?$' requirements.txt > /tmp/comfyui-requirements.txt \
    && pip install --index-url ${TORCH_INDEX_URL} torch torchvision torchaudio \
    && pip install -r /tmp/comfyui-requirements.txt \
    && pip install torchsde

RUN git clone ${COMFYUI_MANAGER_REPOSITORY} ${APP_HOME}/custom_nodes/ComfyUI-Manager \
    && cd ${APP_HOME}/custom_nodes/ComfyUI-Manager \
    && git checkout ${COMFYUI_MANAGER_REF} \
    && if [ -f requirements.txt ]; then pip install -r requirements.txt; fi

RUN if [ "${INSTALL_SAGEATTENTION}" = "1" ]; then \
      git clone ${SAGEATTENTION_REPOSITORY} /tmp/SageAttention \
      && cd /tmp/SageAttention \
      && git checkout ${SAGEATTENTION_REF} \
      && export CUDA_HOME="${CUDA_HOME}" \
      && export PATH="${CUDA_HOME}/bin:${PATH}" \
      && export LD_LIBRARY_PATH="${CUDA_HOME}/lib64:${CUDA_HOME}/targets/x86_64-linux/lib:${LD_LIBRARY_PATH}" \
      && export CPATH="${CUDA_HOME}/targets/x86_64-linux/include:${CPATH}" \
      && export C_INCLUDE_PATH="${CUDA_HOME}/targets/x86_64-linux/include:${C_INCLUDE_PATH}" \
      && export CPLUS_INCLUDE_PATH="${CUDA_HOME}/targets/x86_64-linux/include:${CPLUS_INCLUDE_PATH}" \
      && export MAX_JOBS=4 \
      && python setup.py install \
      && rm -rf /tmp/SageAttention; \
    fi

COPY docker/runpod/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh \
    && mkdir -p /workspace ${COMFYUI_STATE_DIR}

WORKDIR ${APP_HOME}
EXPOSE 8190 8888

CMD ["/entrypoint.sh"]
