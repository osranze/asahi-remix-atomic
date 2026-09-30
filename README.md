# asahi-remix-atomic

An experimental Asahi Remix Atomic image

Works on my machine

## Layout

```
Containerfile.base              base image: Fedora Asahi Remix rootfs, no desktop
Containerfile.wmx               derived image: desktop payload on top of base

ctx/base/                       base variant
  packages.txt                  package set installed by 01.rootfs.sh
  01.rootfs.sh                  bootstraps /target-rootfs (builder stage, host side)
  02.postprocess.sh             postprocesses the rootfs (runs inside the chroot)
  ext/                          files copied verbatim into the target rootfs

ctx/desktop/                    desktop variant
  01.base.sh .. 05.initramfs.sh ordered build stages
  99.cleanup.sh                 final cleanup
  lib/                          helpers sourced by the stages
  ext/                          files copied verbatim into the target rootfs

.github/workflows/
  bootable-containers.yml       reusable builder: build, chunk, push, sign
  build-base.yml                builds Containerfile.base -> base
  build-wmx.yml                 builds Containerfile.wmx  -> wmx
  clean.yml                     registry and workflow-run retention
```

## Variants

The image variants are named `base` and `wmx`, and that name is used
everywhere: `Containerfile.<variant>`,
`.github/workflows/build-<variant>.yml`, and `image_tag: <variant>`.

## Conventions

- Image variants: one directory per variant under `ctx/`, one
  `Containerfile.<variant>`, one `build-<variant>.yml`.
- Variant scripts are numbered in execution order, `NN.<stage>.sh`. Sourced
  helpers live in that variant's `lib/`. Configuration that belongs inside the
  target rootfs mirrors the absolute path under `ext/`.
- Shell scripts start with `#!/usr/bin/env bash` and `set -xeuo pipefail`, use
  4-space indentation, `[[ ]]` for tests, quoted expansions, and lowercase
  script-local variables; values injected by the build (`REL_VER`) stay
  uppercase. Section headers use `# --- topic ---`.
- Containerfiles are `# syntax`-free, declare build args before their `FROM`,
  and end with the identical bootc footer (`bootc container lint`,
  `containers.bootc=1`, `container=oci`, `STOPSIGNAL`, `CMD`).
