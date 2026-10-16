package testrom

import "core:testing"

// Simulate a Blargg ROM printing a string: for each byte, write it to SB then
// start a serial transfer by writing SC with the transfer bit set.
push_serial :: proc(c: ^Serial_Capture, s: string) {
	for i in 0 ..< len(s) {
		serial_write(c, SB_ADDR, s[i])
		serial_write(c, SC_ADDR, 0x81)
	}
}

@(test)
test_serial_captures_text :: proc(t: ^testing.T) {
	c: Serial_Capture
	push_serial(&c, "01-special\n\nPassed\n")
	testing.expect_value(t, serial_text(&c), "01-special\n\nPassed\n")
}

@(test)
test_serial_detects_passed :: proc(t: ^testing.T) {
	c: Serial_Capture
	push_serial(&c, "Passed\n")
	testing.expect_value(t, serial_status(&c), Serial_Status.Passed)
}

@(test)
test_serial_detects_failed :: proc(t: ^testing.T) {
	c: Serial_Capture
	push_serial(&c, "Failed #3\n")
	testing.expect_value(t, serial_status(&c), Serial_Status.Failed)
}

@(test)
test_serial_running_until_marker :: proc(t: ^testing.T) {
	c: Serial_Capture
	push_serial(&c, "01-special\n") // no Passed/Failed yet
	testing.expect_value(t, serial_status(&c), Serial_Status.Running)
}

// A byte in SB with no transfer-start (0x80 bit clear) must not be captured.
@(test)
test_serial_requires_transfer_bit :: proc(t: ^testing.T) {
	c: Serial_Capture
	serial_write(&c, SB_ADDR, 'X')
	serial_write(&c, SC_ADDR, 0x00)
	testing.expect_value(t, serial_text(&c), "")
}

// Writes outside the serial registers must be ignored entirely.
@(test)
test_serial_ignores_other_addrs :: proc(t: ^testing.T) {
	c: Serial_Capture
	serial_write(&c, 0xC000, 'A')
	serial_write(&c, 0xFF40, 'B')
	testing.expect_value(t, serial_text(&c), "")
}
