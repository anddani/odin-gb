package mmu

import "core:testing"

import "../cart"

@(test)
test_mmu_wram_banks :: proc(t: ^testing.T) {
	m: Mmu
	mmu_write(&m, 0xC000, 0x11)
	mmu_write(&m, 0xD000, 0x22)
	testing.expect_value(t, mmu_read(&m, 0xC000), u8(0x11))
	testing.expect_value(t, mmu_read(&m, 0xD000), u8(0x22))
	testing.expect_value(t, m.wram[0][0], u8(0x11)) // distinct banks
	testing.expect_value(t, m.wram[1][0], u8(0x22))
}

// Echo RAM mirrors WRAM both ways.
@(test)
test_mmu_echo_mirror :: proc(t: ^testing.T) {
	m: Mmu
	mmu_write(&m, 0xC005, 0xAB)
	testing.expect_value(t, mmu_read(&m, 0xE005), u8(0xAB)) // echo reads WRAM
	mmu_write(&m, 0xE100, 0xCD) // echo write -> WRAM
	testing.expect_value(t, mmu_read(&m, 0xC100), u8(0xCD))
}

@(test)
test_mmu_vram_oam :: proc(t: ^testing.T) {
	m: Mmu
	mmu_write(&m, 0x8000, 0x3C)
	mmu_write(&m, 0x9FFF, 0x7E) // top of VRAM
	testing.expect_value(t, mmu_read(&m, 0x8000), u8(0x3C))
	testing.expect_value(t, mmu_read(&m, 0x9FFF), u8(0x7E))

	mmu_write(&m, 0xFE00, 0x5A)
	mmu_write(&m, 0xFE9F, 0xA5) // top of OAM
	testing.expect_value(t, mmu_read(&m, 0xFE00), u8(0x5A))
	testing.expect_value(t, mmu_read(&m, 0xFE9F), u8(0xA5))
}

// The FF80/FFFE/FFFF boundary: HRAM must not swallow IE.
@(test)
test_mmu_hram_ie_boundary :: proc(t: ^testing.T) {
	m: Mmu
	mmu_write(&m, 0xFF80, 0x11)
	mmu_write(&m, 0xFFFE, 0x22) // top of HRAM
	mmu_write(&m, 0xFFFF, 0x1F) // IE, distinct
	testing.expect_value(t, mmu_read(&m, 0xFF80), u8(0x11))
	testing.expect_value(t, mmu_read(&m, 0xFFFE), u8(0x22))
	testing.expect_value(t, mmu_read(&m, 0xFFFF), u8(0x1F))
	testing.expect_value(t, m.ie, u8(0x1F)) // IE got its own byte
	testing.expect_value(t, m.hram[0x7E], u8(0x22)) // 0xFFFE is last HRAM byte
}

@(test)
test_mmu_io :: proc(t: ^testing.T) {
	m: Mmu
	mmu_write(&m, 0xFF0F, 0x05) // IF register
	testing.expect_value(t, mmu_read(&m, 0xFF0F), u8(0x05))
	testing.expect_value(t, m.io[0x0F], u8(0x05))
}

@(test)
test_mmu_prohibited :: proc(t: ^testing.T) {
	m: Mmu
	testing.expect_value(t, mmu_read(&m, 0xFEA0), u8(0xFF)) // reads 0xFF
	mmu_write(&m, 0xFEA0, 0x12) // ignored, no crash
	testing.expect_value(t, mmu_read(&m, 0xFEA0), u8(0xFF))
}

@(test)
test_mmu_rom_via_cart :: proc(t: ^testing.T) {
	data := make([]byte, 0x8000)
	defer delete(data)
	data[0x0100] = 0xC3
	c, err := cart.cart_from_bytes(data)
	defer cart.cart_destroy(&c)
	testing.expect_value(t, err, cart.Cart_Error.None)

	m: Mmu
	m.cart = &c
	testing.expect_value(t, mmu_read(&m, 0x0100), u8(0xC3))
	mmu_write(&m, 0x0100, 0x00) // ROM is read-only -> ignored
	testing.expect_value(t, mmu_read(&m, 0x0100), u8(0xC3))
}
