# 1. 5-Stage Pipelined MIPS CPU with Switch-Controlled PWM Motor Controller

A complete 5-stage pipelined MIPS processor that reads hardware switch inputs via Memory-Mapped I/O (MMIO) and dynamically modulates a PWM signal to control a DC motor's average power.

## 2. System Block Diagram

```text
+---------------------------------------------------------------------------------------+
|                                     MIPS PROCESSOR                                    |
|                                                                                       |
|  +---------+      +---------+      +---------+      +--------------+      +---------+ |
|  |  FETCH  | ---> | DECODE  | ---> | EXECUTE | ---> |    MEMORY    | ---> |WRITEBACK| |
|  |  (IF)   |      |  (ID)   |      |  (EX)   |      |    (MEM)     |      |  (WB)   | |
|  +---------+      +---------+      +---------+      +-------+------+      +---------+ |
|       ^                |                |                   |                      |  |
|       |                v                v                   v                      |  |
|  +----+----------------+----------------+-------------------+--------------------+  |  |
|  |                            HAZARD UNIT (Stalls & Forwarding)                 |  |  |
|  +------------------------------------------------------------------------------+  |  |
+-----------------------------------------------------------------------------------|---+
                                                                                      |
                                                    [Internal Memory Bus]             |
                                                    (Addr, Write_Data, Mem_Write)     v
+---------------------------------------------------------------------------------------+
|                               MEMORY-MAPPED I/O (MMIO) BRIDGE                         |
|                                                                                       |
|       +-----------------------+   +-------------------+   +-------------------+       |
|       |   Internal RAM        |   |   switches Reg    |   |   pwm_duty Reg    |       |
|       |   (0x000 - 0x08F)     |   |   (0x090, R-Only) |   |   (0x098, W-Only) |       |
|       +-----------------------+   +---------+---------+   +---------+---------+       |
+---------------------------------------------|-----------------------|-----------------+
                                              ^                       |
                                              |                       v
                                        [8-bit Input]           [8-bit Target]
                                              |                       |
                                              |               +-------v---------+
                                              |               |  PWM CONTROLLER |
                                              |               | (Counter + Cmp) |
                                              |               +--------+--------+
                                              |                        |
                                              |                        v
                                      [Physical Pins]            [Square Wave]
                                       switches[7:0]                pwm_out

```

### 3. MMIO Address Map Table
```
Base Address,Device / Register,Access Direction,Data Width,Functional Notes
0x00000000 - 0x0000008F,Internal RAM,Read / Write,32-bit,Standard memory storage (64 words allocated).
0x00000090,switches,Read-Only,8-bit,Reads external physical switches. Upper 24 bits are padded with 0.
0x00000098,pwm_duty,Write-Only,8-bit,Sets the motor target speed threshold (0 to 255).
0x0000009C,pwm_en,Write-Only,1-bit,Enables (1) or disables (0) the hardware PWM counter peripheral.
```

## 4. How to Build and Run
```
To compile the Verilog source files, execute the simulation, and analyze the timing waveforms using the automated Makefile, run the exact shell commands below in your terminal:
 1. Compile all source files and run the testbench simulation
make

 2. View the generated simulation wave trace in GTKWave
gtkwave mips.vcd
```


## 5. What You'll See (Expected Waveform Behavior)
```
When you open mips.vcd in GTKWave, you will witness the system execute a software polling loop that implements Option B (Switch-Controlled Duty Cycle). The pipeline and peripheral signals behave as follows:

Initialization Phase (0ns to 15ns): The system is held in reset (rst_n is Low). The PC stays at 0 and all pipeline registers are cleared. At 15ns, rst_n transitions to High, and instruction fetching starts.

Boot-up & Activation (15ns to 100ns): The processor executes the initial assembly instructions. It writes 1 to address 0x0000009C, which toggles pwm_en to High, kicking off the internal 10-bit PWM timer counter.

25% Duty Cycle State (100ns to 80,100ns): The testbench drives switches = 8'h40 (decimal 64). The CPU loads this value using a lw instruction from 0x00000090 and maps it via sw to pwm_duty (0x00000098). You will see pwm_out produce a narrow square wave that stays High for exactly 25% of the timer cycle and Low for 75%.

50% Duty Cycle State (80,100ns to 160,100ns): The testbench changes switches to 8'h80 (decimal 128). The CPU's polling loop fetches this change on its next iteration and overwrites pwm_duty with 128. The pwm_out signal shifts to a symmetrical, clean 1:1 square wave balance (50% High, 50% Low).

75% Duty Cycle State (160,100ns onwards): The switches input peaks at 8'hC0 (decimal 192). The CPU updates pwm_duty to 192, causing the pwm_out wave to remain High for 75% of the total period, representing maximum power transfer to the motor before the simulation safely concludes with $finish.

Throughout the entire run, notice that the hazard_unit actively updates forward_a_E and forward_b_E to forward operands seamlessly, preventing pipeline stalls during mathematical computations.
```

# 6. File Layout
```
The repository is organized according to the following hierarchical module tree:

PWM/
├── README.md               # System specification and documentation 
├── Makefile                # Automation script for building and running simulation
├── memfile.dat             # Instruction memory initialization file (MIPS machine hex code)
├── mips.v                  # Top-level module unifying CPU Datapath and Data Memory
├── mips_tb.v               # Simulation testbench (drives switches, clocks, and resets)
|
├── datapath.v           # 5-stage MIPS pipelined datapath architecture
├── control_unit.v       # Top control block instantiating Main and ALU decoders
├── main_decoder.v       # Decodes instruction Opcode into primary control signals
├── alu_decoder.v        # Decodes Funct bits for specific ALU operations
├── alu.v                # Arithmetic Logic Unit executing core R/I calculations
├── reg_file.v           # 32x32-bit register file featuring falling-edge writes
├── pc.v                 # Program Counter register with clock-enable stall support
├── instruction_memory.v # ROM array initialized via memfile.dat
├── data_memory.v        # Data RAM combined with Memory-Mapped I/O logic bridge
├── hazard_unit.v        # Manages data forwarding, load-use stalls, and branch flushes
└── pwm_controller.v     # 10-bit counter-driven PWM generator peripheral
└──docs/
    └──design_report.md       # explains your decisions to the grader
    └──test_report.md         # proves your system actually works
    └──waveform_profile.png   # waveform image
```