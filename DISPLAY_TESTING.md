# Display RTL testing

Run these commands from PowerShell in the repository root:

```powershell
cd "C:\Users\user\Projects\SystemVerilog\core-v-mcu copy"
```

## Run every standalone display test

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\run_display_tests.ps1
```

The command runs the basic TCDM regression, generates and verifies a 320x200
framebuffer image, checks an RGB565 SPI stream, and writes this preview:

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

- The SPI streamer sends already-prepared RGB565 pixel words in SPI mode 0.
- LCD reset, command/data control, initialization commands, and address-window
  setup remain board/display-specific RTL.
- The full CORE-V simulation cannot currently compile locally because ModelSim
  is not installed. The Verilator `model-lib` target does build successfully.
- A new CPU-executed display smoke-test program additionally needs a RISC-V
  cross compiler and a project-specific firmware build flow.
- Vivado synthesis cannot currently run locally because Vivado is not installed.
