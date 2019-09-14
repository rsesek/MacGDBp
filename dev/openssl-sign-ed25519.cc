// clang++ -o openssl-sign-ed25519 openssl-sign-ed25519.cc -I/opt/local/include -L/opt/local/lib -lcrypto -std=c++14
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
openssl-sign-ed25519 provides a sign/verify interface for ED25519 operations.

Until https://github.com/openssl/openssl/issues/6988 is fixed, OpenSSL cannot
be used to generate and verify signatures of files using ED25519 keys. Sparkle
only supports ED25519 keys, so this tool is used to bridge the gap.

Usage:

  Get base64 signature:

    ./openssl-sign-ed25519 --sign --key /path/to/key.pem --file file.zip | openssl enc -a -A

  Verify signature:

    cat sig-b64 | openssl dec -a | ./openssl-sign-ed25519 --verify - --key /path/to/key.pem --file file.zip

Usage Notes:

  - Encrypted private keys are not supported as no password input is provided.

Implementation Notes:

  - No resources are freed since this is a one-shot tool.
*/

#include <fcntl.h>
#include <getopt.h>
#include <openssl/evp.h>
#include <openssl/err.h>
#include <openssl/pem.h>
#include <stdint.h>
#include <stdio.h>
#include <unistd.h>

#include <memory>
#include <vector>

const option kOptions[] = {
  {"key", required_argument, nullptr, 'k'},
  {"sign", no_argument, nullptr, 's'},
  {"verify", required_argument, nullptr, 'v'},
  {"file", required_argument, nullptr, 'i'},
  {nullptr, 0, nullptr, 0},
};

void Usage(const char* prog) {
  fprintf(stderr, "%s: ", prog);
  for (const auto& opt : kOptions) {
    if (!opt.name)
      continue;

    if (opt.has_arg == optional_argument)
      fprintf(stderr, "[");
    fprintf(stderr, "--%s", opt.name);
    if (opt.has_arg == optional_argument)
      fprintf(stderr, "]");

    if (opt.has_arg != no_argument)
      fprintf(stderr, " <%s>", opt.name);

    fprintf(stderr, " ");
  }
  fprintf(stderr, "\n");
}

void CryptoError(const char* msg) {
  unsigned long error = ERR_get_error();
  char buf[256];
  ERR_error_string(error, buf);
  fprintf(stderr, "%s: -%ld %s\n", msg, error, buf);
}

bool ReadEntireFile(const char* path, std::vector<uint8_t>* data) {
  int fd = -1;
  if (strncmp(path, "-", 1) == 0) {
    fd = STDIN_FILENO;
  } else {
    fd = open(path, O_RDONLY);
    if (fd < 0) {
      perror("open");
      return false;
    }
  }

  const size_t buffer_size = getpagesize();
  ssize_t bytes_read = 0;
  do {
    size_t current_size = data->size();
    data->resize(current_size + buffer_size);

    ssize_t bytes_read = read(fd, &(*data)[current_size], buffer_size);
    if (bytes_read < 0) {
      perror("read");
      return false;
    } else if (bytes_read >= 0) {
      data->resize(current_size + bytes_read);
    }
  } while (bytes_read > 0);

  return true;
}

bool LoadKeyAndCreateContext(const char* keyfile_path, EVP_PKEY** pkey, EVP_PKEY_CTX** pctx) {
  FILE* keyfile = fopen(keyfile_path, "r");
  if (!keyfile) {
    perror("fopen keyfile");
    return false;
  }

  *pkey = PEM_read_PrivateKey(keyfile, /*keyout=*/nullptr, /*password=*/nullptr, /*ucontext=*/nullptr);
  if (!*pkey) {
    CryptoError("Failed to read private key");
    return false;
  }

  *pctx = EVP_PKEY_CTX_new(*pkey, nullptr);
  if (!pctx) {
    CryptoError("Failed to create pkey context");
    return false;
  }

  return true;
}

bool SignFile(EVP_PKEY* pkey, EVP_PKEY_CTX* pctx, const char* infile_path) {
  int rv;

  std::vector<uint8_t> data;
  if (!ReadEntireFile(infile_path, &data))
    return false;

  EVP_MD_CTX* ctx = EVP_MD_CTX_new();
  rv = EVP_DigestSignInit(ctx, &pctx, /*type=*/nullptr, /*engine=*/nullptr, pkey);
  if (rv != 1) {
    CryptoError("Failed to initialize digest context");
    return false;
  }

  size_t signature_length;
  rv = EVP_DigestSign(ctx, nullptr, &signature_length, data.data(), data.size());
  if (rv != 1) {
    CryptoError("Failed to sign - get length");
    return false;
  }

  std::unique_ptr<uint8_t[]> signature(new uint8_t[signature_length]);
  rv = EVP_DigestSign(ctx, signature.get(), &signature_length, data.data(), data.size());
  if (rv < 0) {
    CryptoError("Failed to sign");
    return false;
  }

  for (size_t i = 0; i < signature_length; ) {
    ssize_t written = write(STDOUT_FILENO, &signature.get()[i], signature_length - i);
    if (written <= 0) {
      perror("write");
      return false;
    }
    i += written;
  }

  return true;
}

bool VerifyFile(EVP_PKEY* pkey, EVP_PKEY_CTX* pctx, const char* sigfile_path, const char* infile_path) {
  int rv;

  std::vector<uint8_t> signature;
  if (!ReadEntireFile(sigfile_path, &signature))
    return false;

  std::vector<uint8_t> data;
  if (!ReadEntireFile(infile_path, &data))
    return false;

  EVP_MD_CTX* ctx = EVP_MD_CTX_new();

  rv = EVP_DigestVerifyInit(ctx, &pctx, /*type=*/nullptr, /*engine=*/nullptr, pkey);
  if (rv != 1) {
    CryptoError("Failed to initialize verify context");
    return false;
  }

  rv = EVP_DigestVerify(ctx, signature.data(), signature.size(), data.data(), data.size());
  if (rv != 1) {
    printf("Failed to verify data.\n");
    return false;
  }

  printf("Verify OK.\n");

  return true;
}

int main(int argc, char* const argv[]) {
  bool do_sign = false;
  const char* keyfile = nullptr;
  const char* sigfile = nullptr;
  const char* infile = nullptr;

  int opt;
  while ((opt = getopt_long(argc, argv, "ksvih", kOptions, nullptr)) != -1) {
    switch (opt) {
      case 's':
        do_sign = true;
        break;
      case 'k':
        keyfile = optarg;
        break;
      case 'v':
        sigfile = optarg;
        break;
      case 'i':
        infile = optarg;
        break;
      case 'h':
        Usage(argv[0]);
        return EXIT_SUCCESS;
      default:
        Usage(argv[0]);
        return EXIT_FAILURE;
    }
  }

  if (!infile) {
    fprintf(stderr, "No input file specified.\n");
    Usage(argv[0]);
    return EXIT_FAILURE;
  }

  if (!keyfile) {
    fprintf(stderr, "Key must be specified.\n");
    Usage(argv[0]);
    return EXIT_FAILURE;
  }

  if (!(do_sign ^ (sigfile != nullptr))) {
    fprintf(stderr, "Must specify one of --sign or --verify.\n");
    Usage(argv[0]);
    return EXIT_FAILURE;
  }

  EVP_PKEY* pkey;
  EVP_PKEY_CTX* pctx;
  if (!LoadKeyAndCreateContext(keyfile, &pkey, &pctx))
    return EXIT_FAILURE;

  bool ok = false;

  if (do_sign)
    ok = SignFile(pkey, pctx, infile);
  else
    ok = VerifyFile(pkey, pctx, sigfile, infile);

  return ok ? EXIT_SUCCESS : EXIT_FAILURE;
}
