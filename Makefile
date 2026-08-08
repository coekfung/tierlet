PROJECT := Tierlet.xcodeproj
SCHEME := Tierlet
DERIVED_DATA := $(CURDIR)/.build/DerivedData
RUST_MANIFEST := TierletCore/Cargo.toml

.PHONY: bootstrap check test build build-universal ci

bootstrap:
	rustup target add aarch64-apple-darwin x86_64-apple-darwin

check:
	cargo fmt --manifest-path "$(RUST_MANIFEST)" -- --check
	cargo clippy --manifest-path "$(RUST_MANIFEST)" --all-targets -- -D warnings
	plutil -lint "$(PROJECT)/project.pbxproj"
	plutil -lint Resources/LaunchDaemons/wang.coekfung.tierlet.daemon.plist

test:
	cargo test --manifest-path "$(RUST_MANIFEST)"
	$(MAKE) build

build:
	xcodebuild \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-configuration Debug \
		-destination "platform=macOS" \
		-derivedDataPath "$(DERIVED_DATA)" \
		CODE_SIGNING_ALLOWED=NO \
		build

build-universal:
	xcodebuild \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-configuration Release \
		-destination "generic/platform=macOS" \
		-derivedDataPath "$(DERIVED_DATA)" \
		CODE_SIGNING_ALLOWED=NO \
		ARCHS="arm64 x86_64" \
		ONLY_ACTIVE_ARCH=NO \
		build

ci: check test build-universal
