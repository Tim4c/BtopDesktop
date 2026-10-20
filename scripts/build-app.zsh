#!/bin/zsh
set -euo pipefail

script_dir=${0:A:h}
project_dir=${script_dir:h}
app_dir="$project_dir/BtopDesktop.app"
executable="$app_dir/Contents/MacOS/BtopDesktop"
signing_identity=${BTOP_CODESIGN_IDENTITY:-"BtopDesktop Local Development"}

fail() {
	print -u2 "$1"
	exit 1
}

ensure_app_is_closed() {
	for running_command in "${(@f)$(/bin/ps -axo comm=)}"; do
		if [[ "$running_command" == "$executable" ]]; then
			fail 'BtopDesktop is running. Quit it from the menu bar before rebuilding.'
		fi
	done
}

ensure_metal_toolchain() {
	# SwiftTerm declares a Metal shader resource, even though this app uses CoreGraphics.
	if ! xcrun metal --version >/dev/null 2>&1; then
		print -u2 'Metal Toolchain is unavailable. Install the Xcode component once:'
		print -u2 '  xcodebuild -downloadComponent MetalToolchain'
		exit 1
	fi
}

build_release() {
	"$script_dir/install-vendor.zsh"
	swift build --package-path "$project_dir" -c release --product BtopDesktop
}

compile_assets() {
	local build_dir="$1"
	local assets_dir="$build_dir/BtopDesktop-assets"
	mkdir -p "$assets_dir"
	xcrun actool "$project_dir/Resources/Assets.xcassets" \
		--compile "$assets_dir" \
		--platform macosx \
		--minimum-deployment-target 27.0 \
		--target-device mac \
		--output-format human-readable-text \
		--warnings --errors
}

assemble_app() {
	local build_dir="$1"
	local contents_dir="$app_dir/Contents"
	local resources_dir="$contents_dir/Resources"
	local resource_bundle

	rm -rf "$app_dir"
	mkdir -p \
		"$contents_dir/MacOS" \
		"$resources_dir/bin" \
		"$resources_dir/licenses"

	cp "$build_dir/BtopDesktop" "$contents_dir/MacOS/"
	cp "$project_dir/Info.plist" "$contents_dir/Info.plist"
	cp "$project_dir/Vendor/bin/btop" "$resources_dir/bin/"
	cp -R "$project_dir/Vendor/themes" "$resources_dir/"
	cp -R "$project_dir/Vendor/licenses/." "$resources_dir/licenses/"
	cp "$project_dir/LICENSE" "$resources_dir/licenses/BtopDesktop-LICENSE"
	cp "$project_dir/.build/checkouts/SwiftTerm/LICENSE" \
		"$resources_dir/licenses/SwiftTerm-LICENSE"

	cp "$project_dir/Resources/AppIcon.icns" "$resources_dir/AppIcon.icns"
	cp "$build_dir/BtopDesktop-assets/Assets.car" "$resources_dir/Assets.car"

	# SwiftPM resources must ship beside the executable.
	for resource_bundle in "$build_dir"/SwiftTerm_*.bundle(N/); do
		cp -R "$resource_bundle" "$resources_dir/"
	done
}

use_local_signing_identity_if_available() {
	if [[ -n ${BTOP_CODESIGN_IDENTITY:-} ]]; then
		return
	fi

	if security find-identity -v -p codesigning |
		/usr/bin/grep -Fq "\"$signing_identity\""; then
		return
	fi

	signing_identity="-"
	print -u2 'Using ad hoc signing: Accessibility permission may reset after code changes.'
	print -u2 'Run scripts/setup-local-signing.zsh once to configure stable local signing.'
}

sign_and_verify_app() {
	codesign --force --deep --sign "$signing_identity" "$app_dir"
	codesign --verify --deep --strict "$app_dir"
	print "Built: $app_dir"
}

ensure_app_is_closed
ensure_metal_toolchain
build_release
build_dir=$(swift build --package-path "$project_dir" -c release --show-bin-path)
compile_assets "$build_dir"
assemble_app "$build_dir"
use_local_signing_identity_if_available
sign_and_verify_app
