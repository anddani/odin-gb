#+build !js
package mmu

import "core:testing"

// Point the HDMA source/dest registers at src -> dst.
@(private = "file")
set_hdma_regs :: proc(m: ^Mmu, src, dst: u16) {
	mmu_write(m, 0xFF51, u8(src >> 8))
	mmu_write(m, 0xFF52, u8(src & 0xFF))
	mmu_write(m, 0xFF53, u8(dst >> 8))
	mmu_write(m, 0xFF54, u8(dst & 0xFF))
}

// GDMA (bit7=0) copies the whole transfer immediately.
@(test)
test_hdma_gdma_immediate :: proc(t: ^testing.T) {
	m: Mmu
	for i in 0 ..< 16 {mmu_write(&m, 0xC000 + u16(i), u8(0xA0 + i))}
	set_hdma_regs(&m, 0xC000, 0x8000)
	mmu_write(&m, 0xFF55, 0x00) // GDMA, 1 block (16 bytes)
	for i in 0 ..< 16 {
		testing.expect_value(t, mmu_read(&m, 0x8000 + u16(i)), u8(0xA0 + i))
	}
	testing.expect_value(t, mmu_read(&m, 0xFF55), u8(0xFF)) // done
	testing.expect(t, !m.hdma_active, "GDMA leaves no active HDMA")
}

// GDMA length is (value & 0x7F)+1 blocks of 16 bytes.
@(test)
test_hdma_gdma_multiblock :: proc(t: ^testing.T) {
	m: Mmu
	for i in 0 ..< 32 {mmu_write(&m, 0xC000 + u16(i), u8(i))}
	set_hdma_regs(&m, 0xC000, 0x8000)
	mmu_write(&m, 0xFF55, 0x01) // 2 blocks = 32 bytes
	for i in 0 ..< 32 {
		testing.expect_value(t, mmu_read(&m, 0x8000 + u16(i)), u8(i))
	}
}

// HDMA (bit7=1) copies one 16-byte block per H-blank step and advances src/dst.
@(test)
test_hdma_hblank_incremental :: proc(t: ^testing.T) {
	m: Mmu
	for i in 0 ..< 32 {mmu_write(&m, 0xC000 + u16(i), u8(i))}
	set_hdma_regs(&m, 0xC000, 0x8000)
	mmu_write(&m, 0xFF55, 0x81) // HDMA, 2 blocks

	testing.expect(t, m.hdma_active, "HDMA armed")
	testing.expect_value(t, mmu_read(&m, 0xFF55), u8(1)) // blocks-1, bit7=0 (active)
	testing.expect_value(t, mmu_read(&m, 0x8000), u8(0)) // nothing copied yet

	hdma_step_hblank(&m) // block 0 -> 0x8000..0x800F
	for i in 0 ..< 16 {testing.expect_value(t, mmu_read(&m, 0x8000 + u16(i)), u8(i))}
	testing.expect_value(t, mmu_read(&m, 0xFF55), u8(0)) // 1 block left
	testing.expect(t, m.hdma_active, "still active after 1 block")

	hdma_step_hblank(&m) // block 1 -> 0x8010..0x801F (dst advanced)
	for i in 0 ..< 16 {testing.expect_value(t, mmu_read(&m, 0x8010 + u16(i)), u8(16 + i))}
	testing.expect(t, !m.hdma_active, "done after 2 blocks")
	testing.expect_value(t, mmu_read(&m, 0xFF55), u8(0xFF)) // finished

	hdma_step_hblank(&m) // inactive -> no-op (must not crash or copy)
}

// Writing FF55 with bit7=0 while an HDMA runs cancels it (does NOT start a GDMA).
@(test)
test_hdma_cancel :: proc(t: ^testing.T) {
	m: Mmu
	for i in 0 ..< 16 {mmu_write(&m, 0xC000 + u16(i), 0xFF)}
	set_hdma_regs(&m, 0xC000, 0x8000)
	mmu_write(&m, 0xFF55, 0x85) // HDMA, 6 blocks
	testing.expect(t, m.hdma_active, "armed")

	mmu_write(&m, 0xFF55, 0x00) // cancel (bit7=0 while active)
	testing.expect(t, !m.hdma_active, "cancelled")
	testing.expect_value(t, mmu_read(&m, 0x8000), u8(0)) // no GDMA ran
	testing.expect_value(t, mmu_read(&m, 0xFF55), u8(0xFF))
}

// Source/dest low nibbles are ignored (16-byte alignment).
@(test)
test_hdma_alignment :: proc(t: ^testing.T) {
	m: Mmu
	mmu_write(&m, 0xC000, 0xAA) // aligned source byte
	mmu_write(&m, 0xC00F, 0xBB) // used only if the low nibble were honored
	set_hdma_regs(&m, 0xC00F, 0x800F) // low nibbles must drop to 0
	mmu_write(&m, 0xFF55, 0x00) // GDMA, 1 block
	testing.expect_value(t, mmu_read(&m, 0x8000), u8(0xAA)) // src forced to 0xC000
}
