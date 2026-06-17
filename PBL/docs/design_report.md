# 1. Introduction
```
In this project, we have designed and implemented a fully verified 5-stage pipelined MIPS processor coupled with a hardware Pulse Width Modulation (PWM) controller via a custom Memory-Mapped I/O (MMIO) interface bridge. Embedded systems routinely demand real-time reactive communication between computational logic and physical actuators. This design addresses that core requirement by enabling the pipelined datapath to poll external switch configurations and immediately modify physical DC motor average power profiles. This system serves as a foundational demonstration of how specialized peripheral hardware accelerators can be seamlessly bound to a classic RISC ISA to deliver deterministic control without sacrificing pipeline throughput.
```
# 2. System Architecture
```
2-1. Block diagram
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
                                               v                       v
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

2.2 Module Functional Descriptions

Instruction Fetch (IF) / PC Module: Manages the generation of the next Program Counter value while accommodating pipeline hold signals caused by memory load stalls.

Instruction Memory: A read-only memory structure initialized using machine hex codes (memfile.dat) to supply instructions deterministically based on the current PC.

Instruction Decode (ID) / Control Unit: Decodes opcode fields and maps instruction functionalities to internal execution buses, hosting a register file featuring falling-edge synchronization.

ALU Decoder: Translates ALUOp identifiers paired with R-type instruction funct fields into dedicated 3-bit operational control signals (alu_ctrl).

Execute (EX) / ALU Module: Executes core mathematical calculations, logic masking, and relational target evaluation using low-latency combinational elements.

Hazard Unit: Actively monitors register dependencies across pipelined stages to dynamically introduce forwarding paths or insert load-use execution stalls.

Data Memory / MMIO Bridge: A unified address space arbiter that splits memory transaction paths between standard scratchpad RAM and external peripheral registers.

PWM Controller: An independent hardware peripheral running a digital free-running timer compared against a target threshold register to drive stable high-frequency square wave signals.
```

## 3. MMIO Design
```
3-1. address map
Base Address,Device / Register,Access Direction,Data Width,Functional Notes
0x00000000 - 0x0000008F,Internal RAM,Read / Write,32-bit,Standard memory storage for instructions and local variables (64 words allocated).
0x00000090,switches,Read-Only,8-bit,Reads external physical switch states. Upper 24 bits are automatically zero-extended.
0x00000098,pwm_duty,Write-Only,8-bit,Sets the motor target pulse width threshold (0 to 255) for duty cycle modulation.
0x0000009C,pwm_en,Write-Only,1-bit,Enables (1) or disables (0) the hardware PWM timer module counter.

3.2 Address Decoding Logic
The data_memory module intercepts the master memory address lines (alu_result_M). If the address spans within the 0x00000000 to 0x0000008F range, standard internal RAM access occurs. When the address lines decode to 0x00000090 or higher, write enable triggers (mem_write_M) bypass the internal RAM block and route straight to peripheral flag flip-flops.

3.3 Synchronous Writes vs. Combinational Reads
Synchronous Writes: Modifying hardware state configuration fields (like pwm_duty or pwm_en) must be restricted to the active clock edges (posedge clk). Pipelined execution stages mean structural data paths settle mid-cycle; committing data to memory registers prior to the clock edge risks latching transient, unsettled values due to raw combinational races.

Combinational Reads: Reading hardware parameters (such as polling input switches) is completely combinational. The CPU pipeline captures read bus data at the final transition of the Memory stage to Write-Back. Making read indexing combinational ensures that the current, authentic physical external pin state bypasses additional latency penalties and maps immediately to pipeline data forward lines.
```

## 4. PWM Controller Design
```
4.1 Counter + Comparator Architecture
The PWM module contains an internal digital counting structure paired with an equality comparator. To optimize behavioral simulation runs while maintaining robust 8-bit resolution steps, our design leverages a 10-bit free-running step counter register (counter[9:0]). During active generation loops (enable == 1), the counter steps upward on every clock tick.

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)          counter <= 10'b0;
    else if (enable)     counter <= counter + 1;
    else                 counter <= 10'b0;
end

4.2 Duty Cycle Waveform Mapping
The physical module pin output output value (pwm_out) is governed directly by a clean digital threshold relation mapping. By using only the highest bits of the timer (counter[9:2]) during structural extraction comparisons against the targeted value stored in pwm_duty, we match 8-bit granularity perfectly.
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)      pwm_out <= 0;
    else if (enable) pwm_out <= (counter[9:2] < pwm_duty);
    else             pwm_out <= 0;
end

When the configuration state tracks high, pwm_out stays at logic 1 as long as the counter bits evaluate below the register threshold. This translates to an adjustable output duty ratio spanning evenly across $0/256$ to $255/256$ width partitions.

4.3 PWM Frequency CalculationThe global core design ticks at a standard 50MHz clock rate (T_clk = 20ns). Given the 10-bit implementation scaling factor, the period bounds are derived as:

Period = 1024 * T_clk = 1024 * 20ns = 20.48μs

Frequency = 1/20.48μs ≈ 48.83kHz

This high-frequency operation ensures smooth power regulation for DC motors, as it sits well above the audible acoustic frequency limit, minimizing mechanical coil hum.
```

## 5. Software Algorithm
```

5.1 Profile Selection (Option B)
We implemented Option B: Switch-Controlled Duty Cycle. Real-world vehicle control, industrial handling machinery, and interactive robotics platforms depend heavily on human-in-the-loop interfaces. Polling physical inputs to modify electrical motor drive ratios serves as a robust proof-of-concept for industrial human-machine interfaces (HMI).

5.2 Algorithm Pseudocode  
// Memory Map Assignments
volatile int* PWM_ENABLE = (int*)0x0000009C;
volatile int* SWITCHES   = (int*)0x00000090;
volatile int* PWM_DUTY   = (int*)0x00000098;

void main() {
    // Step 1: Boot up peripheral module
    *PWM_ENABLE = 1; 
    
    int last_switch_state = -1;
    
    // Step 2: Continuous polling loop
    while(1) {
        int current_switches = *SWITCHES;
        
        // Step 3: Write to peripheral if a change is detected
        if (current_switches != last_switch_state) {
            *PWM_DUTY = current_switches;
            last_switch_state = current_switches;
        }
        
        // Step 4: Software throttling delay loop
        for (volatile int i = 0; i < 500; i++) {
            // NOP or ambient execution delay
        }
    }
}

5.3 Delay Loop Execution Rate
Pipelined CPU structures read memory data lines at rapid speeds. Running unthrottled read requests directly back-to-back creates immense power overhead on data busses. Incorporating an inner branch countdown loop stalls the main control loop for thousands of pipeline cycles between updates. This ensures the physical switch bouncing behaviors settle out naturally, safely decoupling high-speed digital core execution from low-speed macro-scale user control.
```

## 6. Reflection
6.1 Harder than Expected: Pipeline Hazard Synchronization with MMIO
Synchronizing hazard detection lines across memory-mapped boundaries proved more challenging than standard RAM design. Standard instructions expect localized registers to retain properties consistently. However, if a data hazard requires an immediate stall or a forward event right when the pipeline attempts to update an asynchronous outside peripheral address line, the timing budget narrows significantly. Ensuring that the data forwarded to the MMIO block settled early enough to satisfy the write setup time required careful structural balancing.

6.2 Future Improvement: Interrupt-Driven I/O Bridge
If more development allocation time becomes available, the system should be upgraded from a software polling scheme to an Interrupt-Driven I/O Architecture. Polling cycles occupy significant CPU resources, keeping the processor locked in a tight loop checking for switch modifications. Implementing a dedicated hardware line that asserts an interrupt request (IRQ) only when the input pins change state would allow the processor to execute other primary computational tasks in the background, entering the ISR (Interrupt Service Routine) only when a real-time duty cycle adjustment is required.