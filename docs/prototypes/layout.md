# Tree layout and template generation: three candidates

Ticket: https://git.deadzone.lol/Wizzard/void-zenkernel/issues/4

Facts that shape the choice (verified 2026-09-16 against `~/gitprojects/void-packages`):

- Both variant templates today set `pkgname=linux7.2-zen`. They already cannot coexist in one
  `srcpkgs/`; the maintainer copies one of them in. The binary packages also share a name and
  install the same `/boot/vmlinuz-<kernver>`, so they could never be co-installed.
- The clang and gcc templates differ in 4 things: `short_desc`, `homepage` (accidental drift),
  `hostmakedepends` (`clang llvm lld which`), and `_toolchain_args` on every `make` line.
  `LLVM=1` replaces the whole `_toolchain_args` list on 7.x kernels; the config gate already uses it.
- `xbps-src` sources the template, resolves `build_options`, then sources it again
  (`common/xbps-src/shutils/common.sh:276-281`), so `$(vopt_if clang ...)` works in top-level
  variables. `srcpkgs/kbdd/template` uses exactly that for `makedepends`.
- The chroot bind-mounts the void-packages tree at `/void-packages`
  (`common/chroot-style/bwrap.sh:23`). A symlink from `srcpkgs/` that points outside that tree is
  dangling inside the build. Ticket #8 has to keep the checkout inside void-packages.
- `-headers` / `-dbg` are relative symlinks to the package dir; `setup_pkg` derives `basepkg`
  from the name, not from `readlink`, so symlinks whose target is itself a symlink are fine.

## Candidate A: committed outputs plus a `src/` generator

```
src/
  template.in                 # 300 lines with @VARIANT@ @CC_DEPS@ @TOOLCHAIN@ placeholders
  fragments/{zen,clang,gcc,local}.config
  mv-debug
scripts/
  gen-template.sh             # sed placeholders -> linux-<cc>/linux<S>-zen/template
  regen-config.sh             # base + fragments -> files/x86_64-dotconfig
  gate.sh
linux-clang/linux7.2-zen/{template,files/{x86_64-dotconfig,mv-debug}}   # generated, committed
linux-clang/linux7.2-zen-headers -> linux7.2-zen
linux-clang/linux7.2-zen-dbg -> linux7.2-zen
linux-gcc/linux7.2-zen/...                                              # generated, committed
linux-{clang,gcc}/linux7.1-zen/...
```

`template.in` excerpt:

```sh
short_desc="Linux kernel and modules with Zen patches (${version%.*} series@DESC_SUFFIX@)"
hostmakedepends="tar xz bc elfutils-devel flex gmp-devel kmod libmpc-devel
 pkg-config openssl-devel perl uboot-mkimage cpio pahole python3 zstd@CC_DEPS@"
_toolchain_args="@TOOLCHAIN@"
```

`gen-template.sh clang 7.2` substitutes `@CC_DEPS@=" clang llvm lld"`, `@TOOLCHAIN@="LLVM=1"`,
`@DESC_SUFFIX@=", Clang"`; `gcc` substitutes empty strings.

Updater on tag bump: `gen-template.sh` for both variants and the series, `regen-config.sh` twice,
gate, commit. New series: same, nothing to copy.

Consumption: symlink `linux-clang/linux7.2-zen` into `srcpkgs/`.

Cost: a placeholder mini-language, four generated templates per retention window that reviewers
must not edit, and the variant delta split across `template.in` and the generator. Every bump
diff touches 4 templates that say the same thing. Still one `pkgname`, so the "separate packages"
constraint is not met any better than today.

## Candidate B: one `srcpkgs/`-shaped tree, variant is a build option

```
srcpkgs/
  linux7.2-zen/
    template                  # the source; no generator for templates
    files/
      x86_64-dotconfig        # generated: base + zen + clang + local
      x86_64-dotconfig-gcc    # generated: base + zen + gcc + local
      mv-debug
  linux7.2-zen-headers -> linux7.2-zen
  linux7.2-zen-dbg -> linux7.2-zen
  linux7.1-zen/...
fragments/
  zen.config  clang.config  gcc.config  local.config
scripts/
  regen-config.sh             # <series> <clang|gcc>: fetch base (fallback rule from #2), merge, olddefconfig
  gate.sh                     # fragment-scoped drop check from #2
  update.sh                   # tag scan, bump, new-series copy; runs in CI and by hand
.gitea/workflows/update.yml   # thin: apt deps, scripts/update.sh, rebase, push
```

`srcpkgs/linux7.2-zen/template` head (x86_64 only, so every `case "$XBPS_TARGET_MACHINE"` block
collapses; roughly 150 lines instead of 310):

```sh
# Template file for 'linux7.2-zen'
pkgname=linux7.2-zen
version=7.2.6
revision=1
_lqx=1
archs="x86_64"
create_wrksrc=yes
build_wrksrc="zen-kernel-${version}-lqx${_lqx}"
short_desc="Linux kernel and modules with Zen patches (${version%.*} series$(vopt_if clang ', Clang ThinLTO'))"
maintainer="Wizzard <retard@deadzone.lol>"
license="GPL-2.0-only"
homepage="https://github.com/zen-kernel/zen-kernel"
distfiles="https://github.com/zen-kernel/zen-kernel/archive/refs/tags/v${version}-lqx${_lqx}.tar.gz"
checksum=c7acb9bf088728dc423cb266c2ea2e6278a6ed296af3cf98810dc379e9b7c4b1
python_version=3
patch_args="-Np1"

build_options="clang"
build_options_default="clang"
desc_option_clang="Build with Clang, LLD and ThinLTO"

hostmakedepends="tar xz bc elfutils-devel flex gmp-devel kmod libmpc-devel
 pkg-config openssl-devel perl uboot-mkimage cpio pahole python3 zstd
 $(vopt_if clang 'clang llvm lld')"

_toolchain="$(vopt_if clang LLVM=1)"
_dotconfig="x86_64-dotconfig$(vopt_if clang '' -gcc)"
_kernver="${version}-lqx${_lqx}_${revision}"
# KCFLAGS for x86-64-v3 lands here once #5 settles the CPU target.

do_configure() {
	cp -f ${FILESDIR}/${_dotconfig} .config
	make ${_toolchain} ${makejobs} ARCH=x86_64 olddefconfig
	sed -i -e "s|^\(CONFIG_LOCALVERSION=\).*|\1\"_${revision}\"|" .config
}

do_build() {
	export LDFLAGS=
	make ${_toolchain} ARCH=x86_64 ${makejobs} prepare
	make ${_toolchain} ARCH=x86_64 ${makejobs} bzImage modules
}
```

Build gcc: `./xbps-src -o '~clang' pkg linux7.2-zen`, or `XBPS_PKG_OPTIONS_linux7.2_zen=~clang`
in `etc/conf`. Binary package name is the same either way; the local repo keeps the last build.

Updater on tag bump: `sed` the `version=`, `_lqx=`, `checksum=` lines (what `update.yml` does
today), `regen-config.sh` twice, gate, commit. New series: `cp -a srcpkgs/linux7.1-zen
srcpkgs/linux7.2-zen`, `sed pkgname`, two symlinks, regen, gate. Prune: `git rm -r` the oldest
series dir and its two symlinks.

Consumption (ticket #8): clone this repo inside the void-packages tree, for example
`~/gitprojects/void-packages/zen/`, and `ln -s ../zen/srcpkgs/linux7.2-zen srcpkgs/`. The link
stays inside the bind mount.

Cost: the two variants cannot be built in one invocation and cannot both sit in the local repo.
A second binary name (`linux7.2-zen-gcc`) would need a generator again. Two generated configs per
series instead of one per variant dir; same byte count as today.

## Candidate C: status quo directories, updater only regenerates configs

```
linux-clang/linux7.2-zen/{template,files/{x86_64-dotconfig,mv-debug}}   # hand-edited template
linux-gcc/linux7.2-zen/...                                              # hand-edited template
fragments/{zen,clang,gcc,local}.config
scripts/{regen-config.sh,gate.sh}
.gitea/workflows/update.yml
```

Nothing moves. Templates stay hand-maintained per variant per series; the updater keeps its
`sed` bumping and the copy-forward for new series, gains config regeneration and the gate.

Cost: four templates per retention window, hand-edited, already drifting (`homepage` differs
between variants, 6.17 clang carried a gcc config). Any change to `do_install` is made four
times. This is the shape the map exists to leave.

## Screen against design red flags

- A: pass-through layer. `template.in` plus `gen-template.sh` adds a format and a step but no
  capability xbps-src does not already give through `build_options`. Variant knowledge leaks
  into two places (placeholders in the source, values in the generator).
- B: one deep interface. The template is the single source and the single output; the variant
  is one word (`clang`) resolved by the tool that consumes the template. Generated artifacts are
  only the two configs, which the map already commits to generating.
- C: shallow modules by count. Four near-identical 310-line files, no seam between intent and
  output.

## Recommendation

**B.** Directory names `srcpkgs/`, `fragments/`, `scripts/`. `srcpkgs/` mirrors void-packages so
the symlink target reads the same on both sides. Scripts in POSIX `sh` under `shellcheck`: the
updater is shell already, the runner and the Void box both have `sh`, and the gate from #2 is 10
lines. Python would add an interpreter dependency for string substitution. The workflow YAML
becomes a thin wrapper so `scripts/update.sh` runs identically by hand on the box.

Decisions this leaves to the maintainer:

1. Accept that gcc becomes a build option rather than a second package. The alternative that
   keeps two packages is A with distinct `pkgname`s, which reintroduces the generator.
2. `LLVM=1` in place of the explicit `CC=clang ... HOSTAR=llvm-ar` list.
3. `olddefconfig` in `do_configure` in place of `oldconfig` (today's `oldconfig` runs with no tty
   and silently defaults, per #2).
4. Fragments shared across series at the repo root, resolved per series against that series'
   base. A fragment line that a new series drops fails the gate and gets fixed once.
