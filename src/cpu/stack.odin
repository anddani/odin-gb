package cpu

push16 :: proc(c: ^Cpu, value: u16) {
	c.sp -= 2
	write16(&c.bus, c.sp, value)
}

pop16 :: proc(c: ^Cpu) -> u16 {
	value := read16(&c.bus, c.sp)
	c.sp += 2
	return value
}
