SRC = mips_tb.v mips.v datapath.v control_unit.v main_decoder.v alu_decoder.v alu.v reg_file.v data_memory.v instruction_memory.v pc.v if_stage.v

all: sim

sim:
	iverilog -o test.vvp $(SRC)
	vvp test.vvp

wave: sim
	gtkwave mips.vcd &

clean:
	del /f /q *.vvp *.vcd *.out