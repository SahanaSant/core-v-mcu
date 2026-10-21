# Load the hold-fixed CORE-V-MCU bitstream onto a connected Basys 3 over USB.
# Volatile: the board forgets it on power-off. Nothing is written to flash.
#   vivado.bat -mode batch -source <repo>/emulation/core-v-mcu-basys3/program_board.tcl
set script_dir [file dirname [file normalize [info script]]]
set bit [file normalize "$script_dir/../../build/openhwgroup.org_systems_core-v-mcu_0/basys3-vivado/core_v_mcu_basys3_holdfix.bit"]
open_hw_manager
connect_hw_server
open_hw_target
set dev [lindex [get_hw_devices xc7a35t*] 0]
if {$dev eq ""} { puts "program_board: no xc7a35t found. Is the Basys 3 on and plugged in?"; exit 1 }
current_hw_device $dev
set_property PROGRAM.FILE $bit $dev
program_hw_devices $dev
puts "program_board: programmed $dev with [file tail $bit]"
close_hw_target
disconnect_hw_server
