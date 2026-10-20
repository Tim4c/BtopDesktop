#!/bin/zsh
set -euo pipefail

identity='BtopDesktop Local Development'
keychain=$(security default-keychain -d user | tr -d '"' | xargs)
temporary_dir=$(mktemp -d "${TMPDIR:-/tmp/}btop-signing.XXXXXX")
trap 'rm -rf "$temporary_dir"' EXIT
umask 077

identity_is_available() {
	security find-identity -v -p codesigning "$keychain" |
		/usr/bin/grep -Fq "\"$identity\""
}

ensure_no_invalid_certificate_exists() {
	if security find-certificate -c "$identity" "$keychain" >/dev/null 2>&1; then
		print -u2 "A certificate named $identity already exists but is not a valid signing identity."
		print -u2 'Inspect its private key, expiry, and code-signing trust in Keychain Access before retrying.'
		exit 1
	fi
}

write_certificate_configuration() {
	cat >"$temporary_dir/certificate.cnf" <<'CONFIG'
[req]
prompt = no
distinguished_name = subject
x509_extensions = signing
[subject]
CN = BtopDesktop Local Development
[signing]
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
CONFIG
}

create_certificate_and_private_key() {
	/usr/bin/openssl req -new -x509 -newkey rsa:2048 -nodes -days 3650 \
		-config "$temporary_dir/certificate.cnf" \
		-keyout "$temporary_dir/private.key" \
		-out "$temporary_dir/certificate.pem" 2>/dev/null
}

import_signing_identity() {
	export BTOP_CERTIFICATE_PASSWORD=$(/usr/bin/openssl rand -hex 24)
	/usr/bin/openssl pkcs12 -export \
		-inkey "$temporary_dir/private.key" \
		-in "$temporary_dir/certificate.pem" \
		-out "$temporary_dir/identity.p12" \
		-passout env:BTOP_CERTIFICATE_PASSWORD

	security import "$temporary_dir/identity.p12" -k "$keychain" \
		-P "$BTOP_CERTIFICATE_PASSWORD" \
		-T /usr/bin/codesign
	unset BTOP_CERTIFICATE_PASSWORD

	# Trust this certificate for code signing at user level only.
	security add-trusted-cert -r trustRoot -p codeSign \
		-k "$keychain" "$temporary_dir/certificate.pem"
}

verify_signing_identity() {
	if ! identity_is_available; then
		print -u2 'The certificate was imported, but code-signing trust is not yet valid.'
		exit 1
	fi
	print "Signing identity ready: $identity"
}

if identity_is_available; then
	print "Signing identity already available: $identity"
	exit 0
fi

ensure_no_invalid_certificate_exists
write_certificate_configuration
create_certificate_and_private_key
import_signing_identity
verify_signing_identity
