# Class 07: Early Branch Resolution

> **Week 07 | Hanyang University ERICA Campus | Department of Robotics**  
> **Computer Architecture Course**

---

## 📚 Learning Objectives

After completing this class, you will be able to:

1. **Understand control hazards**: How branch instructions disrupt sequential pipeline execution
2. **Implement early branch resolution**: Move branch decision from EX stage to ID stage
3. **Design branch flush mechanism**: Clear incorrect instructions when mispredicted
4. **Reduce branch penalty from 3 cycles to 1 cycle**

---

## 🧠 Key Concepts

### The Control Hazard Problem

**Scenario**: When executing `beq $t0, $t1, target`:

```
Cycle | IF        | ID        | EX        | MEM       | WB
------|-----------|-----------|-----------|-----------|-------
  1   | beq       |           |           |           |
  2   | add(next) | beq       |           |           |
  3   | sub(next) | add       | beq←judge |           |
  4   | ???       | sub       | add       | beq       |
```

**Problem**: We don't know whether to branch until cycle 3, but we've already fetched 2 potentially wrong instructions!

### Core Idea of Early Branch

Move branch decision **to ID stage**:

```
Cycle | IF        | ID        | EX        | MEM       | WB
------|-----------|-----------|-----------|-----------|-------
  1   | beq       |           |           |           |
  2   | add(next) | beq←judge |           |           |
  3   | target?   | [flush!]  | beq       |           |
```

- **Earlier decision**: Compare two registers in ID stage
- **Reduced penalty**: Only need to flush 1 instruction (in IF/ID register)

### Early Comparison Circuit

```
              ┌─────────────────────────┐
              │        ID Stage         │
              │   ┌───────────────┐     │
   rd1_D ────→│───│  Comparator   │     │
              │   │   (A == B?)   │────→│──→ equal_D
   rd2_D ────→│───│               │     │
              │   └───────────────┘     │
              │                         │
              │   pc_src_D = branch_D   │
              │                & equal_D│
              └─────────────────────────┘
                         │
                         ↓
                   ┌───────────┐
             ┌────→│    MUX    │────→ pc_next
             │     └───────────┘
             │           ↑
    pc_plus4_F    pc_branch_D (target)
```

---

## 📊 Branch Target Address Calculation

```verilog
// Branch target = PC + 4 + (sign_imm << 2)
assign pc_branch_D = pc_plus4_D + (sign_imm_D << 2);
```

**Why `pc_plus4_D` instead of `pc_D`?**

MIPS branch offset is calculated relative to the **next instruction**, so we use PC+4.

### Example:

```assembly
0x0010: beq $t0, $t1, 3      # Offset of 3 instructions
0x0014: add ...              # PC+4 = 0x14
0x0018: sub ...
0x001C: ...
0x0020: target:              # 0x14 + (3 << 2) = 0x14 + 12 = 0x20 ✓
```

---

## 📁 File Structure

```
class_07/
├── datapath.v              # Datapath with early branch ⭐
├── hazard_unit.v           # Hazard detection (basic version)
├── control_unit.v          # Control unit
├── mips.v                  # CPU top level
└── ...
```

---

## 💻 Code Walkthrough

### 1. ID Stage Comparison Logic

```verilog
// In datapath.v ID stage
wire equal_D;
assign equal_D = (rd1_D == rd2_D);

// Branch decision
wire pc_src_D;
assign pc_src_D = branch_D & equal_D;

// Branch target address
wire [31:0] pc_branch_D;
assign pc_branch_D = pc_plus4_D + (sign_imm_D << 2);
```

### 2. PC Multiplexer

```verilog
// IF stage
assign pc_next_F = (pc_src_D)  ? pc_branch_D :
                   (jump_D)    ? jump_addr_D :
                   pc_plus4_F;
```

### 3. IF/ID Flush on Branch

```verilog
// IF/ID pipeline register
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        instr_D_reg <= 32'b0;
        pc_plus4_D  <= 32'b0;
    end else if (pc_src_D || jump_D) begin
        // Branch or jump taken, clear next instruction
        instr_D_reg <= 32'b0;  // NOP
        pc_plus4_D  <= 32'b0;
    end else begin
        instr_D_reg <= instr_F;
        pc_plus4_D  <= pc_plus4_F;
    end
end
```

---

## ⚠️ New Problem: Branch Data Hazard

Moving comparison to ID stage creates a new problem:

```assembly
add $t0, $t1, $t2   # Writes to $t0 (in WB stage)
beq $t0, $t3, done  # Reads $t0 in ID stage → Data not written back yet!
```

**Solution 1**: ID stage forwarding
```verilog
wire [31:0] src_a_D, src_b_D;
assign src_a_D = (forward_a_D == 2'b10) ? alu_result_M :
                 (forward_a_D == 2'b01) ? result_W     : rd1_D;
```

**Solution 2**: Stall and wait
When the previous instruction is `lw`, must stall (detailed in next class).

---

## 🎯 Design Highlights

### Branch Penalty Comparison

| Method | Decision Timing | Penalty Cycles | Performance |
|--------|----------------|----------------|-------------|
| EX stage decision | Cycle 3 | 2 cycles | Lower |
| ID stage decision | Cycle 2 | **1 cycle** | ⭐ Higher |
| Branch prediction | Cycle 1 | 0~N cycles | Depends on prediction accuracy |

### BEQ vs BNE

```verilog
// BNE (Branch if Not Equal) support
wire bne_D;
assign bne_D = (opcode_D == 6'b000101);  // BNE opcode

assign pc_src_D = branch_D & (bne_D ? ~equal_D : equal_D);
```

---

## 🧪 Lab Exercise

### Step 1: Test program (`memfile.dat`)
```
20080005   // addi $t0, $zero, 5
20090005   // addi $t1, $zero, 5
1109FFFD   // beq  $t0, $t1, -3 (jump back to 1st instruction)
200A0099   // addi $t2, $zero, 0x99 (skipped)
```

### Step 2: Run simulation
```bash
cd class_07
make
```

### Step 3: Observe waveform
- Verify `equal_D` is 1 when comparison is equal
- Verify when `pc_src_D` triggers, next cycle PC jumps to target
- Verify IF/ID instruction is flushed to NOP

---

## 🔍 Think Deeper

### Question 1: Delay Slot

Traditional MIPS uses "delay slot": the instruction after a branch is always executed. How is this implemented? What are the pros and cons?

### Question 2: Branch Prediction vs Early Resolution

Modern CPUs use complex branch predictors. Compared to our "early resolution", what are the pros and cons of each?

### Question 3: Loop Performance

If a loop executes 100 times, each iteration has a `beq` jumping back to the loop start. Using 1-cycle penalty vs 2-cycle penalty, how much is the performance difference?

---

## ✅ Checkpoint

Before moving to the next class, make sure you can answer:

- [ ] Why does putting branch decision in ID stage reduce penalty?
- [ ] What is the formula for branch target address?
- [ ] When `beq` doesn't branch, what is `pc_next`?

---

**Previous**: [Class 06 - Pipeline Integration](../class_06/README.md)  
**Next**: [Class 08 - Data Forwarding](../class_08/README.md)
