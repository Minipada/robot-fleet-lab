#!/usr/bin/env bash
# Build both images with kas. A cold build takes hours; the download cache and
# the sstate cache below make every later build take minutes. Keep them.
set -euo pipefail
# shellcheck source=lib.sh disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cache="${FLEET_LAB_CACHE:-$HOME/.cache/robot-fleet-lab}"
mkdir -p "$cache"/{work,downloads,sstate} "$LAB_DIR/build"

if [ -z "${KAS_CONTAINER_ENGINE:-}" ]; then
	if command -v docker >/dev/null; then
		KAS_CONTAINER_ENGINE=docker
	elif command -v podman >/dev/null; then
		KAS_CONTAINER_ENGINE=podman
	else
		die "need docker or podman to run kas-container"
	fi
fi
command -v kas-container >/dev/null || die "kas-container not found (pip install kas, or https://github.com/siemens/kas)"

export KAS_CONTAINER_ENGINE
# Rootless Docker needs a work directory of its own: kas takes ownership of it.
export KAS_WORK_DIR="$cache/work"
export KAS_BUILD_DIR="$LAB_DIR/build"
export DL_DIR="$cache/downloads"
export SSTATE_DIR="$cache/sstate"

cd "$LAB_DIR"
kas-container build kas.yml
