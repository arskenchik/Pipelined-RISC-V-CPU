## Simulation Results

The CPU was simulated using the provided Verilog testbenches. The testbenches load instruction streams from the hex files into instruction memory and execute the program from PC = 0x000.

The design was tested with the following programs:

| Testbench | Program | Result |
|---|---|---|
| `TB_RISCV_forloop.v` | `forloop.hex` | Passed |
| `TB_RISCV_inst.v` | `inst.hex` | Passed |
| `TB_RISCV_sort.v` | `sort.hex` | Passed |

### Waveform Verification

The waveform confirms the correct operation of the 5-stage pipeline:

- Instruction Fetch stage updates the PC every cycle unless stalled.
- IF/ID, ID/EX, EX/MEM, and MEM/WB pipeline registers transfer instructions between stages.
- Forwarding signals resolve RAW data hazards.
- Load-use hazards generate a one-cycle stall.
- Branch and jump instructions flush incorrect instructions from the pipeline.
- Register write-back updates the destination register and `OUTPUT_PORT`.

### Included Simulation Images

- Console success output
- Full pipeline waveform
- Forwarding waveform
- Load-use stall waveform
- Branch flush waveform
