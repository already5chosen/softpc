Variant 8.
Another simple variant with minimal overlap between instruction. That's the first among my variants that has size
comparable to Altera's Nios2e. Unfortunately, performance is also comparable to Nios2e :(
Clock rate (Fmax) is approximately the same as variants 1, 3 and 6, i.e. very high. Higher than Nios2f, but somewhat slower
than Nios2e.
IPC, depending on instruction mix, is 10-15% lower than IPC of core_v1.

The core is build around true dual-ported register file with 16-bit ports. All Altera devices
that I care about implement such register file in a single embedded memory block.
Core features half speed 16-bit ALU, but the shifter is still 32-bit.
Similarly to core_v1 there is almost no concurrency between pipeline stages.

Execution phases (They could not be called pipeline stages, because one instruction is processed
almost to the end, before the next one is started:

1. Fetch
 - Calculate instruction address as combinatorial function of iu_branch, comparison result and "indirect_jump" flag
 - Drive instruction address on tcm_rdaddress.
 - Write full or half-result of the previous instruction into register file.
 - When previous instruction was store - drive memory address/control/*_writedata and *_byteenable buses
 - For Avalon-mm store accesses remain at this phase until fabric de-asserts avm_waitrequest signal
 - Proceed to Decode
2. Decode
 - Calculate NextPC (i.e. increment program counter)
 - Drive register file read addresses with indices of lower halves of registers A and B
 - Latch instruction word
 - Proceed to Regfile1
3. Regfile1
 - Latch value of lower half of register A
 - Latch value of lower half of source operand B
 - Update writedata register with lower half of register B
 - Calculate branch target of taken PC-relative branches
 - For direct jumps and calls - drive new instruction address on tcm_rdaddress and proceed to Decode
 - For direct calls - write NextPC to RA (R31)
 - For NEXTPC instruction - write NextPC to R[C] and proceed to Decode
 - For unconditional branches - set relevant branch flags and proceed to Fetch
 - For indirect jumps and calls -
 -     Drive register file read addresses with indices of both halves of registers A
 - For shift/rotate instructions -
 -     Drive register file read addresses with indices of both halves of registers A
 - For ALU/Branch/Memory instructions -
 -     Drive register file read addresses with indices of upper halves of registers A and B
 - For all instructions except direct jumps, calls, NEXTPC and unconditional branches - Proceed to Regfile2
4. Regfile2
 - For indirect jumps and calls -
 -    Latch values of both halves of registers A
 -    Set "indirect_jump" flag and proceed to Fetch
 - For indirect calls - write NextPC to RA (R31)
 - For shift/rotate instructions -
 -    Latch values of both halves of registers A
 - For ALU/Branch/Memory instructions -
 -    Process latched lower halves of operands by ALU/AGU
 -    Latch value of upper half of register A
 -    Latch value of upper half of source operand B
 -    Update writedata register with upper half of register B
 - For all instructions except indirect jumps and calls - Proceed to Execute
5. Execute
 - For shift/rotate instructions      - Process latched operands by Shifter
 - For ALU/Branch/Memory instructions - Process latched upper halves of operands by ALU/AGU
 - For ALU instructions               - write half (16 bits) of result to register file
 - For shift/rotate instructions      - Set flags for 32-bit result writeback
 - For ALU instructions               - Set flags for 16-bit result writeback
 - For conditional branches           - Set flags for branch resolution
 - For memory stores                  - Set flags for store processing
 - For all instructions except memory loads -  proceed to Fetch
 - For memory loads -  proceed to PH_Load_Address
6. Load_Address (Optional, used only by memory loads)
 - Drive tcm_rdaddress and avm_address/control buses
 - For Avalon-mm accesses remain at this phase until fabric de-asserts avm_waitrequest signal
7. Load_Data (Optional, used only by memory loads)
 - For Avalon-mm accesses: remain at this phase until fabric asserts avm_readdatavalid signal
 - For byte and half-word accesses: align and sign-extend or zero-extend Load data

Cycle count:
Direct jumps, calls                             - 2
Indirect jumps, calls, return                   - 4
Unconditional branch                            - 3
ALU/Shifter                                     - 5
Conditional branches                            - 5
NOPs (cache control instructions etc...)        - 5
TCM stores                                      - 5
AVM stores                                      - 5 + wait states (waitrequest='1')
TCM loads                                       - 7
AVM loads                                       - 7 + wait states (waitrequest='1') + latency (readdatavalid='0')

Synthesis/Fitter results with Balanced target
Fmax (10CL006YE144C8G) : 142.3 MHz
Fmax (10CL006YE144C6G) : 183.6 MHz

Area (10CL006YE144C8G) : 625 LCs + 1 M9K + 0 DSPs
