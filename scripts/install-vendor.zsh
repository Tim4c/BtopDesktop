#!/bin/zsh
# Install pinned binary archives locally. Never runs brew or bottle install scripts.
set -euo pipefail
export PATH=/usr/bin:/bin:/usr/sbin:/sbin

script_dir=${0:A:h}
project_dir=${script_dir:h}
manifest="$project_dir/vendor-manifest.tsv"
vendor="$project_dir/Vendor"
cache="$project_dir/.vendor-cache"
lock="$project_dir/.vendor-install.lock"
mode=${1:-install}

usage() {
	print -u2 'Usage: scripts/install-vendor.zsh [--force|--verify]'
	exit 2
}

fail() {
	print -u2 "$1"
	exit 1
}

parse_arguments() {
	[[ $# -le 1 ]] || usage
	[[ "$mode" == install || "$mode" == --force || "$mode" == --verify ]] || usage
}

validate_platform() {
	[[ $(uname -s) == Darwin && $(uname -m) == arm64 ]] ||
		fail 'The locked runtime requires an Apple Silicon Mac.'
	[[ $(sw_vers -productVersion | cut -d. -f1) -ge 27 ]] ||
		fail 'The locked runtime requires macOS 27 or later.'
	[[ -f "$manifest" ]] || fail "Missing manifest: $manifest"
}

manifest_hash=$(cat "$manifest" "$script_dir/install-vendor.zsh" | shasum -a 256 | awk '{print $1}')

verify_runtime() {
	[[ -f "$vendor/.manifest-sha256" && -f "$vendor/.runtime-sha256" ]] || return 1
	[[ "$(cat "$vendor/.manifest-sha256")" == "$manifest_hash" ]] || return 1
	[[ -x "$vendor/bin/btop" ]] || return 1
	(cd "$vendor" && shasum -a 256 --check .runtime-sha256 >/dev/null 2>&1)
}

handle_verify_mode() {
	verify_runtime ||
		fail 'Vendor is missing, modified, or outdated. Run scripts/install-vendor.zsh.'
	print 'Vendor matches the manifest and all installed file hashes.'
	exit 0
}

handle_already_installed() {
	if [[ "$mode" != --force ]] && verify_runtime; then
		print 'Vendor is already installed and verified.'
		exit 0
	fi
}

cleanup_install() {
	if [[ -n "$backup" && -d "$backup" && ! -e "$vendor" ]]; then
		mv "$backup" "$vendor"
	fi
	[[ -z "$workspace" ]] || rm -rf "$workspace"
	rmdir "$lock" 2>/dev/null || true
}

acquire_install_lock() {
	mkdir "$lock" 2>/dev/null || fail \
		"Another installation may be running. If interrupted, remove $lock before retrying."
}

create_staging_runtime() {
	workspace=$(mktemp -d "$cache/install.XXXXXX")
	stage="$workspace/runtime"
	mkdir -p "$stage/bin" "$stage/themes" "$stage/licenses"
	cp "$manifest" "$stage/licenses/vendor-manifest.tsv"
	print 'Pinned runtime archive provenance and licenses are included in this directory.' \
		>"$stage/licenses/THIRD_PARTY_NOTICES.txt"
}

fetch_verified_archive() {
	local name="$1"
	local version="$2"
	local digest="$3"
	local url="$4"
	local archive="$cache/$digest.tar.gz"
	local repository token actual

	if [[ -f "$archive" && "$(shasum -a 256 "$archive" | awk '{print $1}')" != "$digest" ]]; then
		rm "$archive"
	fi
	[[ -f "$archive" ]] && return

	print "Downloading $name $version..."
	repository=${url#https://ghcr.io/v2/}
	repository=${repository%/blobs/*}
	curl --fail --silent --show-error --location --retry 3 \
		--connect-timeout 20 --max-time 120 \
		"https://ghcr.io/token?service=ghcr.io&scope=repository:${repository}:pull" \
		-o "$workspace/token.json"
	token=$(plutil -extract token raw -o - "$workspace/token.json")
	curl --fail --silent --show-error --location --retry 3 \
		--connect-timeout 20 --max-time 600 \
		--header "Authorization: Bearer $token" "$url" \
		-o "$workspace/download.tar.gz"

	actual=$(shasum -a 256 "$workspace/download.tar.gz" | awk '{print $1}')
	[[ "$actual" == "$digest" ]] ||
		fail "SHA-256 mismatch for $name. Vendor has not been replaced."
	mv "$workspace/download.tar.gz" "$archive"
}

copy_license_files() {
	local package_root="$1"
	local package_name="$2"
	local license relative license_count=0

	mkdir -p "$stage/licenses/$package_name"
	for license in "$package_root"/**/*(N.); do
		case ${license:t} in
		LICENSE* | LICENCE* | COPYING* | COPYRIGHT* | AUTHORS* | NOTICE*)
			relative=${license#$package_root/}
			mkdir -p "$stage/licenses/$package_name/${relative:h}"
			cp "$license" "$stage/licenses/$package_name/$relative"
			((license_count += 1))
			;;
		esac
	done
	[[ $license_count -gt 0 ]] || fail "No license text found for $package_name"
}

extract_verified_archive() {
	local name="$1"
	local version="$2"
	local url="$3"
	local digest="$4"
	local archive="$cache/$digest.tar.gz"
	local unpack="$workspace/$name"
	local root
	local -a roots

	print "Extracting verified archive: $name $version"
	mkdir -p "$unpack"
	tar -xzf "$archive" -C "$unpack"
	roots=("$unpack"/*/*(N/))
	[[ ${#roots} == 1 ]] || fail "Unexpected archive layout for $name"
	[[ "$name" == btop ]] || fail "Unsupported runtime: $name"
	root=$roots[1]

	cp "$root/bin/btop" "$stage/bin/btop"
	chmod 755 "$stage/bin/btop"
	cp -R "$root/share/btop/themes/." "$stage/themes/"
	copy_license_files "$root" "$name"
	print -- "$name $version — $url — SHA-256: $digest" \
		>>"$stage/licenses/THIRD_PARTY_NOTICES.txt"
}

install_manifest_archives() {
	local name version digest url
	while IFS=$'\t' read -r name version digest url; do
		[[ -n "$name" && "$name" != \#* ]] || continue
		[[ "$digest" =~ '^[0-9a-f]{64}$' &&
			"$url" == https://ghcr.io/v2/homebrew/core/*/blobs/sha256:$digest ]] ||
			fail "Invalid manifest entry: $name"
		fetch_verified_archive "$name" "$version" "$digest" "$url"
		extract_verified_archive "$name" "$version" "$url" "$digest"
	done <"$manifest"
}

verify_binary_dependencies() {
	local binary dependency
	for binary in "$stage"/bin/*; do
		[[ $(file -b "$binary") == *arm64* ]] || fail "Not an ARM64 binary: $binary"
		while IFS= read -r dependency; do
			[[ "$dependency" == /usr/lib/* || "$dependency" == /System/Library/* ]] ||
				fail "Unexpected non-system dependency: $dependency"
		done < <(otool -L "$binary" | awk 'NR > 1 {print $1}')
		codesign --force --sign - "$binary"
	done
}

verify_staged_runtime() {
	# Check the staged tools without Homebrew lookup paths or DYLD overrides.
	env -u DYLD_LIBRARY_PATH -u DYLD_FALLBACK_LIBRARY_PATH "$stage/bin/btop" --version
	"$stage/bin/btop" --help | /usr/bin/grep -q -- '--themes-dir' ||
		fail 'The pinned btop does not support --themes-dir.'
	print -r -- "$manifest_hash" >"$stage/.manifest-sha256"
	(
		cd "$stage"
		find bin themes licenses -type f | LC_ALL=C sort |
			while IFS= read -r entry; do shasum -a 256 "$entry"; done
	) >"$stage/.runtime-sha256"
}

replace_runtime() {
	# Keep the old runtime until the staged copy has passed every check.
	if [[ -e "$vendor" ]]; then
		backup="$workspace/previous-vendor"
		mv "$vendor" "$backup"
	fi
	mv "$stage" "$vendor"
	verify_runtime || {
		rm -rf "$vendor"
		fail 'Installed runtime verification failed.'
	}
	print "Installed and verified local runtime: $vendor"
}

parse_arguments "$@"
validate_platform
if [[ "$mode" == --verify ]]; then
	handle_verify_mode
fi
handle_already_installed
mkdir -p "$cache"
acquire_install_lock
workspace=''
backup=''
trap cleanup_install EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
create_staging_runtime
install_manifest_archives
verify_binary_dependencies
verify_staged_runtime
replace_runtime
