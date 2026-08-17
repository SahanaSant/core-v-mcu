# Out-of-context Vivado synthesis and block-RAM inference check.
set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $script_dir ..]]
set build_dir [file join $repo_root build vivado-display-ooc]

if {[info exists ::env(FPGA_PART)]} {
  set fpga_part $::env(FPGA_PART)
} else {
  # Basys 3 Artix-7 part. Override FPGA_PART for the final club board.
  set fpga_part xc7a35tcpg236-1
}

if {[info exists ::env(CLOCK_PERIOD_NS)]} {
  set clock_period_ns $::env(CLOCK_PERIOD_NS)
} else {
  set clock_period_ns 10.000
}

file mkdir $build_dir
create_project -in_memory -part $fpga_part

read_verilog -sv [list \
  [file join $repo_root rtl core-v-mcu soc display_framebuffer.sv] \
  [file join $repo_root rtl core-v-mcu soc display_palette.sv] \
  [file join $repo_root rtl core-v-mcu soc display_tcdm_slave_core.sv] \
]

synth_design -top display_tcdm_slave_core -mode out_of_context -part $fpga_part
create_clock -name display_clk -period $clock_period_ns [get_ports clk_i]

report_utilization -hierarchical -file [file join $build_dir utilization.rpt]
report_timing_summary -delay_type max -max_paths 10 \
  -file [file join $build_dir timing_summary.rpt]
write_checkpoint -force [file join $build_dir display_tcdm_slave_core.dcp]

set bram_cells [get_cells -hierarchical -filter {PRIMITIVE_TYPE =~ BMEM.bram.*}]
set bram_report [open [file join $build_dir bram_cells.txt] w]
puts $bram_report "FPGA part: $fpga_part"
puts $bram_report "BRAM primitive count: [llength $bram_cells]"
foreach bram_cell $bram_cells {
  puts $bram_report $bram_cell
}
close $bram_report

if {[llength $bram_cells] == 0} {
  error "No block-RAM primitives were inferred for the display subsystem"
}

puts "PASS: Vivado inferred [llength $bram_cells] block-RAM primitives"
puts "Reports written to $build_dir"
