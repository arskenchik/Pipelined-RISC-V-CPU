# Pipelined-RISC-V-CPU
A clean 5-stage pipelined RISC-V CPU implemented in Verilog, featuring explicit pipeline registers, ALU, control unit, hazard detection, forwarding logic, branch handling, and memory interface support.

This project implements a clean 5-stage pipelined RISC-V CPU in Verilog. The design follows the classic instruction pipeline structure:

1. Instruction Fetch (IF)
2. Instruction Decode (ID)
3. Execute (EX)
4. Memory Access (MEM)
5. Write Back (WB)

The CPU includes explicit pipeline registers between each stage, making the datapath easier to understand, debug, and extend.

## Features

- 5-stage pipelined architecture
- IF/ID, ID/EX, EX/MEM, and MEM/WB pipeline registers
- Separate ALU module
- Control unit for instruction decoding
- Immediate generator
- Hazard detection unit
- Forwarding unit for data hazard resolution
- Load-use stall handling
- Branch and jump control with pipeline flushing
- Data memory byte-enable support
- Basic RV32I instruction support

## Supported Instruction Types

- R-type arithmetic and logic instructions
- I-type arithmetic and logic instructions
- Load instructions
- Store instructions
- Branch instructions
- JAL and JALR jump instructions

## Project Goal

The goal of this project is to provide a readable and modular RISC-V pipelined CPU implementation for learning, simulation, and further hardware design experimentation. Unlike a monolithic CPU design, this version separates the datapath into clear modules so each pipeline stage and control component can be studied independently.

## Modules

- `RISCV_TOP`
- `pipe_if_id`
- `pipe_id_ex`
- `pipe_ex_mem`
- `pipe_mem_wb`
- `control_unit`
- `imm_gen`
- `alu`
- `branch_unit`
- `hazard_unit`
- `forwarding_unit`
- `store_byte_enable`
- `load_extender`

## Notes

This implementation is intended for educational use and simulation. Depending on the memory interface used in your testbench or FPGA environment, small adjustments may be required, especially for memory write-enable polarity and address formatting.
