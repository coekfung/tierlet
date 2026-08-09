PROJECT := Tierlet.xcodeproj
SCHEME := Tierlet
DERIVED_DATA := $(CURDIR)/.build/DerivedData
RUST_MANIFEST := TierletService/Core/Cargo.toml
ARCH ?= $(shell uname -m)
CONFIGURATION ?= Debug
RUST_HOST_TARGET := $(shell rustc -vV | sed -n 's/^host: //p')

.PHONY: bootstrap check test build

bootstrap:
	rustup target add "$(RUST_HOST_TARGET)"

check:
	cargo fmt --manifest-path "$(RUST_MANIFEST)" -- --check
	cargo clippy --manifest-path "$(RUST_MANIFEST)" --all-targets -- -D warnings
	plutil -lint "$(PROJECT)/project.pbxproj"
	plutil -lint Resources/LaunchDaemons/wang.coekfung.tierlet.daemon.plist

test:
	cargo test --manifest-path "$(RUST_MANIFEST)"

build:
	xcodebuild \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-configuration "$(CONFIGURATION)" \
		-destination "platform=macOS" \
		-derivedDataPath "$(DERIVED_DATA)" \
		CODE_SIGNING_ALLOWED=NO \
		ARCHS="$(ARCH)" \
		ONLY_ACTIVE_ARCH=YES \
		build
