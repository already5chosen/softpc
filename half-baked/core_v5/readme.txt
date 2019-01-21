Variant 5.
As variants 1, 3 and 4 variant 5 is build for simplicity. As with variant 1, 3 and 4 I don't
expect it to have practically useful ratio between resources and performance.
However variants 5 is likely the most practical among the 4.
That is modification of Variant 3 that is less obsessed with clock rate.
Achievable Fmax is lower than Variants 1 or 3 or than Altera's Nios2e core, but IPC is higher.

The main difference vs variant 3 is absence of register stage between RF read and ALU/shifter.

The core is build around full-speed 32-bit ALU and shifter, but features almost no concurrency between pipeline stages.

Execution phases (They could not be called pipeline stages, because one instruction is processed
almost to the end, before the next one is started:

1. Fetch
 - Start to drive instruction address on tcm_rdaddress.
2. Decode
 - Drive register file address with indices of the registers A and B
 - Latch instruction word
 - Calculate NextPC
3. Execute
 - For calls and NextPC - write NextPC to destination register (rA=r31 or rC)
 - Calculate branch target of taken PC-relative branches
 - Jumps and calls - reload PC and finish
 - Conditional Branch - reload PC with NextPC and continue to Fetch+Branch phase (effectively finish)
 - The rest of instruction - reload PC with NextPC and continue
 - Start ALU/AGU/Shifter operations
 - Latch writedata
 - All instructions except conditional branches and memory loads continue to writeback phase
4. Load_Address (Optional, used only by memory loads)
 - Drive tcm_rdaddress and avm_address/control buses
 - For Avalon-mm accesses: remain at this phase until fabric de-asserts avm_waitrequest signal
5. Load_Data (Optional, used only by memory loads)
 - For Avalon-mm accesses: remain at this phase until fabric asserts avm_readdatavalid signal
 - For byte and half-word accesses: align and sign-extend or zero-extend Load data
6. Branch [Optional, used only by PC-relative branches]
 - Conditionally or unconditionally update PC with branch target
7. Writeback/Store
 - For ALU/Shift/Load: write result of the instruction into register file.
 - For stores: drive memory address/control/*_writedata and *_byteenable buses
 - For Avalon-mm stores: remain at this phase until fabric de-asserts avm_waitrequest signal

Writeback/Store and Branch phases of instruction overlaps with Fetch phase of the next instruction.

Cycle count:
Jumps, calls, return                     - 3
Unconditional branch                     - 3
ALU/Shifter                              - 3
NOPs (cache control instructions etc...) - 3
TCM stores                               - 3
AVM stores                               - 3 + wait states (waitrequest='1')
Conditional branches                     - 3
TCM loads                                - 5
AVM loads                                - 5 + wait states (waitrequest='1') + latency (readdatavalid='0')

Synthesis/Fitter results with Balanced target
Fmax (10CL006YE144C8G) : 101.4 MHz
Fmax (10CL006YE144C6G) : 130.8 MHz

Area (10CL006YE144C8G) : 700 LCs + 2 M9K + 0 DSPs





