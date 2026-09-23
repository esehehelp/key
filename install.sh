#!/usr/bin/env bash
set -euo pipefail
sketchbook="${1:-$HOME/Arduino}"
toolchain="${2:-$HOME/.platformio/packages/toolchain-riscv/bin}"
source_dir="$(cd "$(dirname "$0")" && pwd)/hardware/key/ch32x035f7p6"
dest="$sketchbook/hardware/key/ch32x035f7p6"
if [[ ! -x "$toolchain/riscv-wch-elf-gcc" ]]; then
  echo "Missing $toolchain/riscv-wch-elf-gcc; install PlatformIO's CH32 toolchain or pass its bin directory as argument 2." >&2
  exit 1
fi
mkdir -p "$dest/tools/gcc/bin"
cp -a "$source_dir/." "$dest/"
for tool in gcc g++ ar objcopy size; do
  ln -sfn "$toolchain/riscv-wch-elf-$tool" "$dest/tools/gcc/bin/riscv-none-embed-$tool"
done
echo "Installed to $dest. Install wchisp and restart Arduino IDE."
