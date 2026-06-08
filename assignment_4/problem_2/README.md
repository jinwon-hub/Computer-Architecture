# Class 08: Data Forwarding

> **Week 08 | Hanyang University ERICA Campus | Department of Robotics**  
> **Computer Architecture Course**

---

## 📚 Learning Objectives

After completing this class, you will be able to:

1. **Understand data hazards**: Subsequent instructions depend on previous instruction's result
2. **Implement EX stage forwarding**: Forward data from MEM and WB stages to ALU inputs
3. **Implement ID stage forwarding**: Provide latest register values for early branch
4. **Design the Forwarding Unit**: Automatically detect and resolve data hazards

---

## 🧠 Key Concepts

### Data Hazard Example

```assembly
add $t0, $t1, $t2   # Writes to $t0 in WB stage
sub $t3, $t0, $t4   # Needs to read $t0 in ID stage
```

**Pipeline without forwarding**:

```
Cycle |   IF   |   ID   |   EX   |   MEM  |   WB
------|--------|--------|--------|--------|--------
  1   | add    |        |        |        |
  2   | sub    | add    |        |        |
  3   | ...    | sub ✗  | add    |        |     ← sub reads old value!
  4   |        | ...    | sub    | add    |
  5   |        |        | ...    | sub    | add  ← add writes here
```

**Problem**: `sub` reads `$t0` in cycle 3, but `add` doesn't write back until cycle 5!

### Core Idea of Forwarding

```
            EX Stage               MEM Stage              WB Stage
         ┌─────────┐           ┌─────────┐           ┌─────────┐
         │   sub   │←─────────←│   add   │           │         │
         │ ALU inp │ forwarding│ result  │           │         │
         └─────────┘           └─────────┘           └─────────┘
```

**Solution**: When MEM or WB stage has a just-computed result, **forward it directly** to EX stage ALU input, bypassing the register file!

---

## 📊 Forwarding Network Overview

```
                     ┌────────────────────────────────────────────┐
                     │                Forwarding Network          │
                     │                                            │
  ┌───────────────┐  │  ┌───────────────┐    ┌───────────────┐   │
  │   ID/EX Reg   │  │  │   EX/MEM Reg  │    │   MEM/WB Reg  │   │
  │  ┌─────────┐  │  │  │  ┌─────────┐  │    │  ┌─────────┐  │   │
  │  │  rd1_E  │──┼──┼─→│  │ alu_M   │──┼────┼─→│ result_W│  │   │
  │  │  rd2_E  │  │  │  │  └─────────┘  │    │  └─────────┘  │   │
  │  └─────────┘  │  │  │               │    │               │   │
  └───────────────┘  │  └───────────────┘    └───────────────┘   │
         ↓           │         │                    │            │
    ┌────────────┐   │         │                    │            │
    │    MUX     │←──┼─────────┴────────────────────┘            │
    │ (forward)  │   │         forward_a_E                       │
    └────┬───────┘   │                                           │
         ↓           │                                           │
       src_a     ───→│         ┌────────────┐                    │
                     │         │    ALU     │                    │
       src_b     ───→│        →│            │───→ alu_result_E   │
                     └─────────┴────────────┴────────────────────┘
```

---

## 💻 Code Walkthrough

### Forwarding Unit

```verilog
module forwarding_unit (
    // EX stage source registers
    input  wire [4:0] rs_E, rt_E,
    
    // MEM stage destination register
    input  wire [4:0] write_reg_M,
    input  wire       reg_write_M,
    
    // WB stage destination register
    input  wire [4:0] write_reg_W,
    input  wire       reg_write_W,
    
    // Forwarding control signals
    output reg  [1:0] forward_a_E,
    output reg  [1:0] forward_b_E
);
    always @(*) begin
        // Forward A (ALU first input)
        if (reg_write_M && write_reg_M != 0 && write_reg_M == rs_E)
            forward_a_E = 2'b10;  // Forward from MEM stage
        else if (reg_write_W && write_reg_W != 0 && write_reg_W == rs_E)
            forward_a_E = 2'b01;  // Forward from WB stage
        else
            forward_a_E = 2'b00;  // No forwarding, use register value

        // Forward B (ALU second input) - same logic
        if (reg_write_M && write_reg_M != 0 && write_reg_M == rt_E)
            forward_b_E = 2'b10;
        else if (reg_write_W && write_reg_W != 0 && write_reg_W == rt_E)
            forward_b_E = 2'b01;
        else
            forward_b_E = 2'b00;
    end
endmodule
```

### EX Stage Forwarding Multiplexers

```verilog
// In datapath.v EX stage
wire [31:0] src_a_E, src_b_E_temp, src_b_E;

// Select src_a
assign src_a_E = (forward_a_E == 2'b10) ? alu_result_M :
                 (forward_a_E == 2'b01) ? result_W     :
                 rd1_E;

// Select src_b (after forwarding, consider immediate)
assign src_b_E_temp = (forward_b_E == 2'b10) ? alu_result_M :
                      (forward_b_E == 2'b01) ? result_W     :
                      rd2_E;

assign src_b_E = (alu_src_E) ? sign_imm_E : src_b_E_temp;
```

---

## 🎯 Forwarding Control Signal Encoding

| forward_a_E | Source | Description |
|-------------|--------|-------------|
| 2'b00 | rd1_E (register file) | No hazard, normal read |
| 2'b01 | result_W (WB stage) | 2 instructions away, at WB |
| 2'b10 | alu_result_M (MEM stage) | 1 instruction away, just out of ALU |

### Priority is Important!

```assembly
add $t0, $t1, $t2   # Writes to $t0 (now in WB)
sub $t0, $t3, $t4   # Writes to $t0 (now in MEM)
and $t5, $t0, $t6   # Reads $t0 → which one to use?
```

**Answer**: Use the MEM stage value (more recent). That's why the code checks MEM first, then WB.

---

## ⚠️ Why is `write_reg != 0` Important?

```verilog
if (reg_write_M && write_reg_M != 0 && ...)
```

**Reason**: The `$zero` register is always 0. Even if an instruction writes to `$zero`, forwarding should not be triggered, or it would cause errors.

---

## 📁 File Structure

```
class_08/
├── forwarding_unit.v       # Forwarding unit ⭐
├── datapath.v              # Datapath with forwarding
├── hazard_unit.v           # Hazard unit (for stalling)
├── mips.v                  # CPU top level
└── ...
```

---

## 🧪 Lab Exercise

### Step 1: Test program (`memfile.dat`)
```
20080001   // addi $t0, $zero, 1    → $t0 = 1
20090002   // addi $t1, $zero, 2    → $t1 = 2
01095020   // add  $t2, $t0, $t1    → $t2 = 3 (needs forwarding of $t0, $t1)
012A5822   // sub  $t3, $t1, $t2    → $t3 = -1 (needs forwarding of $t2)
```

### Step 2: Run simulation
```bash
cd class_08
make
```

### Step 3: Observe waveform
- Verify `forward_a_E` and `forward_b_E` become `10` or `01` when forwarding is needed
- Verify `src_a_E` and `src_b_E` get the correct forwarded values
- Verify final register values are correct

---

## 🔍 Think Deeper

### Question 1: Load-Use Hazard

```assembly
lw  $t0, 0($t1)   # Load data from memory
add $t2, $t0, $t3 # Immediately use $t0
```

Can this situation be solved with forwarding? Why or why not?

> **Hint**: `lw` data isn't available until the end of MEM stage.

### Question 2: Forwarding Timing

Is the forwarding network combinational or sequential logic? How to prevent the forwarding path from becoming the critical path?

### Question 3: Forwarding vs Stalling

If we don't use forwarding and purely rely on stalling to solve all data hazards, how much would performance drop?

---

## ✅ Checkpoint

Before moving to the next class, make sure you can answer:

- [ ] What does `forward_a_E = 2'b10` mean?
- [ ] Why does MEM stage forwarding have priority over WB stage?
- [ ] In which situations can forwarding not solve data hazards?

---

**Previous**: [Class 07 - Early Branch Resolution](../class_07/README.md)  
**Next**: [Class 09 - Stall & Flush](../class_09/README.md)
