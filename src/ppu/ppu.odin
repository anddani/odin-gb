package ppu

Ppu :: struct {
	lcdc: u8, // FF40
	stat: u8, // FF41
	scy:  u8, // FF42
	scx:  u8, // FF43
	ly:   u8, // FF44
	lyc:  u8, // FF45
	bgp:  u8, // FF47
	wy:   u8, // FF4A
	wx:   u8, // FF4B
}
