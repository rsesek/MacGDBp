#!/bin/sh

set -e

if [[ 2 -ne $# ]]; then
  echo "Usage: $0 /path/to/archive.zip /path/to/keyring"
  exit 1
fi

THIS_DIR=$(dirname "$0")

ARCHIVE="$1"
KEYRING="$2"

DSA_SIG=$(openssl dgst -sha1 -binary "$ARCHIVE" | openssl dgst -sha1 -sign "$KEYRING/dsa_priv.pem" | openssl enc -base64)
EDSA_SIG=$("$THIS_DIR/signer-ed25519" -sign -key "$KEYRING/ed25519_priv.pem" -file "$ARCHIVE" | openssl enc -a -A)

echo "DSA     = $DSA_SIG"
echo "ED25519 = $EDSA_SIG"
