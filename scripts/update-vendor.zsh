#!/bin/zsh
# Refresh the lock from Homebrew metadata; installation remains a separate validation step.
set -euo pipefail

[[ $# == 0 ]] || {
	print -u2 'Usage: scripts/update-vendor.zsh'
	exit 2
}
script_dir=${0:A:h}
manifest="${script_dir:h}/vendor-manifest.tsv"
workspace=$(mktemp -d "${TMPDIR:-/tmp}/btop-update.XXXXXX")
trap 'rm -rf "$workspace"' EXIT

curl --fail --silent --show-error --location --retry 3 \
	--connect-timeout 20 --max-time 120 \
	https://formulae.brew.sh/api/formula/btop.json -o "$workspace/formula.json"

# Pin the minimum supported OS, independently of the Mac running this script.
version=$(plutil -extract versions.stable raw -o - "$workspace/formula.json")
digest=$(plutil -extract bottle.stable.files.arm64_golden_gate.sha256 raw -o - "$workspace/formula.json")
url=$(plutil -extract bottle.stable.files.arm64_golden_gate.url raw -o - "$workspace/formula.json")
[[ "$version" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' &&
	"$digest" =~ '^[0-9a-f]{64}$' &&
	"$url" == "https://ghcr.io/v2/homebrew/core/btop/blobs/sha256:$digest" ]] || {
	print -u2 'Invalid btop metadata; manifest has not been changed.'
	exit 1
}

{
	print -r -- '# Btop Desktop runtime lock: macOS 27+, ARM64. No mutable download URLs.'
	print -r -- '# name\tversion\tSHA-256\tarchive URL'
	printf 'btop\t%s\t%s\t%s\n' "$version" "$digest" "$url"
} >"$workspace/vendor-manifest.tsv"
if cmp -s "$workspace/vendor-manifest.tsv" "$manifest"; then
	print "btop $version: manifest is already up to date."
else
	cp "$workspace/vendor-manifest.tsv" "$manifest"
	print "Updated manifest to btop $version (arm64_golden_gate)."
fi
print 'Next: scripts/install-vendor.zsh --force && scripts/build-app.zsh'
print 'Then: scripts/lint.zsh && swift test'
