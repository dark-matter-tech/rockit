# Rockit Compiler — Docker Image
# Dark Matter Tech
#
# Build:  docker build -t rockit .
# Run:    docker run --rm rockit run Examples/hello.rok
# Shell:  docker run --rm -it rockit repl
# Mount:  docker run --rm -v $(pwd)/myproject:/code rockit run /code/main.rok

FROM swift:5.10.1-jammy AS builder

RUN apt-get update && apt-get install -y clang && rm -rf /var/lib/apt/lists/*

WORKDIR /build
COPY Package.swift .
COPY Sources/ Sources/
COPY Tests/ Tests/
COPY Runtime/ Runtime/

RUN swift build -c release

# --- Runtime image ---
FROM ubuntu:22.04

RUN apt-get update && \
    apt-get install -y --no-install-recommends clang libc6-dev && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /build/.build/release/rockit /usr/local/bin/rockit
COPY --from=builder /build/Runtime/ /usr/local/lib/rockit/runtime/
COPY Examples/ /usr/local/lib/rockit/examples/

ENV ROCKIT_RUNTIME_DIR=/usr/local/lib/rockit/runtime

WORKDIR /code

ENTRYPOINT ["rockit"]
CMD ["repl"]
