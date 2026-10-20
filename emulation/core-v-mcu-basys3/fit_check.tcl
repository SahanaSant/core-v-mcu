# Basys 3 fit check for CORE-V-MCU (branch basys3-fit-check).
# Run in a FRESH Vivado session (Tcl Console):
#   source C:/Users/user/Desktop/projectz/SystemVerilog/core-v-mcu-wafer-space/core-v-mcu/emulation/core-v-mcu-basys3/fit_check.tcl
# Needs the FuseSoC project generated first (in WSL):
#   fusesoc --cores-root . run --target=basys3 --setup openhwgroup.org:systems:core-v-mcu

set script_dir [file dirname [file normalize [info script]]]
set repo_dir   [file normalize "$script_dir/../.."]
set build_dir  "$repo_dir/build/openhwgroup.org_systems_core-v-mcu_0/basys3-vivado"
set stub       [file normalize "$repo_dir/../rtl/gf180mcu/gf180_efpga_stub.sv"]

# Build settings the IP scripts read (values from the Makefile's nexys-emul,
# with the clock part swapped and L2 shrunk so it can fit the xc7a35t).
set ::env(BOARD)                 basys3
set ::env(BOARD_CLOCK_MHZ)       100
set ::env(XILINX_PART)           xc7a35tcpg236-1
set ::env(FC_CLK_PERIOD_NS)      100
set ::env(PER_CLK_PERIOD_NS)     200
set ::env(FPGA_CLK_PERIOD_NS)    125
set ::env(SLOW_CLK_PERIOD_NS)    4000
set ::env(INTERLEAVED_BANK_SIZE) 1024
set ::env(PRIVATE_BANK_SIZE)     1024

# Close anything open and clear Vivado's generated folders from earlier tries.
while {[llength [get_projects -quiet]] > 0} { close_project }

# Windows caps paths at 260 characters and Vivado's IP runs go over it from
# this deep folder. Map the build folder to a short drive letter (V:) instead.
catch {exec cmd /c subst V: /D}
exec cmd /c subst V: [file nativename $build_dir]
cd V:/
foreach d [glob -nocomplain openhwgroup.org_systems_core-v-mcu_0.{srcs,gen,runs,cache,ip_user_files,hw,sim,xpr}] {
    file delete -force $d
}

# Recreate the project from FuseSoC's script.
source openhwgroup.org_systems_core-v-mcu_0.tcl

# Swap the QuickLogic eFPGA for the wafer-space stub (same module name).
foreach pat {*quicklogic.com_ip_efpga_0* */efpga_subsystem/*} {
    set f [get_files -quiet -filter "NAME =~ $pat"]
    if {[llength $f] > 0} { remove_files $f }
}
add_files -norecurse $stub
set_property file_type SystemVerilog [get_files $stub]

# Lock the top so Vivado doesn't guess.
set_property source_mgmt_mode None [current_project]
set_property top core_v_mcu_basys3 [current_fileset]
# Shrink L2 in the RTL to match the 1024-word RAM IP (see l2_ram_multi_bank.sv).
set_property verilog_define {FPGA=true PULP_FPGA_EMUL=1 BASYS3_SMALL_L2=1} [get_filesets sources_1]

# Area-focused synthesis. flatten.tcl sets FLATTEN_HIERARCHY none, which
# blocks optimization across module boundaries; rebuilt allows it.
set_property strategy Flow_AreaOptimized_high [get_runs synth_1]
set_property STEPS.SYNTH_DESIGN.ARGS.FLATTEN_HIERARCHY rebuilt [get_runs synth_1]
reset_run synth_1
launch_runs synth_1 -jobs 8
puts "fit_check: synthesis launched for top [get_property top [current_fileset]]"

# In batch mode (run from a terminal), wait for synthesis and write the reports
# next to the project so they can be read without opening the GUI.
if {$rdi::mode eq "batch"} {
    wait_on_run synth_1
    puts "fit_check: synth_1 status = [get_property STATUS [get_runs synth_1]]"
    if {[get_property PROGRESS [get_runs synth_1]] eq "100%"} {
        open_run synth_1
        report_utilization -file V:/fit_utilization.rpt
        report_utilization -hierarchical -hierarchical_depth 4 -file V:/fit_utilization_hier.rpt
        # Vivado's optimization pass removes unused/duplicate logic; this is the
        # realistic LUT count. Still no bitstream and no board involved.
        opt_design
        report_utilization -file V:/fit_utilization_opt.rpt
        report_utilization -hierarchical -hierarchical_depth 4 -file V:/fit_utilization_opt_hier.rpt
        puts "fit_check: reports written to $build_dir"
    }
}
