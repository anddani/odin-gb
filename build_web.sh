#!/usr/bin/env sh
# Builds the browser version into web/. Serve that directory with any static
# file server, e.g. `python3 -m http.server -d web`.
set -eu
cd "$(dirname "$0")"
odin build src/web -target:js_wasm32 -out:web/odin-gb.wasm -o:speed
# install (not cp): the source lives in the read-only nix store
install -m 644 "$(odin root)/core/sys/wasm/js/odin.js" web/odin.js
