FROM debian:sid-slim

RUN apt update && \
    apt install -y \
        make \
        bash \
        nasm \
        gdb \
        cgdb \
        gcc \
        g++ \
        build-essential \
        vim \
        tmux && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

CMD ["/bin/bash"]
