const CAPACITY = 48000 * 2;
const MAX_BUFFERED = 48000 * 2 * 0.15;

class OdinGbAudio extends AudioWorkletProcessor {
  constructor() {
    super();
    this.ring = new Float32Array(CAPACITY);
    this.r = 0;
    this.w = 0;
    this.port.onmessage = (e) => this.push(e.data);
  }

  get buffered() {
    return (this.w - this.r + CAPACITY) % CAPACITY;
  }

  push(samples) {
    for (let i = 0; i < samples.length; i++) {
      this.ring[this.w] = samples[i];
      this.w = (this.w + 1) % CAPACITY;
    }
    // Emulation and audio clocks drift apart; keep latency bounded.
    const excess = this.buffered - MAX_BUFFERED;
    if (excess > 0) this.r = (this.r + excess + (excess % 2)) % CAPACITY;
  }

  process(_inputs, outputs) {
    const [left, right] = outputs[0];
    for (let i = 0; i < left.length; i++) {
      if (this.buffered >= 2) {
        left[i] = this.ring[this.r];
        right[i] = this.ring[this.r + 1];
        this.r = (this.r + 2) % CAPACITY;
      } else {
        left[i] = 0;
        right[i] = 0;
      }
    }
    return true;
  }
}

registerProcessor("odin-gb-audio", OdinGbAudio);
