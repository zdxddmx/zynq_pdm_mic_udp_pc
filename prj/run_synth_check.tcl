# 在仓库根目录、或在 Vivado Tcl Console 中 source 本脚本执行
set prj_dir [file dirname [file dirname [info script]]]
open_project [file join $prj_dir prj ad_udp_pc.xpr]
