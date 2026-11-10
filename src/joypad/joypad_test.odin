package joypad

import "core:testing"

// Pressed buttons read as 0; unused high bits read 1; select bits echo back.

@(test)
test_joypad_directions_selected :: proc(t: ^testing.T) {
	jp: Joypad
	jp.dirs = 0b0101 // Right (bit0) + Up (bit2) pressed
	joypad_write(&jp, 0x20) // bit4 low -> directions selected
	// lower = 0x0F & ~0b0101 = 0b1010; return 0xC0 | 0x20 | 0x0A
	testing.expect_value(t, joypad_read(&jp), u8(0xEA))
}

@(test)
test_joypad_buttons_selected_ignores_dirs :: proc(t: ^testing.T) {
	jp: Joypad
	jp.btns = 0b1000 // Start pressed
	jp.dirs = 0b1111 // all directions "pressed" -- must be ignored
	joypad_write(&jp, 0x10) // bit5 low -> buttons selected
	// lower = 0x0F & ~0b1000 = 0b0111; return 0xC0 | 0x10 | 0x07
	testing.expect_value(t, joypad_read(&jp), u8(0xD7))
}

@(test)
test_joypad_nothing_pressed :: proc(t: ^testing.T) {
	jp: Joypad
	joypad_write(&jp, 0x20)
	testing.expect(t, joypad_read(&jp) & 0x0F == 0x0F, "no input -> low nibble all 1 (released)")
}
