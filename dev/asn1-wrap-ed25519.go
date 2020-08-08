/*
 * MacGDBp
 * Copyright (c) 2020, Blue Static <https://www.bluestatic.org>
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
asn1-wrap-ed25519 takes a raw private key from signer-ed25519 and reencodes it as PEM PKCS8 (ASN.1).

The raw keys generated by signer-ed25519 are not compatible with the OpenSSL
command. By storing it in PKCS8, the keys can be used with openssl commands.

Usage:

	./signer-ed25519 -new-key > out.key
	./asn1-wrap-ed25519 out.key > out-wrapped.key
*/
package main

import (
	"crypto/ed25519"
	"crypto/x509"
	"encoding/pem"
	"fmt"
	"io/ioutil"
	"os"
)

func main() {
	keyfile := os.Args[1]

	keyPemData, err := ioutil.ReadFile(keyfile)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to read key: %v\n", err)
		os.Exit(1)
	}

	keyPem, _ := pem.Decode(keyPemData)
	if keyPem == nil {
		fmt.Fprintf(os.Stderr, "Failed to decode PEM: %v\n", err)
		os.Exit(1)
	}

	key := ed25519.PrivateKey(keyPem.Bytes)

	asn1Bytes, err := x509.MarshalPKCS8PrivateKey(key)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to ASN.1 encode key: %v\n", err)
		os.Exit(1)
	}

	asn1Pem := &pem.Block{Type: "PRIVATE KEY", Bytes: asn1Bytes}

	err = pem.Encode(os.Stdout, asn1Pem)
	if err != nil {
		fmt.Println("Failed to PEM-encode ASN.1 key: %v\n", err)
		os.Exit(1)
	}
}
