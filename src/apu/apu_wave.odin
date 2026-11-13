package apu

wave_trigger :: proc(apu: ^Apu) {
	ch := &apu.ch3
	ch.enabled = ch.dac_on
	if ch.length == 0 {
		ch.length = 256
	}
	ch.freq_timer = (2048 - ch.freq) * 2
	ch.wave_pos = 0
}

wave_step :: proc(ch: ^Channel, cycles: int) {
	ch.freq_timer -= cycles
	for ch.freq_timer <= 0 {
		ch.freq_timer += (2048 - ch.freq) * 2
		ch.wave_pos = (ch.wave_pos + 1) & 31
	}
}

wave_output :: proc(apu: ^Apu) -> u8 {
	ch := &apu.ch3
	if !ch.enabled || !ch.dac_on {
		return 0
	}
	b := apu.regs[0x20 + int(ch.wave_pos) / 2]
	sample := (ch.wave_pos & 1 == 0) ? (b >> 4) : (b & 0x0F)
	switch ch.wave_shift {
	case 0:
		return 0
	case 1:
		return sample
	case 2:
		return sample >> 1
	case 3:
		return sample >> 2
	}
	return 0
}
