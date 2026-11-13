package apu

NR10 :: 0xFF10
NR11 :: 0xFF11 // bit 7-6 duty, bit 5-0 length load
NR12 :: 0xFF12 // bit 7-4 init volume, bit 3 env direction, bit 2-0 env period
NR13 :: 0xFF13 // frequency low 8 bits
NR14 :: 0xFF14 // bit 7 trigger, bit 6 length enable, bit 2-0 frequency high 3 bits
NR21 :: 0xFF16 // bit 7-6 duty, bit 5-0 length load
NR22 :: 0xFF17 // bit 7-4 init volume, bit 3 env direction, bit 2-0 env period
NR23 :: 0xFF18 // frequency low 8 bits
NR24 :: 0xFF19 // bit 7 trigger, bit 6 length enable, bit 2-0 frequency high 3 bits
NR30 :: 0xFF1A
NR31 :: 0xFF1B
NR32 :: 0xFF1C
NR33 :: 0xFF1D
NR34 :: 0xFF1E
NR41 :: 0xFF20
NR42 :: 0xFF21
NR43 :: 0xFF22
NR44 :: 0xFF23
NR52 :: 0xFF26
FRAME_SQ_PERIOD :: 8192
CYCLES_PER_SAMPLE :: 87
SAMPLE_BUF_SIZE :: 8192

Apu :: struct {
	regs:           [0x30]u8,
	ch1:            Channel,
	ch2:            Channel,
	ch3:            Channel,
	power:          bool,
	fs_counter:     int,
	fs_step:        u8,
	sample_counter: int,
	samples:        [SAMPLE_BUF_SIZE]i16,
	sample_w:       int,
	sample_r:       int,
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

	apu.sample_counter += cycles
	for apu.sample_counter >= CYCLES_PER_SAMPLE {
		apu.sample_counter -= CYCLES_PER_SAMPLE
		mix := int(square_output(&apu.ch1)) + int(square_output(&apu.ch2)) + int(wave_output(apu))
		s := i16((mix - 22) * 700)
		apu.samples[apu.sample_w] = s
		apu.sample_w = (apu.sample_w + 1) % SAMPLE_BUF_SIZE
	}

	square_step(&apu.ch1, cycles)
	square_step(&apu.ch2, cycles)
	wave_step(&apu.ch3, cycles)
}

apu_drain :: proc(apu: ^Apu, out: []i16) -> int {
	n := 0
	for apu.sample_r != apu.sample_w && n < len(out) {
		out[n] = apu.samples[apu.sample_r]
		apu.sample_r = (apu.sample_r + 1) % SAMPLE_BUF_SIZE
		n += 1
	}
	return n
}

apu_read :: proc(apu: ^Apu, addr: u16) -> u8 {
	if addr == NR52 {
		status: u8 = 0
		return (apu.power ? 0x80 : 0) | 0x70 | status
	}

	return apu.regs[addr - 0xFF10]
}


apu_write :: proc(apu: ^Apu, addr: u16, value: u8) {
	ch1 := &apu.ch1
	ch2 := &apu.ch2
	ch3 := &apu.ch3
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
	case NR10:
		ch1.sweep_period = int((value >> 4) & 0x07)
		ch1.sweep_down = value & 0x08 != 0
		ch1.sweep_shift = int(value & 0x07)

	case NR11:
		ch1.duty = value >> 6
		ch1.length = 64 - int(value & 0x3F)

	case NR12:
		ch1.env_period = value & 0x07
		ch1.env_add = value & 0x08 != 0
		ch1.env_initial = value >> 4
		ch1.dac_on = value & 0xF8 != 0
		if !ch1.dac_on {
			ch1.enabled = false
		}

	case NR13:
		ch1.freq = int(value) | (int(apu.regs[NR14 - 0xFF10] & 0x07) << 8)

	case NR14:
		ch1.length_enable = value & 0x40 != 0
		ch1.freq = int(apu.regs[NR13 - 0xFF10]) | (int(value & 0x07) << 8)
		if value & 0x80 != 0 {
			square_trigger(&apu.ch1)
		}

	case NR21:
		ch2.duty = value >> 6
		ch2.length = 64 - int(value & 0x3F)

	case NR22:
		ch2.env_period = value & 0x07
		ch2.env_add = value & 0x08 != 0
		ch2.env_initial = value >> 4
		ch2.dac_on = value & 0xF8 != 0
		if !ch2.dac_on {
			ch2.enabled = false
		}

	case NR23:
		ch2.freq = int(value) | (int(apu.regs[NR24 - 0xFF10] & 0x07) << 8)

	case NR24:
		ch2.length_enable = value & 0x40 != 0
		ch2.freq = int(apu.regs[NR23 - 0xFF10]) | (int(value & 0x07) << 8)
		if value & 0x80 != 0 {
			square_trigger(&apu.ch2)
		}

	case NR30:
		ch3.dac_on = value & 0x80 != 0
		if !ch3.dac_on {
			ch3.enabled = false
		}

	case NR31:
		ch3.length = 256 - int(value)

	case NR32:
		ch3.wave_shift = (value >> 5) & 3

	case NR33:
		ch3.freq = int(value) | (int(apu.regs[NR34 - 0xFF10] & 7) << 8)

	case NR34:
		ch3.length_enable = value & 0x40 != 0
		ch3.freq = int(apu.regs[NR33 - 0xFF10]) | (int(value & 7) << 8)
		if value & 0x80 != 0 {
			wave_trigger(apu)
		}
	}
}
