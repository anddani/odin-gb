package testrom

import "core:strings"

// Blargg's test ROMs report their results by "printing" over the serial port:
// each character is written to SB (0xFF01), then a transfer is started by
// writing SC (0xFF02) with the transfer bit (0x80) set. We don't emulate any
// serial timing -- at transfer-start we just grab the byte currently in SB,
// accumulate the text, and scan it for Blargg's "Passed"/"Failed" markers.
//
// Feed serial_write() every CPU memory write; writes outside the two serial
// registers are ignored, so it is safe to wire into the whole write path.

SB_ADDR :: 0xFF01
SC_ADDR :: 0xFF02
SC_TRANSFER_BIT :: 0x80

Serial_Status :: enum {
	Running,
	Passed,
	Failed,
}

Serial_Capture :: struct {
	sb:  u8,          // last byte written to SB, pending transfer
	buf: [1024]u8,    // accumulated output (Blargg messages are short)
	n:   int,         // bytes used in buf
}

serial_write :: proc(c: ^Serial_Capture, addr: u16, val: u8) {
	switch addr {
	case SB_ADDR:
		c.sb = val
	case SC_ADDR:
		if (val & SC_TRANSFER_BIT) != 0 && c.n < len(c.buf) {
			c.buf[c.n] = c.sb
			c.n += 1
		}
	}
}

serial_text :: proc(c: ^Serial_Capture) -> string {
	return string(c.buf[:c.n])
}

serial_status :: proc(c: ^Serial_Capture) -> Serial_Status {
	text := serial_text(c)
	switch {
	case strings.contains(text, "Passed"):
		return .Passed
	case strings.contains(text, "Failed"):
		return .Failed
	}
	return .Running
}
