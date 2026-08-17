# Display RTL testing

Run these commands from PowerShell in the repository root:

```powershell
cd "C:\Users\user\Projects\SystemVerilog\core-v-mcu copy"
```

## Run every standalone display test

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\run_display_tests.ps1
```

The command runs five tests: the basic TCDM regression, a generated 320x200
framebuffer image, the ST7789VI reset/initialization sequence, a full-size
RGB565 3-wire SPI stream, and a focused integration test through
`display_subsystem_core`. The integration test writes the palette and
framebuffer through TCDM, starts the frame through the control register,
verifies every 9-bit SPI word, and reads back status and the frame counter. It
also writes this preview:

```text
build\display-tests\image\display_framebuffer_test.png
```

## Validate the full CORE-V MCU FuseSoC setup

FuseSoC and Verilator are installed in the current WSL environment. Keep the
FuseSoC build directory in the Ubuntu filesystem: Verilator's GNU Make flow
cannot build in the repository path because `core-v-mcu copy` contains a space.

Run the full Verilator model build with:

```powershell
wsl.exe bash -lc "cd '/mnt/c/Users/user/Projects/SystemVerilog/core-v-mcu copy' && /home/sahana/.local/bin/fusesoc --cores-root . run --target=model-lib --setup --build --build-root /home/sahana/core-v-build-model openhwgroup.org:systems:core-v-mcu"
```

Run the full Verilator lint build with:

```powershell
wsl.exe bash -lc "cd '/mnt/c/Users/user/Projects/SystemVerilog/core-v-mcu copy' && /home/sahana/.local/bin/fusesoc --cores-root . run --target=lint --setup --build --build-root /home/sahana/core-v-build-lint openhwgroup.org:systems:core-v-mcu"
```

The Windows installation of Icarus Verilog is enough for
`tests/run_display_tests.ps1`. Install `iverilog` separately inside Ubuntu only
if you want to run Icarus-based FuseSoC targets from WSL.

The repository's full simulation target uses ModelSim. Set `MODEL_TECH` to its
`bin` directory, then run:

```powershell
wsl.exe bash -lc "cd '/mnt/c/Users/user/Projects/SystemVerilog/core-v-mcu copy' && /home/sahana/.local/bin/fusesoc --cores-root . run --target=sim --setup --build --run openhwgroup.org:systems:core-v-mcu"
```

## Check FPGA block-RAM inference in Vivado

No physical FPGA is required for this out-of-context synthesis. After installing
Vivado and opening a Vivado-enabled PowerShell terminal, run:

```powershell
$env:FPGA_PART = 'xc7a35tcpg236-1'
$env:CLOCK_PERIOD_NS = '10.000'
vivado -mode batch -source .\tests\display_ooc_synth.tcl
```

`xc7a35tcpg236-1` is the Basys 3 FPGA part. Change `FPGA_PART` when the club
selects the final board. Vivado writes the utilization, timing, inferred-BRAM,
and checkpoint results under:

```text
build\vivado-display-ooc\
```

The Tcl script fails deliberately if it cannot find any inferred block-RAM
primitives.

## Current limitations

- `display_subsystem` is connected in `soc_domain`, and its chip-select, clock
  and SDA signals are exposed by `core_v_mcu`, along with LCD reset, IM0, and
  IM2. A board wrapper and XDC file still need to assign them to FPGA pins.
- The target is Newhaven `NHD-2.4-240320AF-CTXP`, driven by an ST7789VI. The
  controller uses 3-wire, 9-bit SPI: each transfer contains a command/data bit
  followed by one byte, so there is no separate D/C output.
- `display_st7789_init` performs the panel reset, sends the 72-word Newhaven
  initialization sequence, selects RGB565, and opens a 320x240 landscape
  address window. IM0 and IM2 are driven high to select 3-wire SPI.
- With a 50 MHz SoC clock and `SPI_CLK_DIV=2`, SCLK is 12.5 MHz. A 320x200
  RGB565 frame takes at least about 92 ms on the wire; RTL overhead makes the
  current practical ceiling roughly 9--10 frames/s.
- Doom produces 320x200 pixels while the LCD is 320x240. The current streamer
  updates the first 200 rows; software or a later controller revision must
  deliberately clear/pad the remaining 40 rows.
- The framebuffer is single-buffered. Writing it while SPI scanout is active
  can tear; software can wait for `DONE`, or a later revision can add a second
  framebuffer and swap them at frame boundaries.
- On the physical module, connect `spi_mosi_o` to SDA, `spi_sclk_o` to SCL,
  `spi_cs_no` to CSX, and `display_reset_no` to RESX. Tie unused WRX, RDX, and
  DB pins low as recommended for serial mode; SDO may remain open when reads
  are unused. The 3.1 V, 80 mA backlight needs the board's appropriate power
  circuitry rather than an ordinary FPGA GPIO.
- Panel orientation, mirroring, RGB/BGR order, pin assignments, and final SPI
  rate still require confirmation on the actual hardware.
- The full CORE-V simulation cannot currently compile locally because ModelSim
  is not installed. The Verilator `model-lib` target does build successfully.
- A new CPU-executed display smoke-test program additionally needs a RISC-V
  cross compiler and a project-specific firmware build flow.
- Vivado synthesis cannot currently run locally because Vivado is not installed.
