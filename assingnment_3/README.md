# Class 05: Control Unit

> **Week 05 | Hanyang University ERICA Campus | Department of Robotics**  
> **Computer Architecture Course**

---

## 📚 Learning Objectives

After completing this class, you will be able to:

1. **Understand the role of the control unit**: Automatically generate all control signals from instructions
2. **Implement the Main Decoder**: Parse the instruction's `opcode` field
3. **Implement the ALU Decoder**: Determine ALU operation based on `funct` field
4. **Complete your first full single-cycle MIPS CPU**: No more manual control signals!

---

## 🧠 Key Concepts

### Position of the Control Unit

```
         ┌─────────────────────────────────────────────────────┐
         │                        CPU                          │
         │   ┌────────────────┐          ┌──────────────────┐  │
instr ──────→│  Control Unit  │─────────→│    Datapath      │  │
         │   │ (Main + ALU    │ control  │ (PC, RegFile,    │  │
         │   │  Decoder)      │ signals  │  ALU, Memory)    │  │
         │   └────────────────┘          └──────────────────┘  │
         └─────────────────────────────────────────────────────┘
```

The control unit is like the "brain within the brain" of the CPU:
- **Input**: Instruction opcode and funct fields
- **Output**: Control signals (reg_write, mem_write, alu_ctrl, etc.)

### Two-Level Decoding Architecture

```
         opcode (6-bit)          funct (6-bit)
              │                       │
              ↓                       ↓
      ┌───────────────┐       ┌───────────────┐
      │ Main Decoder  │──────→│  ALU Decoder  │
      └───────────────┘       └───────────────┘
              │                       │
              ↓                       ↓
    [reg_write, mem_write,        alu_ctrl
     branch, alu_src, ...]        (3-bit)
```

- **Main Decoder**: Determines instruction type and most control signals based on opcode
- **ALU Decoder**: Combines `alu_op` and `funct` to precisely determine ALU operation

---

## 📊 Instruction Decoding Tables

### Main Decoder Truth Table

| opcode | Instruction Type | reg_write | reg_dst | alu_src | branch | mem_write | mem_to_reg | alu_op |
|--------|------------------|-----------|---------|---------|--------|-----------|------------|--------|
| 000000 | R-Type | 1 | 1 | 0 | 0 | 0 | 0 | 10 |
| 100011 | lw | 1 | 0 | 1 | 0 | 0 | 1 | 00 |
| 101011 | sw | 0 | x | 1 | 0 | 1 | x | 00 |
| 000100 | beq | 0 | x | 0 | 1 | 0 | x | 01 |
| 001000 | addi | 1 | 0 | 1 | 0 | 0 | 0 | 00 |

### ALU Decoder Truth Table

| alu_op | funct | alu_ctrl | Operation |
|--------|-------|----------|-----------|
| 00 | xxxxxx | 010 | ADD (for lw/sw address calculation) |
| 01 | xxxxxx | 110 | SUB (for beq comparison) |
| 10 | 100000 | 010 | ADD |
| 10 | 100010 | 110 | SUB |
| 10 | 100100 | 000 | AND |
| 10 | 100101 | 001 | OR |
| 10 | 101010 | 111 | SLT |

---

## 📁 File Structure

```
class_05/
├── alu.v                   # ALU
├── alu_decoder.v           # ALU decoder ⭐
├── main_decoder.v          # Main decoder ⭐
├── control_unit.v          # Control unit top level ⭐
├── datapath.v              # Datapath
├── mips.v                  # CPU top module ⭐
├── mips_tb.v               # Testbench
├── memfile.dat             # Test program
└── Makefile
```

---

## 💻 Code Walkthrough

### 1. `main_decoder.v` - Main Decoder

```verilog
module main_decoder (
    input  wire [5:0] opcode,
    output reg        mem_to_reg, mem_write,
    output reg        branch, alu_src,
    output reg        reg_dst, reg_write,
    output reg  [1:0] alu_op
);
    always @(*) begin
        case (opcode)
            6'b000000: begin // R-Type
                reg_write = 1; reg_dst = 1; alu_src = 0;
                branch = 0; mem_write = 0; mem_to_reg = 0;
                alu_op = 2'b10;
            end
            6'b100011: begin // lw
                reg_write = 1; reg_dst = 0; alu_src = 1;
                branch = 0; mem_write = 0; mem_to_reg = 1;
                alu_op = 2'b00;
            end
            6'b101011: begin // sw
                reg_write = 0; alu_src = 1;
                branch = 0; mem_write = 1;
                alu_op = 2'b00;
            end
            6'b000100: begin // beq
                reg_write = 0; alu_src = 0;
                branch = 1; mem_write = 0;
                alu_op = 2'b01;
            end
            default: begin
                {reg_write, reg_dst, alu_src, branch, mem_write, mem_to_reg} = 6'b0;
                alu_op = 2'b00;
            end
        endcase
    end
endmodule
```

### 2. `alu_decoder.v` - ALU Decoder

```verilog
module alu_decoder (
    input  wire [1:0] alu_op,
    input  wire [5:0] funct,
    output reg  [2:0] alu_ctrl
);
    always @(*) begin
        case (alu_op)
            2'b00: alu_ctrl = 3'b010;  // ADD (lw/sw)
            2'b01: alu_ctrl = 3'b110;  // SUB (beq)
            2'b10: begin               // R-Type: check funct
                case (funct)
                    6'b100000: alu_ctrl = 3'b010;  // add
                    6'b100010: alu_ctrl = 3'b110;  // sub
                    6'b100100: alu_ctrl = 3'b000;  // and
                    6'b100101: alu_ctrl = 3'b001;  // or
                    6'b101010: alu_ctrl = 3'b111;  // slt
                    default:   alu_ctrl = 3'b010;
                endcase
            end
            default: alu_ctrl = 3'b010;
        endcase
    end
endmodule
```

### 3. `control_unit.v` - Control Unit Top Level

```verilog
module control_unit (
    input  wire [5:0] opcode,
    input  wire [5:0] funct,
    output wire       mem_to_reg, mem_write,
    output wire       branch, alu_src,
    output wire       reg_dst, reg_write,
    output wire [2:0] alu_ctrl
);
    wire [1:0] alu_op;

    main_decoder u_main (
        .opcode(opcode), .mem_to_reg(mem_to_reg), .mem_write(mem_write),
        .branch(branch), .alu_src(alu_src), .reg_dst(reg_dst),
        .reg_write(reg_write), .alu_op(alu_op)
    );

    alu_decoder u_alu (
        .alu_op(alu_op), .funct(funct), .alu_ctrl(alu_ctrl)
    );
endmodule
```

### 4. `mips.v` - CPU Top Module

```verilog
module mips (
    input  wire        clk, rst_n,
    output wire [31:0] pc_out, alu_result
);
    wire [31:0] instr;
    wire        mem_to_reg, mem_write, branch, alu_src, reg_dst, reg_write;
    wire [2:0]  alu_ctrl;

    // Control unit: automatically generate control signals from instruction
    control_unit u_ctrl (
        .opcode(instr[31:26]), .funct(instr[5:0]),
        .mem_to_reg(mem_to_reg), .mem_write(mem_write),
        .branch(branch), .alu_src(alu_src),
        .reg_dst(reg_dst), .reg_write(reg_write),
        .alu_ctrl(alu_ctrl)
    );

    // Datapath: execute instruction
    datapath u_dp (
        .clk(clk), .rst_n(rst_n),
        .reg_write_en(reg_write), .reg_dst(reg_dst), .alu_src(alu_src),
        .alu_ctrl(alu_ctrl), .mem_write_en(mem_write), .mem_to_reg(mem_to_reg),
        .pc_out(pc_out), .alu_result(alu_result),
        .instr(instr)  // Need to output instruction to control unit
    );
endmodule
```

---

## 🎯 Design Highlights

### Why Split Into Two Decoders?

1. **Main Decoder**: Only looks at opcode (6 bits), handles instruction type
2. **ALU Decoder**: Only R-Type instructions need to check the funct field

This design reduces logic complexity - a classic example of **hierarchical design**.

### `alu_op` Intermediate Encoding

| alu_op | Meaning |
|--------|---------|
| 00 | Needs ADD operation (lw/sw address calculation) |
| 01 | Needs SUB operation (beq comparison) |
| 10 | Check funct field (R-Type) |

This is an **information compression** technique that reduces Main Decoder output width.

---

## 🧪 Lab Exercise

### Step 1: Test program (`memfile.dat`)
```
20020005   // addi $v0, $zero, 5
20030003   // addi $v1, $zero, 3
00622020   // add  $a0, $v1, $v0   → $a0 = 8
00641822   // sub  $v1, $v1, $a0   → $v1 = 3 - 8 = -5
0043282A   // slt  $a1, $v0, $v1   → $a1 = (5 < -5) = 0
```

### Step 2: Run simulation
```bash
cd class_05
make
```

### Step 3: Verification
- Observe how `opcode` and `funct` change
- Verify `alu_ctrl` is correctly generated
- Confirm final register values

---

## 🔍 Think Deeper

### Question 1: How to add a new instruction?

If you want to add `ori` (OR Immediate) instruction, which modules need modification?

### Question 2: Is the control unit combinational or sequential logic?

> **Hint**: Control signals need to be generated **immediately after instruction is valid** - what problems would a one-cycle delay cause?

### Question 3: Illegal Instruction Handling

If opcode is an undefined value, how does the current code handle it? What would a real CPU do?

---

## 🏆 Milestone

> **Congratulations!** After completing this class, you have implemented a complete **single-cycle MIPS CPU**!
> 
> It can automatically:
> - Fetch instructions
> - Decode instructions
> - Execute operations
> - Access memory
> - Write back results
> 
> Next step: Transform this single-cycle CPU into a **5-stage pipelined CPU**!

---

## ✅ Checkpoint

Before moving to the next class, make sure you can answer:

- [ ] What instruction type does `opcode = 000000` represent?
- [ ] What is `alu_op` for the `lw` instruction?
- [ ] Why is `alu_ctrl` for `beq` set to SUB?

---

**Previous**: [Class 04 - Single-Cycle Datapath](../class_04/README.md)  
**Next**: [Class 06 - Pipeline Integration](../class_06/README.md)
