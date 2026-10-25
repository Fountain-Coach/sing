#!/bin/sh
# Install/repair the PRIVATE bounded WORLD research lane on the separate disk.
# No new production package, service, model, media assets, GitHub CI or CoreMIDI.
set -eu
base=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
mount_point=/Volumes/DockerDisk
target="$mount_point/fountain-coach/devtools/sing-world-venv"
requirements="$base/requirements-world-macos-arm64.txt"

if [ "$(uname -s)" != "Darwin" ] || [ "$(uname -m)" != "arm64" ]; then
  echo "WORLD research requires authorized Apple Silicon macOS" >&2
  exit 2
fi
if ! mount | grep -F " on $mount_point " >/dev/null; then
  echo "External DockerDisk is not mounted: refusing internal drive install" >&2
  exit 3
fi
if [ ! -f "$requirements" ]; then
  echo "Missing hashed private WORLD requirements" >&2
  exit 4
fi
python3 -c 'import sys; assert sys.version_info[:2] == (3,14), "Python 3.14 required"'
if [ ! -x "$target/bin/python" ]; then
  mkdir -p "$(dirname "$target")"
  python3 -m venv "$target"
fi
# Installed research tools are self-managed. Avoid unnecessary reinstallation,
# particularly when a mounted external volume transiently fails a pip import.
# Reinstall only when the exact, pinned dependency inspection fails.
if "$target/bin/python" -c 'import sys,pyworld,numpy,importlib.metadata as m; assert sys.version_info[:2] == (3,14); assert m.version("pyworld-prebuilt") == "0.3.6.post1"; assert m.version("numpy") == "2.3.4"' 2>/dev/null; then
  echo "Existing WORLD research environment already matches pinned versions"
else
  "$target/bin/python" -m pip install --disable-pip-version-check --no-cache-dir \
    --only-binary=:all: --require-hashes -r "$requirements"
fi
"$target/bin/python" -c 'import sys,pyworld,numpy,importlib.metadata as m; assert sys.version_info[:2] == (3,14); assert m.version("pyworld-prebuilt") == "0.3.6.post1"; assert m.version("numpy") == "2.3.4"; print("WORLD research verified (no publication)")'
printf 'PRIVATE_WORLD_PYTHON=%s\n' "$target/bin/python"
