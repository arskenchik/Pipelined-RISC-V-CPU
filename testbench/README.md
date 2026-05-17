# 5-Stage Pipelined RISC-V CPU

This repository contains a modular 5-stage pipelined RISC-V CPU implemented in Verilog. The CPU follows the classic pipeline structure:

```text
IF -> ID -> EX -> MEM -> WB
```

The design separates the datapath and control logic into clear modules, making the CPU easier to understand, simulate, and debug.

## Features

- 5-stage pipelined CPU architecture
- Explicit pipeline registers:
  - IF/ID
  - ID/EX
  - EX/MEM
  - MEM/WB
- Separate ALU module
- Control unit
- Immediate generator
- Hazard detection unit
- Forwarding unit
- Branch and jump handling
- Data memory byte-enable support
- ModelSim simulation waveform evidence

## Main Modules

```text
RISCV_TOP
pipe_if_id
pipe_id_ex
pipe_ex_mem
pipe_mem_wb
control_unit
imm_gen
alu
branch_unit
hazard_unit
forwarding_unit
store_byte_enable
load_extender
```

## Supported Instruction Types

The implementation targets a basic RV32I-style instruction subset, including:

- R-type arithmetic and logic instructions
- I-type arithmetic and logic instructions
- Load instructions
- Store instructions
- Branch instructions
- JAL and JALR instructions

## Simulation Environment

The CPU was simulated using **ModelSim Intel FPGA Edition** with the provided Verilog testbench files.

Testbenches used:

```text
TB_RISCV_forloop.v
TB_RISCV_inst.v
TB_RISCV_sort.v
```

The testbenches load instruction streams from `.hex` files and verify the CPU output through `NUM_INST` and `OUTPUT_PORT`.

## Current Simulation Status

| Testbench | Status | Notes |
|---|---|---|
| `TB_RISCV_forloop.v` | Partially passing | Tests 1–5 pass, Test 6 currently fails due to store-address/output mismatch |
| `TB_RISCV_sort.v` | Partially passing | Similar result: reaches Test 6 and fails due to output mismatch |
| `TB_RISCV_inst.v` | Pending / under debugging | To be verified |

This project is currently under active debugging. The design simulates and shows active pipeline behavior, but full testcase completion is still in progress.

## Forloop Simulation Result

The `forloop` testcase successfully passes the first five checks before failing at Test 6.

Console output:

```text
Test # 1 has been passed
Test # 2 has been passed
Test # 3 has been passed
Test # 4 has been passed
Test # 5 has been passed
Test # 6 has been failed
output_port = 0xfe8 (Ans : 0xed8)
```

### Forloop Waveform

This waveform shows the CPU running the `forloop` testcase. It includes clock/reset, top-level outputs, pipeline instruction registers, forwarding signals, and hazard control signals.

![Forloop waveform](simulation/forloop_waveform.png)

### Forloop Console Output

This screenshot shows the partial passing result from the ModelSim transcript.

![Forloop console output](simulation/forloop_console_partial.png)

## Sort Simulation Waveform

This waveform shows the CPU running the `sort` testcase. The pipeline registers show instructions moving through the IF, ID, EX, MEM, and WB stages. The sort testcase is also currently under debugging and reaches a Test 6 failure.

![Sort waveform](simulation/sort_waveform.png)

## ModelSim Commands

Example command sequence used for simulation:

```tcl
cd C:/path/to/Lab5

vlib work
vmap work work

vlog template/Mem_Model.v
vlog template/REG_FILE.v
vlog template/RISCV_CLKRST.v
vlog template/RISCV_main.v
vlog testbench/TB_RISCV_forloop.v

vsim -voptargs=+acc work.TB_RISCV_forloop
add wave -r /*
run -all
```

Example selected waveform signals:

```tcl
add wave /TB_RISCV_forloop/CLK
add wave /TB_RISCV_forloop/RSTn
add wave -radix hex /TB_RISCV_forloop/NUM_INST
add wave -radix hex /TB_RISCV_forloop/OUTPUT_PORT
add wave -radix hex /TB_RISCV_forloop/riscv_top1/pc
add wave -radix hex /TB_RISCV_forloop/riscv_top1/if_id_inst
add wave -radix hex /TB_RISCV_forloop/riscv_top1/id_ex_inst
add wave -radix hex /TB_RISCV_forloop/riscv_top1/ex_mem_inst
add wave -radix hex /TB_RISCV_forloop/riscv_top1/mem_wb_inst
add wave -radix bin /TB_RISCV_forloop/riscv_top1/forward_a
add wave -radix bin /TB_RISCV_forloop/riscv_top1/forward_b
add wave /TB_RISCV_forloop/riscv_top1/pc_write
add wave /TB_RISCV_forloop/riscv_top1/if_id_write
add wave /TB_RISCV_forloop/riscv_top1/id_ex_flush
```

## Notes

This repository is intended as an educational pipelined CPU implementation. The current version demonstrates the main 5-stage pipeline structure, hazard handling, and forwarding logic, but additional debugging is required for complete testcase success.
