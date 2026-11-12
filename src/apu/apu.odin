package apu

NR52 :: 0xFF26

Apu :: struct {
	regs:  [0x30]u8,
	power: bool,
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
