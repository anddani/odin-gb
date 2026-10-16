package cpu

read8 :: proc(b: ^Bus, addr: u16) -> u8 {
	return b.read(b.ctx, addr)
}

write8 :: proc(b: ^Bus, addr: u16, value: u8) {
	b.write(b.ctx, addr, value)
}

read16 :: proc(b: ^Bus, addr: u16) -> u16 {
	lo := u16(b.read(b.ctx, addr))
	hi := u16(b.read(b.ctx, addr + 1))
	return (hi << 8) | lo
}

write16 :: proc(b: ^Bus, addr: u16, value: u16) {
	lo := u8(value & 0xFF)
	hi := u8(value >> 8)
	b.write(b.ctx, addr, lo)
	b.write(b.ctx, addr + 1, hi)
}

fetch8 :: proc(c: ^Cpu) -> u8 {
	value := c.bus.read(c.bus.ctx, c.pc)
	c.pc += 1
	return value
}

fetch16 :: proc(c: ^Cpu) -> u16 {
	lo := u16(fetch8(c))
	hi := u16(fetch8(c))
	return (hi << 8) | lo
}
