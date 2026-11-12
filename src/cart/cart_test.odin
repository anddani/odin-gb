package cart

import "core:mem"
import "core:os"
import "core:slice"
import "core:testing"

// A slice shorter than one 32 KB ROM bank must be rejected and must not
// allocate anything.
@(test)
test_too_small :: proc(t: ^testing.T) {
	data := make([]byte, 0x1000) // 4 KB, well under MIN_ROM_SIZE
	defer delete(data)

	c, err := cart_from_bytes(data)
	testing.expect_value(t, err, Cart_Error.Too_Small)
	testing.expect(t, c.rom == nil, "Too_Small must not allocate a rom")
}

// The boundary: exactly MIN_ROM_SIZE is the smallest legal cart and must pass;
// one byte short must fail.
@(test)
test_min_size_boundary :: proc(t: ^testing.T) {
	short := make([]byte, MIN_ROM_SIZE - 1)
	defer delete(short)
	_, err_short := cart_from_bytes(short)
	testing.expect_value(t, err_short, Cart_Error.Too_Small)

	exact := make([]byte, MIN_ROM_SIZE)
	defer delete(exact)
	c, err_exact := cart_from_bytes(exact)
	defer cart_destroy(&c)
	testing.expect_value(t, err_exact, Cart_Error.None)
	testing.expect_value(t, len(c.rom), MIN_ROM_SIZE)
}

// A valid cart must hold a byte-for-byte copy of the source data, in its own
// allocation (not an alias of the caller's slice).
@(test)
test_valid_is_a_copy :: proc(t: ^testing.T) {
	data := make([]byte, MIN_ROM_SIZE)
	defer delete(data)
	data[0] = 0xAB
	data[MIN_ROM_SIZE - 1] = 0xCD

	c, err := cart_from_bytes(data)
	defer cart_destroy(&c)

	testing.expect_value(t, err, Cart_Error.None)
	testing.expect(t, slice.equal(c.rom, data), "rom must equal source bytes")
	testing.expect(t, &c.rom[0] != &data[0], "rom must be a copy, not an alias")
}

// Because it is a copy, mutating the source after construction must not change
// the cart's rom.
@(test)
test_copy_is_independent :: proc(t: ^testing.T) {
	data := make([]byte, MIN_ROM_SIZE)
	defer delete(data)
	data[0] = 0x11

	c, err := cart_from_bytes(data)
	defer cart_destroy(&c)
	testing.expect_value(t, err, Cart_Error.None)

	data[0] = 0x22 // mutate the source after the clone
	testing.expect_value(t, c.rom[0], u8(0x11))
}

// A path that cannot be read yields File_Unreadable and allocates nothing.
@(test)
test_file_unreadable :: proc(t: ^testing.T) {
	c, err := cart_from_file("/nonexistent/rom.gb")
	testing.expect_value(t, err, Cart_Error.File_Unreadable)
	testing.expect(t, c.rom == nil, "a failed load must not allocate")
}

// Allocate a cart, destroy it, and assert the tracking allocator sees no
// outstanding allocations. This proves cart_destroy frees the owned rom.
@(test)
test_no_leak_on_destroy :: proc(t: ^testing.T) {
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	defer mem.tracking_allocator_destroy(&track)

	leaked: int
	{
		context.allocator = mem.tracking_allocator(&track)

		data := make([]byte, MIN_ROM_SIZE)
		c, err := cart_from_bytes(data)
		delete(data)
		cart_destroy(&c)
		_ = err

		leaked = len(track.allocation_map)
	}

	testing.expectf(t, leaked == 0, "expected 0 live allocations, found %d", leaked)
}

// --- header parsing (M3) ---

@(test)
test_parse_mbc1_battery_and_ram :: proc(t: ^testing.T) {
	data := make([]byte, 0x8000)
	defer delete(data)
	data[0x0147] = 0x03 // MBC1 + RAM + BATTERY
	data[0x0149] = 0x03 // 32 KB external RAM
	c, err := cart_from_bytes(data)
	defer cart_destroy(&c)

	testing.expect_value(t, err, Cart_Error.None)
	testing.expect_value(t, c.mbc, Mbc.MBC1)
	testing.expect(t, c.battery, "battery flag set")
	testing.expect_value(t, len(c.ram), 32 * 1024)
	testing.expect_value(t, c.rom_bank, 1)
}

@(test)
test_parse_rom_only_no_ram :: proc(t: ^testing.T) {
	data := make([]byte, 0x8000)
	defer delete(data)
	data[0x0147] = 0x00 // ROM only
	c, _ := cart_from_bytes(data)
	defer cart_destroy(&c)

	testing.expect_value(t, c.mbc, Mbc.None)
	testing.expect(t, !c.battery, "no battery")
	testing.expect(t, c.ram == nil, "no external RAM allocated")
}

// Allocating external RAM must not leak on destroy.
@(test)
test_no_leak_with_ram :: proc(t: ^testing.T) {
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	defer mem.tracking_allocator_destroy(&track)

	leaked: int
	{
		context.allocator = mem.tracking_allocator(&track)
		data := make([]byte, 0x8000)
		data[0x0149] = 0x02 // 8 KB RAM
		c, _ := cart_from_bytes(data)
		delete(data)
		cart_destroy(&c)
		leaked = len(track.allocation_map)
	}
	testing.expectf(t, leaked == 0, "leaked %d allocations", leaked)
}

// --- MBC1 banking ---

@(test)
test_mbc1_rom_banking :: proc(t: ^testing.T) {
	// 4 banks (64 KB). Stamp each bank's first byte with its bank number.
	data := make([]byte, 4 * 0x4000)
	defer delete(data)
	data[0x0147] = 0x01 // MBC1
	for b in 0 ..< 4 {data[b * 0x4000] = u8(b)}
	c, _ := cart_from_bytes(data)
	defer cart_destroy(&c)

	// bank 0 fixed at 0x0000
	testing.expect_value(t, cart_read(&c, 0x0000), u8(0))
	// default switchable bank is 1
	testing.expect_value(t, cart_read(&c, 0x4000), u8(1))
	// select bank 2
	cart_write(&c, 0x2000, 0x02)
	testing.expect_value(t, cart_read(&c, 0x4000), u8(2))
	// select bank 3
	cart_write(&c, 0x2000, 0x03)
	testing.expect_value(t, cart_read(&c, 0x4000), u8(3))
}

// Writing bank 0 to the 0x2000 register selects bank 1 (the 0->1 quirk).
@(test)
test_mbc1_bank0_quirk :: proc(t: ^testing.T) {
	data := make([]byte, 4 * 0x4000)
	defer delete(data)
	data[0x0147] = 0x01
	data[0x4000] = 0xAA // bank 1 marker
	c, _ := cart_from_bytes(data)
	defer cart_destroy(&c)
	cart_write(&c, 0x2000, 0x00) // request bank 0
	testing.expect_value(t, cart_read(&c, 0x4000), u8(0xAA)) // got bank 1
}

// External RAM: disabled -> 0xFF; enabled -> read/write round-trips.
@(test)
test_mbc1_ram :: proc(t: ^testing.T) {
	data := make([]byte, 0x8000)
	defer delete(data)
	data[0x0147] = 0x03 // MBC1+RAM+battery
	data[0x0149] = 0x02 // 8 KB
	c, _ := cart_from_bytes(data)
	defer cart_destroy(&c)

	cart_write(&c, 0xA000, 0x42) // RAM disabled by default -> dropped
	testing.expect_value(t, cart_read(&c, 0xA000), u8(0xFF))

	cart_write(&c, 0x0000, 0x0A) // enable RAM
	cart_write(&c, 0xA000, 0x42)
	testing.expect_value(t, cart_read(&c, 0xA000), u8(0x42))
}

// --- battery save round-trip ---

@(test)
test_battery_save_roundtrip :: proc(t: ^testing.T) {
	// Build a minimal MBC1+RAM+battery ROM on disk.
	rom := make([]byte, 0x8000)
	defer delete(rom)
	rom[0x0147] = 0x03 // MBC1+RAM+BATTERY
	rom[0x0149] = 0x02 // 8 KB RAM
	tmp_rom := "/tmp/odin-gb-savetest.gb"
	tmp_sav := "/tmp/odin-gb-savetest.sav"
	_ = os.write_entire_file(tmp_rom, rom)
	defer os.remove(tmp_rom)
	defer os.remove(tmp_sav)
	os.remove(tmp_sav) // ensure clean start

	// Session 1: load, write to RAM, save.
	{
		c, err := cart_from_file(tmp_rom)
		defer cart_destroy(&c)
		testing.expect_value(t, err, Cart_Error.None)
		cart_write(&c, 0x0000, 0x0A) // enable RAM
		cart_write(&c, 0xA000, 0x42)
		cart_write(&c, 0xA123, 0x99)
		cart_save_ram(&c)
	}

	// Session 2: reopen -- RAM must be restored from the .sav.
	{
		c, err := cart_from_file(tmp_rom)
		defer cart_destroy(&c)
		testing.expect_value(t, err, Cart_Error.None)
		cart_write(&c, 0x0000, 0x0A) // enable RAM to read it back
		testing.expect_value(t, cart_read(&c, 0xA000), u8(0x42))
		testing.expect_value(t, cart_read(&c, 0xA123), u8(0x99))
	}
}

// A non-battery cart must not write a .sav.
@(test)
test_no_save_without_battery :: proc(t: ^testing.T) {
	rom := make([]byte, 0x8000)
	defer delete(rom)
	rom[0x0147] = 0x01 // MBC1, NO battery
	rom[0x0149] = 0x02
	tmp_rom := "/tmp/odin-gb-nobat.gb"
	tmp_sav := "/tmp/odin-gb-nobat.sav"
	_ = os.write_entire_file(tmp_rom, rom)
	defer os.remove(tmp_rom)
	os.remove(tmp_sav)

	c, _ := cart_from_file(tmp_rom)
	defer cart_destroy(&c)
	cart_save_ram(&c)

	sav_data, read_err := os.read_entire_file(tmp_sav, context.allocator)
	defer delete(sav_data)
	testing.expect(t, read_err != nil, "non-battery cart must not create a .sav")
}

// --- MBC3 ---

@(test)
test_mbc3_7bit_rom_banking :: proc(t: ^testing.T) {
	// 128 banks (2 MB). Mark bank N's first byte with N (low 8 bits).
	data := make([]byte, 128 * 0x4000)
	defer delete(data)
	data[0x0147] = 0x13 // MBC3+RAM+BATTERY
	for b in 0 ..< 128 {data[b * 0x4000] = u8(b)}
	c, _ := cart_from_bytes(data)
	defer cart_destroy(&c)

	// bank 100 needs 7 bits (MBC1's 5-bit register couldn't reach it)
	cart_write(&c, 0x2000, 100)
	testing.expect_value(t, cart_read(&c, 0x4000), u8(100))
	// bank 0 -> 1 quirk
	cart_write(&c, 0x2000, 0)
	testing.expect_value(t, cart_read(&c, 0x4000), u8(1))
}

@(test)
test_mbc3_ram_bank :: proc(t: ^testing.T) {
	data := make([]byte, 0x8000)
	defer delete(data)
	data[0x0147] = 0x13
	data[0x0149] = 0x03 // 32 KB (4 banks)
	c, _ := cart_from_bytes(data)
	defer cart_destroy(&c)

	cart_write(&c, 0x0000, 0x0A) // enable
	cart_write(&c, 0x4000, 0x02) // RAM bank 2
	cart_write(&c, 0xA000, 0x77)
	cart_write(&c, 0x4000, 0x00) // switch to RAM bank 0
	testing.expect_value(t, cart_read(&c, 0xA000), u8(0x00)) // bank 0 is separate, still zeroed
	cart_write(&c, 0x4000, 0x02) // back to bank 2
	testing.expect_value(t, cart_read(&c, 0xA000), u8(0x77)) // bank 2 retained its value
}

// Selecting an RTC register (>=0x08) returns the stub, not RAM/garbage.
@(test)
test_mbc3_rtc_stub :: proc(t: ^testing.T) {
	data := make([]byte, 0x8000)
	defer delete(data)
	data[0x0147] = 0x13
	data[0x0149] = 0x02 // 8 KB
	c, _ := cart_from_bytes(data)
	defer cart_destroy(&c)

	cart_write(&c, 0x0000, 0x0A) // enable
	cart_write(&c, 0x4000, 0x08) // select RTC seconds
	testing.expect_value(t, cart_read(&c, 0xA000), u8(0x00)) // stub, no crash
	cart_write(&c, 0xA000, 0x42) // RTC write ignored (no crash)
}

// --- MBC5 ---

// 9-bit ROM bank: select a bank > 255 via the low-8 (0x2000) + bit-8 (0x3000) regs.
@(test)
test_mbc5_9bit_rom_banking :: proc(t: ^testing.T) {
	// 512 banks (8 MB). Mark bank N's first byte with N (low 8 bits).
	data := make([]byte, 512 * 0x4000)
	defer delete(data)
	data[0x0147] = 0x19 // MBC5
	for b in 0 ..< 512 {data[b * 0x4000] = u8(b)}
	c, _ := cart_from_bytes(data)
	defer cart_destroy(&c)

	// bank 300 = 0x12C -> low byte 0x2C, bit 8 = 1
	cart_write(&c, 0x2000, 0x2C) // low 8
	cart_write(&c, 0x3000, 0x01) // bit 8
	testing.expect_value(t, cart_read(&c, 0x4000), u8(0x2C)) // bank 300's marker (300 & 0xFF)

	// MBC5 allows bank 0 in the switchable window (no 0->1 quirk)
	cart_write(&c, 0x2000, 0x00)
	cart_write(&c, 0x3000, 0x00)
	testing.expect_value(t, cart_read(&c, 0x4000), u8(0)) // bank 0, NOT 1
}

// MBC5 has no RTC: all RAM banks (incl. >3) are real.
@(test)
test_mbc5_high_ram_bank :: proc(t: ^testing.T) {
	data := make([]byte, 0x8000)
	defer delete(data)
	data[0x0147] = 0x1A // MBC5+RAM
	data[0x0149] = 0x04 // 128 KB (16 banks)
	c, _ := cart_from_bytes(data)
	defer cart_destroy(&c)

	cart_write(&c, 0x0000, 0x0A) // enable
	cart_write(&c, 0x4000, 0x07) // RAM bank 7 (would be dropped by MBC3's <=3 guard)
	cart_write(&c, 0xA000, 0x5E)
	testing.expect_value(t, cart_read(&c, 0xA000), u8(0x5E))
}
