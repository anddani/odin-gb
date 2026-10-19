package cpu

import "core:math/bits"

jumps :: proc(c: ^Cpu, op: u8) -> int {
	op_code := (op >> 4) & 0b11
	cycle_count := 0
	switch op_code {
	// RET
	case 0:
		c.pc = pop16(c)
		cycle_count = 16

	// RETI
	case 1:
		c.pc = pop16(c)
		c.ime = true
		cycle_count = 16

	// JP HL
	case 2:
		c.pc = get_hl(c)
		cycle_count = 4

	// LD SP,HL
	case 3:
		c.sp = get_hl(c)
		cycle_count = 8
	}
	return cycle_count
}

cond :: proc(c: ^Cpu, op: u8) -> bool {
	cc := (op >> 3) & 0b11
	switch cc {
	// NZ
	case 0:
		return !c.flags.z

	// Z
	case 1:
		return c.flags.z

	// NC
	case 2:
		return !c.flags.c

	// C
	case 3:
		return c.flags.c
	}
	return false
}

cb :: proc(c: ^Cpu) -> int {
	op := fetch8(c)
	x := (op >> 6) & 0b11
	y := (op >> 3) & 0b111
	z := op & 0b111
	value := read_reg(c, z)

	switch x {
	case 0:
		result: u8
		carry: bool
		old_c := c.flags.c
		switch y {
		// RLC
		case 0:
			result = bits.rotate_left8(value, 1)
			carry = value & 0x80 != 0
		// RRC
		case 1:
			result = bits.rotate_left8(value, 7)
			carry = value & 0x01 != 0

		// RL
		case 2:
			result = (value << 1) | u8(old_c)
			carry = value & 0x80 != 0

		// RR
		case 3:
			result = (value >> 1) | (old_c ? 0x80 : 0)
			carry = value & 0x01 != 0

		// SLA
		case 4:
			result = value << 1
			carry = value & 0x80 != 0

		// SRA
		case 5:
			result = (value >> 1) | (value & 0x80)
			carry = value & 0x01 != 0

		// SWAP
		case 6:
			result = value << 4 | value >> 4
			carry = false

		// SRL
		case 7:
			result = value >> 1
			carry = value & 0x01 != 0
		}

		write_reg(c, z, result)
		c.flags.z = result == 0
		c.flags.n = false
		c.flags.h = false
		c.flags.c = carry

	// BIT y
	case 1:
		c.flags.z = (value & (1 << y)) == 0
		c.flags.n = false
		c.flags.h = true

	// RES y
	case 2:
		write_reg(c, z, value & ~(1 << y))

	// SET y
	case 3:
		write_reg(c, z, value | (1 << y))

	}
	if z == 6 {
		return x == 1 ? 12 : 16
	}
	return 8
}

control_flow :: proc(c: ^Cpu, op: u8) -> int {
	z := op & 0b00000111
	cycle_count := 4
	bit_3 := op & 0b00001000

	switch z {
	// RET cc
	// LDH (a8),A
	// LDH A,(a8)
	// ADD SP,r8
	// LD HL,SP+r8
	case 0:

	// POP rr
	// RET
	// RETI
	// JP HL
	// LD SP,HL
	case 1:
		if bit_3 == 0 {
			set_rp2(c, op, pop16(c))
			cycle_count = 12
		} else {
			cycle_count = jumps(c, op)
		}

	// JP cc,a16
	// LDH (C),A
	// LDH A,(C)
	// LD (a16),A
	// LD A,(a16)
	case 2:
		if op & 0x20 == 0 {
			target := fetch16(c)
			if cond(c, op) {
				c.pc = target
				cycle_count = 16
			} else {
				cycle_count = 12
			}
		} else {

		}

	// JP a16
	// CB
	// DI
	// EI
	case 3:
		op_code := (op & 0b00111000) >> 3
		switch op_code {
		// JP a16
		case 0:
			c.pc = fetch16(c)
			cycle_count = 16

		// CB
		case 1:
			cycle_count = cb(c)

		// DI
		case 6:

		// EI
		case 7:
		}

	// CALL cc,a16
	case 4:
		target := fetch16(c)
		if cond(c, op) {
			push16(c, c.pc)
			c.pc = target
			cycle_count = 24
		} else {
			cycle_count = 12
		}


	// PUSH RR
	// CALL a16
	case 5:
		if bit_3 == 0 {
			push16(c, get_rp2(c, op))
			cycle_count = 16
		} else {
			target := fetch16(c)
			push16(c, c.pc)
			c.pc = target
			cycle_count = 24
		}

	// immediate ALU
	case 6:
		op_code := (op & 0b00111000) >> 3
		v := fetch8(c)
		alu_apply(c, op_code, v)
		cycle_count = 8

	// RST
	case 7:
		push16(c, c.pc)
		c.pc = u16(op & 0x38)
		cycle_count = 16
	}
	return cycle_count
}
