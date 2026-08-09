#!/bin/sh

set -eu

case "${ARCHS:-}" in
    arm64)
        rust_target="aarch64-apple-darwin"
        ;;
    x86_64)
        rust_target="x86_64-apple-darwin"
        ;;
    "")
        echo "error: ARCHS must contain exactly one architecture" >&2
        exit 1
        ;;
    *)
        echo "error: unsupported or multiple architectures in ARCHS: ${ARCHS}" >&2
        exit 1
        ;;
esac

core_dir="${SRCROOT}/TierletService/Core"
generated_dir="${core_dir}/Generated"
library="${core_dir}/target/${rust_target}/debug/libtierlet_core.a"

cd "${core_dir}"

if [ "${CONFIGURATION}" = "Release" ]; then
    cargo build --manifest-path "${core_dir}/Cargo.toml" --target "${rust_target}" --release
    library="${core_dir}/target/${rust_target}/release/libtierlet_core.a"
else
    cargo build --manifest-path "${core_dir}/Cargo.toml" --target "${rust_target}"
fi

mkdir -p "${BUILT_PRODUCTS_DIR}" "${generated_dir}"
cp "${library}" "${BUILT_PRODUCTS_DIR}/libtierlet_core.a"

cargo run \
    --manifest-path "${core_dir}/Cargo.toml" \
    --features bindgen \
    --bin uniffi-bindgen \
    -- generate \
    --library "${library}" \
    --language swift \
    --out-dir "${generated_dir}"
