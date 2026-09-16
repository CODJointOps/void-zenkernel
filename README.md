# void-zenkernel

xbps-src templates for the Zen kernel (Liquorix `lqx` tags) on Void Linux, x86_64.

## Layout

```
srcpkgs/linuxX.Y-zen/           one package per kernel series, current and previous only
  template                      the source; hand-edited
  files/x86_64-dotconfig        generated: Void base + zen + clang fragments
  files/x86_64-dotconfig-gcc    generated: Void base + zen + gcc fragments
fragments/                      the only hand-edited config input
scripts/                        updater and config gate, POSIX sh
```

Clang with ThinLTO is the default. `gcc` is the build option `~clang` on the same package.

## Build

Clone this repo inside your void-packages checkout and link each package in. The package entry
must be a real directory (xbps-src treats a symlinked `srcpkgs/<name>` as a subpackage), so link
`template` and `files` inside it:

```sh
cd ~/gitprojects/void-packages
git clone https://git.deadzone.lol/Wizzard/void-zenkernel zen
for s in 7.1 7.2; do
  mkdir -p srcpkgs/linux$s-zen
  ln -sfn ../../zen/srcpkgs/linux$s-zen/template srcpkgs/linux$s-zen/template
  ln -sfn ../../zen/srcpkgs/linux$s-zen/files srcpkgs/linux$s-zen/files
  ln -sfn linux$s-zen srcpkgs/linux$s-zen-headers
  ln -sfn linux$s-zen srcpkgs/linux$s-zen-dbg
done
./xbps-src pkg linux7.2-zen              # clang, ThinLTO
./xbps-src -o '~clang' pkg linux7.2-zen  # gcc
```

The clone must live inside void-packages: the build chroot only sees that tree.

## Updates

`.gitea/workflows/update.yml` runs `scripts/update.sh` daily. On a new `lqx` tag it bumps the
template, regenerates both configs from Void's `linuxX.Y` base plus `fragments/`, fails if any
fragment line is dropped, and commits. It also re-converges the configs daily when Void's base
moves. Hand runs (`scripts/update.sh` without `-c`) are for inspection: the toolchain probe lines
(`CONFIG_CC_VERSION_TEXT` and friends) depend on the host compiler, so CI is what commits.
