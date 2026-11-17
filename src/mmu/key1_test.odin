#+build !js
package mmu

import "core:testing"

// KEY1 (FF4D): bit7 = current speed, bit0 = armed, bits1-6 read as 1.
@(test)
test_key1_read_write_bits :: proc(t: ^testing.T) {
	m: Mmu
	testing.expect_value(t, mmu_read(&m, 0xFF4D), u8(0x7E)) // speed 0, unarmed
	mmu_write(&m, 0xFF4D, 0x01) // arm
	testing.expect_value(t, mmu_read(&m, 0xFF4D), u8(0x7F)) // armed (bit0)
	m.double_speed = true
	testing.expect_value(t, mmu_read(&m, 0xFF4D), u8(0xFF)) // double speed + armed
}

// Only bit 0 of a KEY1 write is honored (arm flag); other bits are ignored.
@(test)
test_key1_write_only_bit0 :: proc(t: ^testing.T) {
	m: Mmu
	mmu_write(&m, 0xFF4D, 0xFE) // bit0 clear, junk high bits
	testing.expect(t, !m.key1_armed, "bit0 clear -> not armed")
	mmu_write(&m, 0xFF4D, 0xFF) // bit0 set
	testing.expect(t, m.key1_armed, "only bit0 arms")
}

// The switch toggles speed and clears the arm flag; a second call is a no-op.
@(test)
test_speed_switch_toggles_when_armed :: proc(t: ^testing.T) {
	m: Mmu
	m.key1_armed = true
	mmu_try_speed_switch(&m)
	testing.expect(t, m.double_speed, "armed -> switched to double")
	testing.expect(t, !m.key1_armed, "arm flag cleared after switch")

	mmu_try_speed_switch(&m) // not armed now
	testing.expect(t, m.double_speed, "no re-toggle when unarmed")
}
