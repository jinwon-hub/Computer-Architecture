all: sim

sim:
	iverilog -o test.vvp alu_my.v alu_my_tb.v
	vvp test.vvp

wave:
	gtkwave alu_my.vcd

clean:
	rm -f *.vvp *.vcd