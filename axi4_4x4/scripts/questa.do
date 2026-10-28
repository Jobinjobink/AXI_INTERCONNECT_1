# Run from the extracted project root: vsim -c -do scripts/questa.do
onerror {quit -code 1 -force}
onbreak {quit -code 1 -force}
file mkdir build
vlib build/questa_work
vmap work build/questa_work
vlog -sv -f filelist.f tb/axi4_owner_checker.sv tb/axi4_protocol_checker.sv tb/axi4_test_slave.sv tb/tb_axi4_interconnect.sv
vsim -c work.tb_axi4_interconnect +SEED=1
run -all
quit -code 0 -force
