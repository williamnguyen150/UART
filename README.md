# UART + APB Implementation in Verilog

This repository contains a Verilog implementation that recreates the AMBA APB (Advanced Peripheral Bus) protocol and a UART (Universal Asynchronous Receiver/Transmitter) subsystem, plus example glue logic (APB↔UART bridge), testbenches and simulation.

## Features

- APB-compatible Master/Slave interface modules (address, control, read/write data, handshakes)
- UART Transmitter and Receiver (configurable baud, data bits, parity, stop bits)
- APB-to-UART bridge / peripheral
- Testbenches to simulate typical read/write APB transactions and UART transfers

## Project layout

- /UART/         — Verilog sources (APB, UART, bridge, utils)
- /tb/          — Testbenches and top-level simulation harnesses

## APB overview (short)

APB is a simple, low-power bus for register-access peripherals.

Typical signals (slave view):
- PCLK        — clock
- PRESETn     — active-low reset
- PADDR       — address bus
- PSEL        — select (asserted to begin a transfer)
- PENABLE     — enable (second cycle of a transfer)
- PWRITE      — write/read indicator (1 = write)
- PWDATA      — write data
- PRDATA      — read data (from slave)
- PREADY      — slave ready (stretch cycle if low)
- PSLVERR     — error indicator (optional)

Transfer phases:
1. Address phase: PSEL=1, PENABLE=0, PADDR and PWRITE valid
2. Enable phase: PENABLE=1; data transfer happens if PREADY=1


## UART overview (short)

Basic UART signals:
- tx  — UART transmit output
- rx  — UART receive input
- Baud rate generator controls TX/RX bit timing

Configurable parameters (typical):
- Baud rate (e.g., 115200)
- Data width (usually 8)
- Parity type (none / even / odd)
- Stop bits (1 or 2)

The UART in this repo implements asynchronous bit framing and sample/oversample logic suitable for simulation and basic FPGA use.

## Example instantiation

A minimal APB slave instantiating a UART peripheral (Verilog-style pseudocode):

```verilog
// Example top-level connections (pseudocode)
wire         pclk, presetn;
wire [31:0]  paddr;
wire         psel, penable, pwrite;
wire [31:0]  pwdata;
wire [31:0]  prdata;
wire         pready, pslverr;

apb_uart_bridge u_bridge (
  .PCLK    (pclk),
  .PRESETn (presetn),
  .PADDR   (paddr),
  .PSEL    (psel),
  .PENABLE (penable),
  .PWRITE  (pwrite),
  .PWDATA  (pwdata),
  .PRDATA  (prdata),
  .PREADY  (pready),
  .PSLVERR (pslverr),

  .uart_tx (usb_tx_pin),
  .uart_rx (usb_rx_pin)
);
```

See UART/ for real module names, port widths and parameters.

## Registers (APB↔UART bridge)

Typical register map provided by the bridge (example):
- 0x00 — TXDATA (write) / RXDATA (read)
- 0x04 — STATUS (tx_busy, rx_ready, overrun)
- 0x08 — CTRL (baud divisor, parity select, enable)
- 0x0C — IRQ / INT_MASK

## Running simulations

ModelSim / Questa example:
- vlog UART/*.v tb/*.v
- vsim work.[INSERT_TESTBENCH_FILENAME]
- run -all


## Synthesis and FPGA notes

- The design is written in synthesizable Verilog, specifically on DE2-115 dev kit provided to us (check each module for synthesis pragmas).
- For FPGA (Vivado/Quartus):
  - Add rtl/*.v to your project
  - Assign the correct top module
  - Constrain clock and IO pins in SDC files
  - IO pins assignment for DE2 in QSF files
  - Consider removing or gating testbench-only constructs (initial, $display, $dumpfile)
- Baud-rate generation uses counters; ensure clock frequencies and divisors fit your target clock.

## Verification tips

- Use PREADY to model wait states and verify that masters retry transactions until PREADY=1.
- Simulate UART with oversampling or mid-bit sampling to exercise receiver robustness.
- Create fuzz tests or randomized APB sequences to verify corner cases (PSEL toggling, short transfers).

## Contact / Author

Repository: https://github.com/williamnguyen150/UART

For questions or improvements, open an issue or a pull request on GitHub.

---
