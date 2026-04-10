# List all module files
SRC = datapath_my.v if_stage_my.v pc_my.v instruction_memory_my.v \
      reg_file_my.v alu_my.v data_memory_my.v
TB  = datapath_my_tb.v

OUT = datapath_my.out
VCD = datapath_my.vcd

all: compile run

compile:
	iverilog -o $(OUT) $(TB) $(SRC)

run:
	vvp -n $(OUT)

wave:
	gtkwave $(VCD) &

clean:
	if exist $(OUT) del $(OUT)
	if exist $(VCD) del $(VCD)