# void-zenkernel domain glossary

Vocabulary for this repository. Terms here are the canonical names. Implementation lives in code, not here.

## Terms

- **Series**: a kernel major.minor line, for example `7.2`. One package pair per series. Directory name `linuxX.Y-zen`.
- **Tag**: a zen-kernel git tag this repo tracks. Only `lqx` (Liquorix) tags count, shape `vX.Y.Z-lqxN`. `zen` tags are ignored.
- **Variant**: the compiler flavour of a build. Two variants: `clang` (default) and `gcc`, selected by the xbps build option `clang`. Same series, same tag, same package name, different toolchain and generated config.
- **Template**: the xbps-src build recipe for one series at `srcpkgs/linuxX.Y-zen/template`. Hand-edited source; the updater rewrites only `version`, `_lqx` and `checksum`.
- **Base config**: Void Linux's own `x86_64-dotconfig` for the same series. Hardware enablement comes from here, never hand-edited in this repo.
- **Fragment**: a short Kconfig file stating intent on top of the base config. Fragments are the only hand-edited config input. Kinds: `zen`, `clang`, `gcc`, `local`.
- **Generated config**: the full `x86_64-dotconfig` (clang) and `x86_64-dotconfig-gcc` committed per series under `files/`. Output of base config plus fragments resolved by `olddefconfig`. Never hand-edited.
- **Updater**: the scheduled CI workflow. Watches tags, regenerates templates and generated configs, validates, commits.
- **Retention window**: the set of series kept in the tree. Current series and previous series only.
- **Config gate**: CI check that the generated config resolves without prompts and that every fragment line survived resolution.
