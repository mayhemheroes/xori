# Build Stage
FROM --platform=linux/amd64 ubuntu:22.04 AS builder

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y curl build-essential pkg-config libssl-dev
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain nightly
ENV PATH="/root/.cargo/bin:${PATH}"
RUN cargo install -f cargo-fuzz

# Pre-compile dependencies (cached as long as Cargo.lock doesn't change)
COPY Cargo.toml /src/
COPY fuzz/Cargo.toml /src/fuzz/
RUN mkdir -p /src/src /src/fuzz/fuzz_targets && \
    echo > /src/src/lib.rs && \
    printf '#![no_main]\nuse libfuzzer_sys::fuzz_target;\nfuzz_target!(|_data: &[u8]| {});\n' \
        > /src/fuzz/fuzz_targets/simple.rs
WORKDIR /src
RUN cargo +nightly fuzz build || true

# Build with real source
ADD . /src
RUN cargo +nightly fuzz build && \
    mv fuzz/target/x86_64-unknown-linux-gnu/release/simple /simple

RUN RUSTFLAGS="--cfg fuzzing -Clink-dead-code -Cdebug-assertions -C codegen-units=1" \
    cargo +nightly build --release --manifest-path fuzz/Cargo.toml && \
    mv fuzz/target/release/simple /simple_no_inst

# Package Stage
FROM ubuntu:22.04

COPY --from=builder /simple /simple_no_inst /
