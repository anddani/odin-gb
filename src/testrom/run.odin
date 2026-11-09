package testrom

import "core:fmt"

import "../cart"
import "../cpu"
import "../mmu"

// A Blargg test run drives a real cpu.Cpu through the real MMU (banked memory,
// ROM delegated to the cart), capturing serial output to decide Passed/Failed.

// Everything the Bus context needs: the MMU plus the serial scoreboard.
Machine :: struct {
	mmu:    mmu.Mmu,
	serial: Serial_Capture,
}

machine_read :: proc(ctx: rawptr, addr: u16) -> u8 {
	return mmu.mmu_read(&(cast(^Machine)ctx).mmu, addr)
}

machine_write :: proc(ctx: rawptr, addr: u16, value: u8) {
	m := cast(^Machine)ctx
	mmu.mmu_write(&m.mmu, addr, value)
	serial_write(&m.serial, addr, value) // ignores non-serial addresses
}

Run_Result :: struct {
	status:      Serial_Status,
	cycles:      int,
	no_progress: bool, // step returned 0 -- CPU not executing yet
}

// Generous cycle budget: the individual cpu_instrs sub-tests finish well under
// this. A ROM that never prints Passed/Failed hits the budget and we stop.
MAX_CYCLES :: 100_000_000

// Post-boot register state (we skip the DMG boot ROM and jump straight to the
// cartridge entry at 0x0100 with the documented register values).
PC_ENTRY :: 0x0100

run_blargg_serial :: proc(rom_path: string) -> (result: Run_Result, err: cart.Cart_Error) {
	c := cart.cart_from_file(rom_path) or_return
	defer cart.cart_destroy(&c)

	m := new(Machine)
	defer free(m)
	m.mmu.cart = &c // MMU delegates ROM/external-RAM reads to the cart

	state: cpu.Cpu
	state.bus = cpu.Bus {
		ctx   = m,
		read  = machine_read,
		write = machine_write,
	}
	state.pc = PC_ENTRY
	state.sp = 0xFFFE
	cpu.set_af(&state, 0x01B0)
	cpu.set_bc(&state, 0x0013)
	cpu.set_de(&state, 0x00D8)
	cpu.set_hl(&state, 0x014D)

	last_n := 0
	for result.cycles < MAX_CYCLES {
		used := cpu.step(&state)
		if used <= 0 {
			result.no_progress = true
			break
		}
		result.cycles += used

		// Only rescan the serial text when new bytes have arrived.
		if m.serial.n != last_n {
			last_n = m.serial.n
			status := serial_status(&m.serial)
			if status != .Running {
				result.status = status
				break
			}
		}
	}

	// Surface whatever the ROM printed so failures are legible.
	fmt.printf("[%s] status=%v cycles=%d\n%s\n", rom_path, result.status, result.cycles, serial_text(&m.serial))
	return
}
