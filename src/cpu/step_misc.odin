package cpu

misc :: proc(c: ^Cpu, op: u8) -> int {
	dst := (op & 0b00111000) >> 3
	z := op & 0b00000111
	cycle_count := 4

	switch z {
	// NOP
	case 0:

	// LD rr,d16
	// ADD HL,rr
	case 1:
		if op & 0b00001000 == 0 {
			// LD rr,d16
			value := fetch16(c)
			set_rp(c, op, value)
			cycle_count = 12
		} else {
			// ADD HL,rr
			hl := get_hl(c)
			rr := get_rp(c, op)
			full := u32(hl) + u32(rr)
			set_hl(c, u16(full))
			c.flags.n = false
			c.flags.h = (hl & 0x0FFF) + (rr & 0x0FFF) > 0x0FFF
			c.flags.c = full > 0xFFFF
			cycle_count = 8
		}

	case 2:

	// INC rr
	// DEC rr
	case 3:
		if op & 0b00001000 == 0 {
			// INC rr
			set_rp(c, op, get_rp(c, op) + 1)
		} else {
			// DEC rr
			set_rp(c, op, get_rp(c, op) - 1)
		}
		cycle_count = 8

	// INC r
	case 4:
		old := read_reg(c, dst)
		result := old + 1

		write_reg(c, dst, result)
		c.flags.z = result == 0
		c.flags.n = false
		c.flags.h = (old & 0xF) == 0xF
		cycle_count = Reg(dst) == ._HL ? 12 : 4


	// DEC r
	case 5:
		old := read_reg(c, dst)
		result := old - 1

		write_reg(c, dst, result)
		c.flags.z = result == 0
		c.flags.n = true
		c.flags.h = (old & 0xF) == 0
		cycle_count = Reg(dst) == ._HL ? 12 : 4

	// LD r,d8
	case 6:
		value := fetch8(c)
		write_reg(c, dst, value)

	case 7:
	}

	return cycle_count
}
