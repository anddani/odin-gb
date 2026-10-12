package cart

import "core:mem"
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
