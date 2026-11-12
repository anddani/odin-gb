package apu

ch2_output :: proc(ch: ^Channel) -> u8 {
	if !ch.enabled {
		return 0
	}
	bit := DUTY_TABLE[ch.duty][ch.duty_pos]
	return bit * ch.volume
}

ch2_step :: proc(ch: ^Channel, cycles: int) {
	ch.freq_timer -= cycles
	for ch.freq_timer <= 0 {
		ch.freq_timer += (2048 - ch.freq) * 4
		ch.duty_pos = (ch.duty_pos + 1) & 7
	}
}

square_trigger :: proc(ch: ^Channel) {
	ch.enabled = ch.dac_on

	if ch.length == 0 {
		ch.length = 64
	}

	ch.freq_timer = (2048 - ch.freq) * 4

	// nr22 := apu.regs[NR22 - 0xFF10]
	ch.volume = ch.env_initial
	ch.env_timer = int(ch.env_period)
}
