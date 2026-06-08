SRC = mips.v control_unit.v main_decoder.v alu_decoder.v \
      datapath.v pc.v instruction_memory.v \
      reg_file.v alu.v data_memory.v if_stage.v forwarding_unit.v

sim: all

TB  = mips_tb.v
OUT = wave.out
VCD = wave.vcd

.PHONY: all compile run wave clean sim

all: compile run

compile:
	iverilog -o $(OUT) $(TB) $(SRC)

run:
	vvp -n $(OUT)

wave:
	gtkwave $(VCD) &

clean:
	-del /f /q $(OUT) 2>nul
	-del /f /q $(VCD) 2>nul