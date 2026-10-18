package cpu

ld :: proc(c: ^Cpu, op: u8) -> int {

	// Special handling for HALT operation
	if op == 0x76 {
		c.halt = true
		return 4
	}

	dst := (op & 0b00111000) >> 3
	src := (op & 0b00000111)
	cycle_count := dst == 6 || src == 6 ? 8 : 4

	write_reg(c, dst, read_reg(c, src))

	return cycle_count
}
