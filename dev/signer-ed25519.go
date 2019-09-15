/*
 * MacGDBp
 * Copyright (c) 2019, Blue Static <https://www.bluestatic.org>
 *
 * This program is free software; you can redistribute it and/or modify it under the terms of the GNU
 * General Public License as published by the Free Software Foundation; either version 2 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
 * even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with this program; if not,
 * write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA
 */

/*
signer-ed25519 provides a sign/verify interface for ED25519 operations.

Until https://github.com/openssl/openssl/issues/6988 is fixed, OpenSSL cannot
be used to generate and verify signatures of files using ED25519 keys. Sparkle
only supports ED25519 keys, so this tool is used to bridge the gap.

Usage:

  Create a new key pair:

    ./signer-ed25519 -new-key

  Get base64 signature:

    ./signer-ed25519 -sign -key privkey.pem -file file.zip | openssl enc -a -A

  Verify signature:

    ./signer-ed25519 -verify -signature <(openssl enc -d -a sig.b64) -key pubkey.pem -file file.zip

Usage Notes:

  - Encrypted private keys are not supported as no password input is provided.
*/

package main

import (
	"crypto"
	"crypto/ed25519"
	"encoding/pem"
	"flag"
	"fmt"
	"io/ioutil"
	"os"
)

var (
	keyPath  = flag.String("key", "Path to the key file.", "")
	inPath   = flag.String("file", "Path to the file to sign/verify.", "")
	sigPath  = flag.String("signature", "Path to the signature file.", "")
	doSign   = flag.Bool("sign", false, "Sign the given file.")
	doVerify = flag.Bool("verify", false, "Verify the given file.")
	doNewKey = flag.Bool("new-key", false, "Generate a new keypair.")
)

func main() {
	flag.Parse()

	if *doNewKey {
		newKey()
		os.Exit(0)
	}

	if (!*doSign && !*doVerify) || (*doSign && *doVerify) {
		fmt.Fprintf(os.Stderr, "Must specify either -sign or -verify.\n")
		os.Exit(1)
	}

	keyPemData, err := ioutil.ReadFile(*keyPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to read key: %v.\n", err)
		os.Exit(1)
	}

	keyPem, _ := pem.Decode(keyPemData)
	if keyPem == nil {
		fmt.Fprintf(os.Stderr, "Failed to decode PEM.\n", err)
		os.Exit(1)
	}

	if *doSign {
		sign(keyPem)
	}

	if *doVerify {
		verify(keyPem)
	}
}

func newKey() {
	pub := &pem.Block{Type: "PUBLIC KEY"}
	priv := &pem.Block{Type: "PRIVATE KEY"}
	var err error
	pub.Bytes, priv.Bytes, err = ed25519.GenerateKey(nil)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to generate new key pair: %v.\n", err)
		os.Exit(1)
	}

	if err := pem.Encode(os.Stdout, pub); err != nil {
		fmt.Fprintf(os.Stderr, "Failed to write public key: %v.\n", err)
	}
	if err := pem.Encode(os.Stdout, priv); err != nil {
		fmt.Fprintf(os.Stderr, "Failed to write private key: %v.\n", err)
	}
}

func sign(keyPem *pem.Block) {
	if keyPem.Type != "PRIVATE KEY" {
		fmt.Fprintf(os.Stderr, "Signing expects a private key.\n")
		os.Exit(1)
	}

	key := ed25519.PrivateKey(keyPem.Bytes)

	signature, err := key.Sign(nil, readInput(), crypto.Hash(0))
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to sign file: %v.\n", err)
		os.Exit(1)
	}

	if _, err := os.Stdout.Write(signature); err != nil {
		fmt.Fprintf(os.Stderr, "Failed to write output: %v.\n", err)
		os.Exit(1)
	}
}

func verify(keyPem *pem.Block) {
	if keyPem.Type != "PUBLIC KEY" {
		fmt.Fprintf(os.Stderr, "Verifying expects a public key.\n")
		os.Exit(1)
	}

	key := ed25519.PublicKey(keyPem.Bytes)

	signature, err := ioutil.ReadFile(*sigPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to read signature file: %v.\n", err)
		os.Exit(1)
	}

	if ed25519.Verify(key, readInput(), signature) {
		fmt.Println("Verify OK.")
	} else {
		fmt.Println("Verify FAILED!")
	}
}

func readInput() (fileData []byte) {
	fileData, err := ioutil.ReadFile(*inPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to read input file: %v.\n", err)
		os.Exit(1)
	}
	return
}
