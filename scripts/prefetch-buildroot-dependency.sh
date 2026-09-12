#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

name="${1:-automake-1.16.5.tar.xz}"
case "$name" in
  automake-1.16.5.tar.xz)
    url="https://ftp.gnu.org/gnu/automake/$name"
    hash_file="linux-baseline/buildroot/package/automake/automake.hash"
    destination="linux-baseline/buildroot/dl/automake/$name"
    ;;
  gcc-13.4.0.tar.xz)
    url="https://ftp.gnu.org/gnu/gcc/gcc-13.4.0/$name"
    hash_file="linux-baseline/buildroot/package/gcc/gcc.hash"
    destination="linux-baseline/buildroot/dl/gcc/$name"
    ;;
  *) echo "No pinned canonical-source mapping for $name" >&2; exit 2 ;;
esac

temp_file="$(mktemp)"
trap 'rm -f "$temp_file"' EXIT
wget --timeout=30 --tries=3 -O "$temp_file" "$url"
algorithm="$(awk -v name="$name" '$3 == name {print $1; exit}' "$hash_file")"
expected="$(awk -v name="$name" '$3 == name {print $2; exit}' "$hash_file")"
case "$algorithm" in sha256|sha512) ;; *) echo "Unsupported or missing hash algorithm: $algorithm" >&2; exit 3;; esac
actual="$("${algorithm}sum" "$temp_file" | cut -d' ' -f1)"
[[ -n "$expected" && "$actual" == "$expected" ]]
mkdir -p "$(dirname "$destination")"
install -m 0644 "$temp_file" "$destination"
echo "$name verified ($algorithm): $actual"
