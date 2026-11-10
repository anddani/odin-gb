package joypad

Joypad :: struct {
	select: u8,
	dirs:   u8,
	btns:   u8,
}

joypad_read :: proc(jp: ^Joypad) -> u8 {
	lower: u8 = 0x0F
	if jp.select & 0x10 == 0 {
		lower &= ~jp.dirs
	}
	if jp.select & 0x20 == 0 {
		lower &= ~jp.btns
	}
	return 0xC0 | (jp.select & 0x30) | lower
}
