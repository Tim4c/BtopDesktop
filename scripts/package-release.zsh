#!/bin/zsh
# Package an already built app; never replaces the local development bundle.
set -euo pipefail

project_dir=${0:A:h:h}
app="$project_dir/BtopDesktop.app"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$project_dir/Info.plist")
[[ "$version" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]] || {
	print -u2 'Expected a numeric major.minor.patch version in Info.plist.'
	exit 1
}
[[ -d "$app" ]] || {
	print -u2 'Build BtopDesktop.app first.'
	exit 1
}
app_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")
[[ "$app_version" == "$version" ]] || {
	print -u2 'The app version is stale. Rebuild first.'
	exit 1
}
for license in BtopDesktop-LICENSE SwiftTerm-LICENSE btop/LICENSE; do
	[[ -s "$app/Contents/Resources/licenses/$license" ]] || {
		print -u2 "Missing bundled license: $license. Rebuild first."
		exit 1
	}
done
codesign --verify --deep --strict "$app"

output="$project_dir/dist/v$version"
[[ ! -e "$output" ]] || {
	print -u2 "Output already exists: $output"
	exit 1
}
mkdir -p "$output"
stage=$(mktemp -d "${TMPDIR:-/tmp}/btop-release.XXXXXX")
trap 'rm -rf "$stage"' EXIT
ditto "$app" "$stage/BtopDesktop.app"
# Sign only the staged copy, keeping the developer's local identity untouched.
codesign --force --sign - "$stage/BtopDesktop.app/Contents/Resources/bin/btop"
codesign --force --deep --sign - "$stage/BtopDesktop.app"
codesign --verify --deep --strict "$stage/BtopDesktop.app"
archive="BtopDesktop-$version-macos-arm64.zip"
ditto -c -k --sequesterRsrc --keepParent "$stage/BtopDesktop.app" "$output/$archive"
digest=$(shasum -a 256 "$output/$archive" | awk '{print $1}')
print -r -- "$digest  $archive" >"$output/SHA256SUMS"
sed -e "s/@VERSION@/$version/g" -e "s/@SHA256@/$digest/g" \
	"$project_dir/packaging/homebrew/btop-desktop.rb.in" >"$output/btop-desktop.rb"
cp "$project_dir/packaging/release-notes.md" "$output/RELEASE_NOTES.md"
print "Prepared release files: $output"
