package apu

ch2_output :: proc(apu: ^Apu) -> u8 {
	ch := &apu.ch2
	if !ch.enabled {
		return 0
	}
	bit := DUTY_TABLE[ch.duty][ch.duty_pos]
	return bit * ch.volume
}

ch2_step :: proc(apu: ^Apu, cycles: int) {
	ch := &apu.ch2
	ch.freq_timer -= cycles
	for ch.freq_timer <= 0 {
		freq := int(apu.regs[NR23 - 0xFF10]) | (int(apu.regs[NR24 - 0xFF10] & 0x07) << 8)
		ch.freq_timer += (2048 - freq) * 4
		ch.duty_pos = (ch.duty_pos + 1) & 7
	}
}

ch2_trigger :: proc(apu: ^Apu) {
	ch := &apu.ch2
	ch.enabled = true

	if ch.length == 0 {
		ch.length = 64
	}

	freq := int(apu.regs[NR23 - 0xFF10]) | (int(apu.regs[NR24 - 0xFF10] & 0x07) << 8)
	ch.freq_timer = (2048 - freq) * 4

	nr22 := apu.regs[NR22 - 0xFF10]
	ch.volume = nr22 >> 4
	ch.env_period = nr22 & 0x07
	ch.env_add = nr22 & 0x08 != 0
	ch.env_timer = int(ch.env_period)

	if nr22 & 0xF8 == 0 {
		ch.enabled = false
	}
}
