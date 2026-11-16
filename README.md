# Odin Gameboy

This project is a Gameboy Emulator

## Running

```sh
odin run src -- /path/to/rom.gb
```

## Running in the browser

```sh
./build_web.sh                    # builds web/odin-gb.wasm and copies odin.js
python3 -m http.server -d web     # then open http://localhost:8000
```

Pick or drop a ROM onto the page. Battery saves are kept in `localStorage`.

Controls: arrows = D-pad, X = A, Z = B, Enter = Start, Shift = Select.

`nix build .#web` produces the same files in `result/`, ready to be copied into
a static site. To embed it in another page, load `odin.js`, then:

```js
import { createEmulator } from "./odin-gb.js";
const emu = await createEmulator({ canvas: document.querySelector("canvas") });
await emu.loadRom(romBytes); // call from a click/file-pick so audio can start
```
