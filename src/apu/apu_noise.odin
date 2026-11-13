package apu

noise_step :: proc(ch: ^Channel, cycles: int) {
	ch.freq_timer -= cycles
	for ch.freq_timer <= 0 {
		ch.freq_timer += ch.noise_divisor << uint(ch.noise_shift)
		xor := (ch.lfsr ~ (ch.lfsr >> 1)) & 1
		ch.lfsr >>= 1
		ch.lfsr |= xor << 14
		if ch.noise_width {
			ch.lfsr = (ch.lfsr & ~u16(0x40)) | (xor << 6)
		}
	}
}
