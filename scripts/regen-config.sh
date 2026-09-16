#!/bin/sh
# Resolve Void base + fragments into one variant's config.
# Usage: regen-config.sh <kernel-src> <base.config> <clang|gcc> <out-file>
# Exit 1 and leave <out-file> untouched if olddefconfig dropped any fragment line.
set -eu
src=$1 base=$2 variant=$3 out=$4
frag=$(cd "$(dirname "$0")/.." && pwd)/fragments
o=$(mktemp -d)
trap 'rm -rf "$o"' EXIT
mk=
[ "$variant" = clang ] && mk=LLVM=1

"$src/scripts/kconfig/merge_config.sh" -m -O "$o" "$base" \
	"$frag/zen.config" "$frag/$variant.config" "$frag/local.config" </dev/null >/dev/null
make -s -C "$src" O="$o" $mk olddefconfig </dev/null

rc=0
for f in "$frag/zen.config" "$frag/$variant.config" "$frag/local.config"; do
	while IFS= read -r line; do
		case $line in
		CONFIG_*)
			grep -qxF -- "$line" "$o/.config" || { echo "DROPPED ($variant): $line" >&2; rc=1; } ;;
		'# CONFIG_'*' is not set')
			sym=${line#\# }; sym=${sym% is not set}
			! grep -q "^$sym=" "$o/.config" || { echo "DROPPED ($variant): $line" >&2; rc=1; } ;;
		esac
	done <"$f"
done
[ $rc -eq 0 ] && cp "$o/.config" "$out"
exit $rc
