package cpu

alu_apply :: proc(c: ^Cpu, op_code: u8, v: u8) {
	cy := u8(c.flags.c)
	acc := c.regs[.A]
	result: u8
	switch op_code {
	// ADD A,r
	case 0:
		result = acc + v
		c.flags.n = false
		c.flags.h = (acc & 0xF) + (v & 0xF) > 0xF
		c.flags.c = int(acc) + int(v) > 0xFF

	// ADC A,r
	case 1:
		result = acc + v + cy
		c.flags.n = false
		c.flags.h = (acc & 0xF) + (v & 0xF) + cy > 0xF
		c.flags.c = int(acc) + int(v) + int(cy) > 0xFF

	// 2. SUB A,r
	// 7. CP A,r
	//   Same as SUB but does not store the result, only sets flags
	case 2, 7:
		result = acc - v
		c.flags.n = true
		c.flags.h = (acc & 0xF) < (v & 0xF)
		c.flags.c = acc < v

	// SBC A,r
	case 3:
		result = acc - v - cy
		c.flags.n = true
		c.flags.h = (acc & 0xF) < (v & 0xF) + cy
		c.flags.c = int(acc) < int(v) + int(cy)

	// AND A,r
	case 4:
		result = acc & v
		c.flags.n = false
		c.flags.h = true
		c.flags.c = false

	// XOR A,r
	case 5:
		result = acc ~ v
		c.flags.n = false
		c.flags.h = false
		c.flags.c = false

	// OR A,r
	case 6:
		result = acc | v
		c.flags.n = false
		c.flags.h = false
		c.flags.c = false
	}

	c.flags.z = result == 0

	// CP A,r should not store the result, only set flags
	if op_code != 7 {
		c.regs[.A] = result
	}
}

alu :: proc(c: ^Cpu, op: u8) -> int {
	op_code := (op & 0b00111000) >> 3
	src := (op & 0b00000111)
	v := read_reg(c, src)

	alu_apply(c, op_code, v)

	// When src is 6 (HL register), cycle count is 8
	return src == 6 ? 8 : 4
}
