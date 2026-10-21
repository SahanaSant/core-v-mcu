# Basys 3: try to clear hold-time violations left after build_bitstream.tcl.
# Works on the routed impl_1 result; no re-synthesis, no board needed.
#   vivado.bat -mode batch -source <repo>/emulation/core-v-mcu-basys3/hold_fix.tcl

set script_dir [file dirname [file normalize [info script]]]
set build_dir  [file normalize "$script_dir/../../build/openhwgroup.org_systems_core-v-mcu_0/basys3-vivado"]
catch {exec cmd /c subst V: /D}
exec cmd /c subst V: [file nativename $build_dir]
cd V:/

open_checkpoint [glob V:/openhwgroup.org_systems_core-v-mcu_0.runs/impl_1/*_routed.dcp]
puts "hold_fix: WHS before = [get_property SLACK [get_timing_paths -hold]] ns"

# Hold violations here come from clock skew on gated clocks (~1.1 ns).
# Setup slack is 33+ ns, so trading some of it for hold is free.
phys_opt_design -hold_fix
route_design -directive Explore
phys_opt_design -hold_fix

puts "hold_fix: WHS after  = [get_property SLACK [get_timing_paths -hold]] ns"
puts "hold_fix: WNS after  = [get_property SLACK [get_timing_paths -setup]] ns"
report_timing_summary -file V:/hold_fix_timing.rpt
write_checkpoint -force V:/hold_fix_routed.dcp
write_bitstream -force V:/core_v_mcu_basys3_holdfix.bit
puts "hold_fix: bitstream at $build_dir/core_v_mcu_basys3_holdfix.bit"
