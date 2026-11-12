package apu

DUTY_TABLE := [4][8]u8 {
	{0, 0, 0, 0, 0, 0, 0, 1}, // 12.5%
	{1, 0, 0, 0, 0, 0, 0, 1}, // 25%
	{1, 0, 0, 0, 0, 1, 1, 1}, // 50%
	{0, 1, 1, 1, 1, 1, 1, 0}, // 75%
}

Channel :: struct {
	enabled:       bool,
	freq_timer:    int,
	duty:          u8,
	duty_pos:      u8,
	length:        int,
	length_enable: bool,
	volume:        u8,
	env_timer:     int,
	env_period:    u8,
	env_add:       bool,
	freq:          int,
	env_initial:   u8,
	dac_on:        bool,
}

square_output :: proc(ch: ^Channel) -> u8 {
	if !ch.enabled {
		return 0
	}
	bit := DUTY_TABLE[ch.duty][ch.duty_pos]
	return bit * ch.volume
}

square_step :: proc(ch: ^Channel, cycles: int) {
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
