FROM debian:sid-slim

RUN apt update && \
    apt install -y \
        make \
        bash \
        gcc \
        g++ \
        build-essential \
        libyaml-cpp-dev \
        libreadline8 \
        libreadline-dev \
        nlohmann-json3-dev \
        btop \
        vim \
        tmux && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

CMD ["/bin/bash"]