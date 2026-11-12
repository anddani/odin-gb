package apu

NR21 :: 0xFF16 // bit 7-6 duty, bit 5-0 length load
NR22 :: 0xFF17 // bit 7-4 init volume, bit 3 env direction, bit 2-0 env period
NR23 :: 0xFF18 // frequency low 8 bits
NR24 :: 0xFF19 // bit 7 trigger, bit 6 length enable, bit 2-0 frequency high 3 bits
NR52 :: 0xFF26
FRAME_SQ_PERIOD :: 8192

DUTY_TABLE := [4][8]u8 {
	{0, 0, 0, 0, 0, 0, 0, 1}, // 12.5%
	{1, 0, 0, 0, 0, 0, 0, 1}, // 25%
	{1, 0, 0, 0, 0, 1, 1, 1}, // 50%
	{0, 1, 1, 1, 1, 1, 1, 0}, // 75%
}

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

	ch2_step(apu, cycles)
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
	switch addr {
	case NR21:
		apu.ch2.duty = value >> 6
		apu.ch2.length = 64 - int(value & 0x3F)

	case NR22:
		apu.ch2.env_period = value & 0x07
		apu.ch2.env_add = value & 0x08 != 0
		apu.ch2.volume = value >> 4

	case NR23:

	case NR24:
		apu.ch2.length_enable = value & 0x40 != 0
		if value & 0x80 != 0 {
			ch2_trigger(apu)
		}
	}
}
