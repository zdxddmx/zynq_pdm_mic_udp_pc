open_project C:/Users/29229/Desktop/ZYNQ_7020_FPGA/47_pdm_mic_udp_pc/prj/ad_udp_pc.xpr
reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
set synth_status [get_property STATUS [get_runs synth_1]]
puts "SYNTH_STATUS=$synth_status"
if {[string first "Complete" $synth_status] < 0} {
    exit 1
}
exit 0
