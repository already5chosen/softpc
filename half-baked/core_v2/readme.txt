Variant 2.
Execution phases identical to variant 1, but implementation is different.
Variant 1 uses intermediate registers in order to meet timing.
Variant 2 uses fewer registers and tries to meet timing by means of specifying multicycle paths.

It turned out that Quartus integrated synthesis and fitter poorly suited for such style of design.
Variant 2 ended up both significantly bigger and very significantly slower than variant 1.
At least, I learned something.

The core is build around full-speed 32-bit ALU and shifter, but features almost no concurrency between pipeline stages.

Execution phases (They could not be called pipeline stages, because one instruction is processed
almost to the end, before the next one is started:

1. Fetch
 - Start to drive instruction address on tcm_rdaddress.
 - Calculate NextPC
2. Decode1
 - Drive register file address with index of the register A
 - Latch instruction word
3. Regfile1
 - Latch value of the register A
 - Start to drive register file address with index of the register B
 - For calls - write NextPC to RA (R31)
 - Calculate branch target of taken PC-relative branches
 - Jumps and calls - reload PC and finish
 - Unconditional Branch - continue to Branch phase
 - The rest of instruction - reload PC with NextPC and continue
4. Regfile2 - [Optional]
 - used by instructions that have register B as a source except for integer stores and B=0
 - Latch value of register B
5. Execute
 - Start ALU/AGU/Shifter operations
 - Latch writedata
 - All instructions except conditional branches and memory loads continue to writeback phase
6. Branch [Optional, used only by PC-relative branches]
 - Conditionally or unconditionally update PC with branch target
7. Load_Address (Optional, used only by memory loads)
 - Drive tcm_rdaddress and avm_address/control buses
 - For Avalon-mm accesses remain at this phase until fabric de-asserts avm_waitrequest signal
8. Load_Data (Optional, used only by memory loads)
 - For Avalon-mm accesses: remain at this phase until fabric asserts avm_readdatavalid signal
 - For byte and half-word accesses: align and sign-extend or zero-extend Load data
 - Align and sign or zero-extend Load data
9. Writeback/Store
 - For ALU/Shift/Load: write result of the instruction into register file.
 - For stores: drive memory address/control/*_writedata and *_byteenable buses
 - For Avalon-mm stores: remain at this phase until fabric de-asserts avm_waitrequest signal

Writeback/Store and Branch phases of instruction overlaps with Fetch phase of the next instruction.

Cycle count:
Jumps, calls, return                     - 3
Unconditional branch                     - 3
ALU/Shifter with immediate 2nd operand   - 4
ALU/Shifter with R0 as the 2nd operand   - 4
NOPs (cache control instructions etc...) - 4
TCM stores                               - 4
AVM stores                               - 4 + wait states (waitrequest='1')
ALU/Shifter with Rb as the 2nd operand   - 5
Conditional branches                     - 5
TCM loads                                - 6
AVM loads                                - 6 + wait states (waitrequest='1') + latency (readdatavalid='0')

Synthesis/Fitter results with Balanced target
Fmax (10CL006YE144C8G) : 141.8 MHz
Fmax (10CL006YE144C6G) : 169.2 MHz

Area (10CL006YE144C8G) : 826 LCs + 1 M9K + 0 DSPs





