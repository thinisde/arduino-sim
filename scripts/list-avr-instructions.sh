#!/usr/bin/env bash
set -euo pipefail

elf="$1"

avr-objdump -d "$elf" \
  | perl -ne 'if (/^\s*[0-9a-f]+:\s+(?:[0-9a-f]{2}\s+)+\s*([a-z][a-z0-9.]*)\b/) { print uc($1), "\n" }' \
  | sort -u
