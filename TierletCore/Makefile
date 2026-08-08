ARCHS ?= $(shell uname -m)
CONFIGURATION ?= Debug
BUILT_PRODUCTS_DIR ?= $(CURDIR)/target/xcode
BUILD_DIR ?= $(BUILT_PRODUCTS_DIR)

RUST_PROFILE := $(if $(filter Release,$(CONFIGURATION)),release,debug)
CARGO_FLAGS := $(if $(filter Release,$(CONFIGURATION)),--release,)
OUTPUT_LIBRARY := $(BUILT_PRODUCTS_DIR)/libtierlet_core.a
GENERATED_DIR := $(CURDIR)/Generated
FIRST_RUST_TARGET := $(if $(filter arm64,$(firstword $(ARCHS))),aarch64-apple-darwin,x86_64-apple-darwin)
BINDGEN_LIBRARY := $(CURDIR)/target/$(FIRST_RUST_TARGET)/$(RUST_PROFILE)/libtierlet_core.a

UNSUPPORTED_ARCHS := $(filter-out arm64 x86_64,$(ARCHS))
ifneq ($(strip $(UNSUPPORTED_ARCHS)),)
$(error Unsupported architecture: $(UNSUPPORTED_ARCHS))
endif

.PHONY: build install xcode clean

build install: xcode

xcode:
	@mkdir -p "$(BUILT_PRODUCTS_DIR)" "$(GENERATED_DIR)"
	@for arch in $(ARCHS); do \
		case "$$arch" in \
			arm64) rust_target=aarch64-apple-darwin ;; \
			x86_64) rust_target=x86_64-apple-darwin ;; \
		esac; \
		cargo build --manifest-path "$(CURDIR)/Cargo.toml" --target "$$rust_target" $(CARGO_FLAGS); \
	done
	@if [ "$(words $(ARCHS))" -eq 1 ]; then \
		case "$(firstword $(ARCHS))" in \
			arm64) rust_target=aarch64-apple-darwin ;; \
			x86_64) rust_target=x86_64-apple-darwin ;; \
		esac; \
		cp "$(CURDIR)/target/$$rust_target/$(RUST_PROFILE)/libtierlet_core.a" "$(OUTPUT_LIBRARY)"; \
	else \
		xcrun lipo -create \
			"$(CURDIR)/target/aarch64-apple-darwin/$(RUST_PROFILE)/libtierlet_core.a" \
			"$(CURDIR)/target/x86_64-apple-darwin/$(RUST_PROFILE)/libtierlet_core.a" \
			-output "$(OUTPUT_LIBRARY)"; \
	fi
	@cargo run \
		--manifest-path "$(CURDIR)/Cargo.toml" \
		--features bindgen \
		--bin uniffi-bindgen \
		-- generate \
		--library "$(BINDGEN_LIBRARY)" \
		--language swift \
		--out-dir "$(GENERATED_DIR)"

clean:
	@cargo clean --manifest-path "$(CURDIR)/Cargo.toml"
	@rm -f "$(OUTPUT_LIBRARY)"
