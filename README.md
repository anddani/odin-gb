# Odin Game Boy

A Game Boy Color emulator written in Odin.

## Running

The following command runs the emulator in a window backed by Raylib:

```sh
odin run src -- /path/to/rom.gb
```

## Running in the browser

To build a wasm binary, rum the follow build script:

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
## AI disclaimer

**None** of the code in the `src/` directory has been generated using AI. This project built as a learning experience to understand how the Game Boy works.
I explicitly instructed the coding agent to never suggest any code changes in `src/` and never suggest fixes in code review.
The only way I allowed it to communicate was in written communication.

A coding agent was used to ask clarifying questions, ask for sources,
ask for code review and generating tests in the `tests/` directory, example in `examples/` and a performance benchmark script in `bench/`.
