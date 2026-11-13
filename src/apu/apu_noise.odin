package apu

NOISE_DIVISORS := [8]int{8, 16, 32, 48, 64, 80, 96, 112}

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

noise_output :: proc(ch: ^Channel) -> u8 {
	if !ch.enabled {
		return 0
	}
	bit := ~ch.lfsr & 1
	return u8(bit) * ch.volume
}

noise_trigger :: proc(ch: ^Channel) {
	ch.enabled = ch.dac_on
	if ch.length == 0 {
		ch.length = 64
	}
	ch.freq_timer = ch.noise_divisor << uint(ch.noise_shift)
	ch.lfsr = 0x7FFF
	ch.volume = ch.env_initial
	ch.env_timer = int(ch.env_period)
}
