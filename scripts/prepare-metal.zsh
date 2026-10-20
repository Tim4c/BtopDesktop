#!/bin/zsh
set -euo pipefail

[[ $(uname -m) == arm64 && $(sw_vers -productVersion | cut -d. -f1) -ge 27 ]] || {
	print -u2 'The build requires macOS 27 or later on Apple Silicon.'
	exit 1
}
sw_vers
xcodebuild -version
swift --version
if ! xcrun metal --version >/dev/null 2>&1; then
	xcodebuild -downloadComponent MetalToolchain
fi
# Registration can lag behind the download; discard cached tool lookups.
for attempt in {1..12}; do
	xcrun --kill-cache
	if xcrun metal --version; then
		exit 0
	fi
	if [[ $attempt -lt 12 ]]; then
		print "Waiting for Metal Toolchain registration ($attempt/12)..."
		sleep 5
	fi
done
print -u2 '::error::Metal Toolchain downloaded but unavailable after registration checks.'
exit 1
