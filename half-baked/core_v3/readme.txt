Variant 3.
As variant 1, variant 3 is build for simplicity. As with variant 1, I don't
expect it to have practically useful ratio between resources and performance.
The only thing that it will likely be good is a clock rate.

The main difference vs variant 1 is use of register file with 2 32-bit read ports.
It means that on majority (or all) of Altera device families it will occupy 2 embedded
memory blocks instead of one. On a plus side, this variant will be 15% faster on average
and hopefully will require fewer LEs.

The core is build around full-speed 32-bit ALU and shifter, but features almost no concurrency between pipeline stages.

Execution phases (They could not be called pipeline stages, because one instruction is processed
almost to the end, before the next one is started:

1. Fetch
 - Start to drive instruction address on tcm_rdaddress.
2. Decode
 - Drive register file address with indices of the registers A and B
 - Latch instruction word
 - Calculate NextPC
3. Regfile
 - Latch value of the register A
 - Latch the second ALU/AGU/shifter input - either value of the register B or immediate operand
 - For calls and NextPC - write NextPC to destination register (rA=r31 or rC)
 - Calculate branch target of taken PC-relative branches
 - Jumps and calls - reload PC and finish
 - Unconditional Branch - reload PC with NextPC and continue to Fetch+Branch phase (effectively finish)
 - The rest of instruction - reload PC with NextPC and continue
4. Execute
 - Start ALU/AGU/Shifter operations
 - Latch writedata
 - All instructions except conditional branches and memory loads continue to writeback phase
5. Load_Address (Optional, used only by memory loads)
 - Drive tcm_rdaddress and avm_address/control buses
 - For Avalon-mm accesses: remain at this phase until fabric de-asserts avm_waitrequest signal
6. Load_Data (Optional, used only by memory loads)
 - For Avalon-mm accesses: remain at this phase until fabric asserts avm_readdatavalid signal
 - For byte and half-word accesses: align and sign-extend or zero-extend Load data
7. Branch [Optional, used only by PC-relative branches]
 - Conditionally or unconditionally update PC with branch target
8. Writeback/Store
 - For ALU/Shift/Load: write result of the instruction into register file.
 - For stores: drive memory address/control/*_writedata and *_byteenable buses
 - For Avalon-mm stores: remain at this phase until fabric de-asserts avm_waitrequest signal

Writeback/Store and Branch phases of instruction overlaps with Fetch phase of the next instruction.

Cycle count:
Jumps, calls, return                     - 3
Unconditional branch                     - 3
ALU/Shifter                              - 4
NOPs (cache control instructions etc...) - 4
TCM stores                               - 4
AVM stores                               - 4 + wait states (waitrequest='1')
Conditional branches                     - 4
TCM loads                                - 6
AVM loads                                - 6 + wait states (waitrequest='1') + latency (readdatavalid='0')

Synthesis/Fitter results with Balanced target
Fmax (10CL006YE144C8G) : 140.4 MHz
Fmax (10CL006YE144C6G) : 181.7 MHz

Area (10CL006YE144C8G) : 712 LCs + 2 M9K + 0 DSPs





