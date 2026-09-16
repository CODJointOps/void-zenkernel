#!/bin/sh
# Converge srcpkgs/ to the latest zen lqx tag: bump the template, regenerate
# both configs from the Void base plus fragments, gate them, prune old series.
# Usage: scripts/update.sh [-c]   (-c commits the result)
# Safe to rerun: a tree already at the tag ends with no diff.
set -eu
cd "$(dirname "$0")/.."
commit=
[ "${1:-}" = -c ] && commit=1
work=${UPDATE_WORK:-$(mktemp -d)}
mkdir -p "$work"

tag=$(git ls-remote --tags https://github.com/zen-kernel/zen-kernel.git 'refs/tags/v*-lqx*' |
	sed -E 's#.*refs/tags/##; s#\^\{\}$##' |
	grep -E '^v[0-9]+\.[0-9]+(\.[0-9]+)?-lqx[0-9]+$' | sort -uV | tail -n1)
[ -n "$tag" ] || { echo "no lqx tag found" >&2; exit 1; }
version=${tag%-lqx*}; version=${version#v}
lqx=${tag##*-lqx}
series=${version%.*}
root=zen-kernel-$version-lqx$lqx
pkg=srcpkgs/linux$series-zen
echo "tag $tag, series $series"

archive=$work/$root.tar.gz
[ -f "$archive" ] || curl -fsSL -o "$archive" "https://github.com/zen-kernel/zen-kernel/archive/refs/tags/$tag.tar.gz"
checksum=$(sha256sum "$archive" | cut -d' ' -f1)
[ -d "$work/$root" ] || tar -xzf "$archive" -C "$work" --wildcards \
	"$root/Makefile" "$root/Kbuild" "$root/Kconfig" "$root/scripts/*" "$root/arch/x86/*" '*/Kconfig*'

series_dirs() { for d in srcpkgs/linux*-zen; do echo "$d"; done | sort -V; }

# New series: copy the previous one forward and drop what falls out of the window.
if [ ! -d "$pkg" ]; then
	prev=$(series_dirs | tail -n1)
	cp -a "$prev" "$pkg"
	sed -i "s/linux[0-9.]*-zen/linux$series-zen/g" "$pkg/template"
	ln -s "linux$series-zen" "$pkg-headers"
	ln -s "linux$series-zen" "$pkg-dbg"
	series_dirs | head -n -2 | while read -r old; do
		rm -rf "$old" "$old-headers" "$old-dbg"
		echo "pruned $old"
	done
	echo "created $pkg from $prev"
fi

t=$pkg/template
cur_version=$(sed -n 's/^version=//p' "$t")
cur_lqx=$(sed -n 's/^_lqx=//p' "$t")
cur_sum=$(sed -n 's/^checksum=//p' "$t")
rev=$(sed -n 's/^revision=//p' "$t")
if [ "$cur_version-$cur_lqx" != "$version-$lqx" ]; then rev=1
elif [ "$cur_sum" != "$checksum" ]; then rev=$((rev + 1)); fi
sed -i -e "s/^version=.*/version=$version/" -e "s/^_lqx=.*/_lqx=$lqx/" \
	-e "s/^checksum=.*/checksum=$checksum/" -e "s/^revision=.*/revision=$rev/" "$t"

# Void base for this series; when Void has dropped it, converge from our own config.
base=$work/base.config
if curl -fsSL -o "$base" "https://raw.githubusercontent.com/void-linux/void-packages/master/srcpkgs/linux$series/files/x86_64-dotconfig"; then
	base_name="void linux$series"
else
	cp "$pkg/files/x86_64-dotconfig" "$base"
	base_name="previous $pkg config"
fi
echo "base: $base_name"

scripts/regen-config.sh "$work/$root" "$base" clang "$pkg/files/x86_64-dotconfig"
scripts/regen-config.sh "$work/$root" "$base" gcc "$pkg/files/x86_64-dotconfig-gcc"
xlint "$t"

git add -A srcpkgs
if git diff --cached --quiet; then
	echo "up to date at $tag"
	exit 0
fi
git diff --cached --stat
[ "$commit" ] && git commit -qm "Update to $tag (base: $base_name) [auto]" && echo "committed"
exit 0
