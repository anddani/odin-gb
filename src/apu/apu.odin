package apu

NR52 :: 0xFF26
FRAME_SQ_PERIOD :: 8192

Apu :: struct {
	regs:       [0x30]u8,
	power:      bool,
	fs_counter: int,
	fs_step:    u8,
	ch2:        Channel,
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
}

apu_step :: proc(apu: ^Apu, cycles: int) {
	if !apu.power {
		return
	}

	apu.fs_counter += cycles
	for apu.fs_counter >= FRAME_SQ_PERIOD {
		apu.fs_counter -= FRAME_SQ_PERIOD

		switch apu.fs_step {
		case 0, 4:
			clock_length(apu)
		case 2, 6:
			clock_length(apu)
			clock_sweep(apu)
		case 7:
			clock_envelope(apu)
		}

		apu.fs_step = (apu.fs_step + 1) & 7
	}
}

apu_read :: proc(apu: ^Apu, addr: u16) -> u8 {

	if addr == NR52 {
		status: u8 = 0
		return (apu.power ? 0x80 : 0) | 0x70 | status
	}

	return apu.regs[addr - 0xFF10]
}

apu_write :: proc(apu: ^Apu, addr: u16, value: u8) {
	if addr == NR52 {
		apu.power = (value & 0x80) != 0
		if !apu.power {
			for i in 0 ..< 0x16 {
				apu.regs[i] = 0
			}
		}
		return
	}

	if !apu.power && addr >= 0xFF10 && addr <= 0xFF25 {
		return
	}

	apu.regs[addr - 0xFF10] = value
}
