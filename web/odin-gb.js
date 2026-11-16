// Browser host for the odin-gb wasm build.
//
// Requires core:sys/wasm/js/odin.js to be loaded first (it defines window.odin).
//
//   const emu = await createEmulator({ canvas, wasmUrl: "odin-gb.wasm" });
//   emu.loadRom(new Uint8Array(await file.arrayBuffer()));

const WIDTH = 160;
const HEIGHT = 144;
const CPU_HZ = 4194304;
const TICKS_PER_FRAME = 70224;
const FRAME_MS = (TICKS_PER_FRAME / CPU_HZ) * 1000;
const SAMPLE_HZ = 48000;
const SAVE_INTERVAL_MS = 5000;

// Same mapping as src/main.odin.
const KEYMAP = {
  ArrowRight: ["dirs", 0b0001],
  ArrowLeft: ["dirs", 0b0010],
  ArrowUp: ["dirs", 0b0100],
  ArrowDown: ["dirs", 0b1000],
  KeyX: ["btns", 0b0001], // A
  KeyZ: ["btns", 0b0010], // B
  ShiftRight: ["btns", 0b0100], // Select
  ShiftLeft: ["btns", 0b0100],
  Enter: ["btns", 0b1000], // Start
};

const CART_ERRORS = ["None", "File_Unreadable", "Too_Small"];

export async function createEmulator({
  canvas,
  wasmUrl = new URL("odin-gb.wasm", import.meta.url),
  workletUrl = new URL("audio-worklet.js", import.meta.url),
  keyTarget = window,
}) {
  const memInterface = new window.odin.WasmMemoryInterface();
  const imports = window.odin.setupDefaultImports(memInterface, null);
  const { instance } = await WebAssembly.instantiateStreaming(fetch(wasmUrl), imports);
  const wasm = instance.exports;
  memInterface.setExports(wasm);
  memInterface.setMemory(wasm.memory);
  wasm._start();

  const ctx2d = canvas.getContext("2d");
  canvas.width = WIDTH;
  canvas.height = HEIGHT;

  const input = { dirs: 0, btns: 0 };
  let running = false;
  let rafId = 0;
  let lastTime = 0;
  let acc = 0;
  let audio = null;
  let saveKey = null;
  let saveTimer = 0;

  const bytes = (ptr, len) => new Uint8Array(wasm.memory.buffer, ptr, len);

  function onKey(e) {
    const m = KEYMAP[e.code];
    if (!m) return;
    e.preventDefault();
    const [group, bit] = m;
    if (e.type === "keydown") input[group] |= bit;
    else input[group] &= ~bit;
  }
  keyTarget.addEventListener("keydown", onKey);
  keyTarget.addEventListener("keyup", onKey);

  async function startAudio() {
    if (audio) {
      await audio.ctx.resume();
      return;
    }
    const ctx = new AudioContext({ sampleRate: SAMPLE_HZ });
    await ctx.audioWorklet.addModule(workletUrl);
    const node = new AudioWorkletNode(ctx, "odin-gb-audio", { outputChannelCount: [2] });
    node.connect(ctx.destination);
    audio = { ctx, node };
  }

  function pushAudio() {
    const n = wasm.web_audio_drain();
    if (!audio || n === 0) return;
    const src = new Int16Array(wasm.memory.buffer, wasm.web_audio_buffer(), n);
    const out = new Float32Array(n);
    for (let i = 0; i < n; i++) out[i] = src[i] / 32768;
    audio.node.port.postMessage(out, [out.buffer]);
  }

  function draw() {
    const px = new Uint8ClampedArray(wasm.memory.buffer, wasm.web_framebuffer(), WIDTH * HEIGHT * 4);
    ctx2d.putImageData(new ImageData(px, WIDTH, HEIGHT), 0, 0);
  }

  function tick(now) {
    if (!running) return;
    acc += Math.min(now - lastTime, FRAME_MS * 4);
    lastTime = now;

    let ran = false;
    while (acc >= FRAME_MS) {
      wasm.web_set_input(input.dirs, input.btns);
      wasm.web_run_frame();
      pushAudio();
      acc -= FRAME_MS;
      ran = true;
    }
    if (ran) draw();

    if (now - saveTimer > SAVE_INTERVAL_MS) {
      persistSave();
      saveTimer = now;
    }
    rafId = requestAnimationFrame(tick);
  }

  function romTitle(rom) {
    let s = "";
    for (let i = 0x134; i < 0x144 && rom[i] !== 0; i++) s += String.fromCharCode(rom[i]);
    return s.trim() || "untitled";
  }

  function restoreSave() {
    const len = wasm.web_save_ram_len();
    if (!len || !saveKey) return;
    let stored;
    try {
      stored = localStorage.getItem(saveKey);
    } catch {
      return;
    }
    if (!stored) return;
    const data = Uint8Array.from(atob(stored), (c) => c.charCodeAt(0));
    bytes(wasm.web_save_ram(), len).set(data.subarray(0, len));
  }

  function persistSave() {
    const len = wasm.web_save_ram_len();
    if (!len || !saveKey) return;
    const ram = bytes(wasm.web_save_ram(), len);
    let bin = "";
    for (let i = 0; i < ram.length; i++) bin += String.fromCharCode(ram[i]);
    try {
      localStorage.setItem(saveKey, btoa(bin));
    } catch {
      // Storage full or blocked and save does not persist.
    }
  }

  function onHide() {
    if (document.visibilityState === "hidden") persistSave();
  }
  document.addEventListener("visibilitychange", onHide);
  window.addEventListener("pagehide", persistSave);

  return {
    // Call from a user gesture (click, file pick, drop) so audio can start.
    async loadRom(rom) {
      pause();
      persistSave();

      bytes(wasm.web_rom_alloc(rom.length), rom.length).set(rom);
      const err = wasm.web_load_rom();
      if (err !== 0) throw new Error(`Loading ROM failed: ${CART_ERRORS[err] ?? err}`);

      saveKey = `odin-gb:save:${romTitle(rom)}`;
      restoreSave();

      try {
        await startAudio();
      } catch (e) {
        console.warn("odin-gb: audio unavailable", e);
      }
      resume();
    },
    pause,
    resume,
    destroy() {
      pause();
      persistSave();
      keyTarget.removeEventListener("keydown", onKey);
      keyTarget.removeEventListener("keyup", onKey);
      document.removeEventListener("visibilitychange", onHide);
      window.removeEventListener("pagehide", persistSave);
      audio?.ctx.close();
    },
  };

  function pause() {
    running = false;
    cancelAnimationFrame(rafId);
    audio?.ctx.suspend();
  }

  function resume() {
    if (running) return;
    running = true;
    acc = 0;
    lastTime = performance.now();
    audio?.ctx.resume();
    rafId = requestAnimationFrame(tick);
  }
}
