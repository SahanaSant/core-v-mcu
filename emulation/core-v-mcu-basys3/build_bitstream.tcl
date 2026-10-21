# Basys 3: place & route + bitstream for CORE-V-MCU. No board needed.
# Run AFTER fit_check.tcl has synthesized the project. In PowerShell:
#   vivado.bat -mode batch -source <repo>/emulation/core-v-mcu-basys3/build_bitstream.tcl
# Output: core_v_mcu_basys3.bit plus impl_utilization.rpt / impl_timing.rpt,
# all in the build folder (mapped to V:).

set script_dir [file dirname [file normalize [info script]]]
set repo_dir   [file normalize "$script_dir/../.."]
set build_dir  "$repo_dir/build/openhwgroup.org_systems_core-v-mcu_0/basys3-vivado"

# Same build settings fit_check.tcl used (the IP scripts read these).
set ::env(BOARD)                 basys3
set ::env(BOARD_CLOCK_MHZ)       100
set ::env(XILINX_PART)           xc7a35tcpg236-1
set ::env(FC_CLK_PERIOD_NS)      100
set ::env(PER_CLK_PERIOD_NS)     200
set ::env(FPGA_CLK_PERIOD_NS)    125
set ::env(SLOW_CLK_PERIOD_NS)    4000
set ::env(INTERLEAVED_BANK_SIZE) 1024
set ::env(PRIVATE_BANK_SIZE)     1024

# Short drive letter again (Windows 260-char path limit).
catch {exec cmd /c subst V: /D}
exec cmd /c subst V: [file nativename $build_dir]
cd V:/

open_project V:/openhwgroup.org_systems_core-v-mcu_0.xpr

if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {
    puts "build_bitstream: synth_1 is not complete. Run fit_check.tcl first."
    exit 1
}

# Area-friendly placement, since the device is ~91% full.
set_property strategy Area_Explore [get_runs impl_1]
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1

set status [get_property STATUS [get_runs impl_1]]
puts "build_bitstream: impl_1 status = $status"

if {[get_property PROGRESS [get_runs impl_1]] eq "100%"} {
    open_run impl_1
    report_utilization   -file V:/impl_utilization.rpt
    report_timing_summary -file V:/impl_timing.rpt
    set bit [glob -nocomplain V:/openhwgroup.org_systems_core-v-mcu_0.runs/impl_1/*.bit]
    if {[llength $bit] > 0} {
        file copy -force [lindex $bit 0] V:/core_v_mcu_basys3.bit
        puts "build_bitstream: bitstream at $build_dir/core_v_mcu_basys3.bit"
    }
}
