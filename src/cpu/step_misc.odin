package cpu

import "core:math/bits"

// Returns the address and applies HL++/HL-- side effect
addr_rr :: proc(c: ^Cpu, op: u8) -> u16 {
	addr: u16
	idx := (op >> 4) & 0b11

	switch idx {
	case 0:
		addr = get_bc(c)
	case 1:
		addr = get_de(c)
	case 2:
		addr = get_hl(c)
		set_hl(c, addr + 1)
	case 3:
		addr = get_hl(c)
		set_hl(c, addr - 1)
	}
	return addr
}

misc :: proc(c: ^Cpu, op: u8) -> int {
	dst := (op & 0b00111000) >> 3
	z := op & 0b00000111
	cycle_count := 4
	bit_3 := op & 0b00001000

	switch z {
	// NOP
	case 0:

	// LD rr,d16
	// ADD HL,rr
	case 1:
		if bit_3 == 0 {
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

	// LD (rr),A store
	// LD A,(rr) read
	case 2:
		if bit_3 == 0 {
			// LD (rr),A store
			addr := addr_rr(c, op)
			write8(&c.bus, addr, c.regs[.A])
		} else {
			// LD A,(rr) read
			addr := addr_rr(c, op)
			c.regs[.A] = read8(&c.bus, addr)
		}
		cycle_count = 8


	// INC rr
	// DEC rr
	case 3:
		if bit_3 == 0 {
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
		acc := c.regs[.A]
		switch dst {
		// RLCA
		case 0:
			c.flags.z = false
			c.flags.n = false
			c.flags.h = false
			c.flags.c = acc & 0x80 > 0
			c.regs[.A] = bits.rotate_left8(acc, 1)

		// RRCA
		case 1:
			c.flags.z = false
			c.flags.n = false
			c.flags.h = false
			c.flags.c = acc & 0x01 > 0
			c.regs[.A] = bits.rotate_left8(acc, 7)

		// RLA
		case 2:
			old_c := c.flags.c
			c.flags.c = acc & 0x80 > 0
			c.flags.z = false
			c.flags.n = false
			c.flags.h = false
			c.regs[.A] = (acc << 1) | u8(old_c)

		// RRA
		case 3:
			old_c := c.flags.c
			c.flags.c = acc & 0x01 > 0
			c.flags.z = false
			c.flags.n = false
			c.flags.h = false
			c.regs[.A] = (acc >> 1) | (old_c ? 0x80 : 0x00)

		// DAA
		case 4:
			if c.flags.n {
				if c.flags.c {
					c.regs[.A] -= 0x60
				}
				if c.flags.h {
					c.regs[.A] -= 0x06
				}
			} else {
				if c.flags.c || c.regs[.A] > 0x99 {
					c.regs[.A] += 0x60
					c.flags.c = true
				}
				if c.flags.h || (c.regs[.A] & 0x0F) > 0x09 {
					c.regs[.A] += 0x06
				}
			}
			c.flags.z = c.regs[.A] == 0
			c.flags.h = false

		// CPL
		case 5:
			c.flags.n = true
			c.flags.h = true
			c.regs[.A] = ~c.regs[.A]

		// SCF
		case 6:
			c.flags.c = true
			c.flags.n = false
			c.flags.h = false

		// CCF
		case 7:
			c.flags.c = !c.flags.c
			c.flags.n = false
			c.flags.h = false
		}

	}

	return cycle_count
}
