# Build
FROM debian:bookworm AS build

ARG ZIG_VER=0.14.0

RUN apt-get update && apt-get install -y curl xz-utils

RUN curl https://ziglang.org/download/${ZIG_VER}/zig-linux-$(uname -m)-${ZIG_VER}.tar.xz -o zig-linux.tar.xz && \
    tar xf zig-linux.tar.xz && \
    mv zig-linux-$(uname -m)-${ZIG_VER}/ /opt/zig

WORKDIR /app

COPY . .

RUN /opt/zig/zig build -Doptimize=ReleaseFast

CMD ["tail", "-f", "/dev/null"]
