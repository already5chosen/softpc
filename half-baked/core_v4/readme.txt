Variant 4.
Build for simplicity. I don't expect it to have practically useful ratio between resources and performance.
That is modification of Variant 1 that is less obsessed with clock rate.
Achievable Fmax is lower than Variants 1 or 3 or than Altera's Nios2e core, but IPC is higher.

The core is build around full-speed 32-bit ALU and shifter, but features almost no concurrency between pipeline stages.

Execution phases (They could not be called pipeline stages, because one instruction is processed
almost to the end, before the next one is started:

1. Fetch
 - Start to drive instruction address on tcm_rdaddress.
2. Decode
 - Drive register file address with index of the register A
 - Latch instruction word
 - Calculate NextPC
3. Execute1
 - Latch value of the register A
 - Start to drive register file address with index of the register B
 - For calls and NextPC - write NextPC to destination register (rA=r31 or rC)
 - Calculate branch target of taken PC-relative branches
 - Jumps and calls - reload PC and finish
 - Unconditional Branch - reload PC with NextPC and continue to Fetch+Branch phase (effectively finish)
 - The rest of instruction - reload PC with NextPC
 - ALU/Shifter instructions with immediate operand or with B=0 - Start ALU/Shifter operations, continue to Writeback/Store
 - Conditional Branches with B=0 - Start ALU operations, continue to Branch
 - Memory Loads  - Start AGU operations, continue to Load_Address
 - Memory Stores - Start AGU operations, continue to Writeback/Store
 - ALU/Shifter/CondBr with B/=0 - continue to Execute2
4. Execute2 - [Optional]
 - used by instructions that have register B as a source except for integer stores and B=0
 - Start ALU/Shifter operations
 - ALU/Shifter instructions - continue to Writeback/Store
 - Conditional Branches     - Start ALU operations, continue to Branch
5. Load_Address (Optional, used only by memory loads)
 - Drive tcm_rdaddress and avm_address/control buses
 - For Avalon-mm accesses remain at this phase until fabric de-asserts avm_waitrequest signal
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
Jumps, calls, return                            - 3
Unconditional branch                            - 3
ALU/Shifter with immediate 2nd operand          - 3
ALU/Shifter with R0 as the 2nd operand          - 3
Conditional branches with R0 as the 2nd operand - 3
NOPs (cache control instructions etc...)        - 3
TCM stores                                      - 3
AVM stores                                      - 3 + wait states (waitrequest='1')
ALU/Shifter with Rb as the 2nd operand          - 4
Conditional branches Rb as the 2nd operand      - 4
TCM loads                                       - 5
AVM loads                                       - 5 + wait states (waitrequest='1') + latency (readdatavalid='0')

Synthesis/Fitter results with Balanced target
Fmax (10CL006YE144C8G) : 101.5 MHz
Fmax (10CL006YE144C6G) : 129.7 MHz

Area (10CL006YE144C8G) : 735 LCs + 1 M9K + 0 DSPs
