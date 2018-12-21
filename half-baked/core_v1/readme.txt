Variant 1.
Build for simplicity. I don't expect it to have practically useful ratio between resources and performance.
The only thing that it will likely be good is a clock rate.

The core is build around full-speed 32-bit ALU and shifter, but features almost no concurrency between pipeline stages.

Execution phases (They could not be called pipeline stages, because one instruction is processed
almost to the end, before the next one is started:

0. Fetch/WB
 - Start driving instruction address on tcm_address.
 - Write result of the previous instruction into register file.
1. Decode1
 - drive register file address with index of the first source register
2. Decode2 (Optional, used only by instructions with 2 register sources)
 - drive register file address with index of the second source register
 - latch value of the first source register
3. Execute
 - Process operands by ALU/AGU/Shifter
 - Calculate next PC for all instruction except conditional branches
4. Branch (Optional, used only by conditional branches)
 - Calculate next PC for conditional branches
5. Memory Address (Optional, used only by memory loads and stores)
 - Drive Data address/control signals on *_address buses
 - Drive *_writedata and *_byteenable signals for stores
 - Avalon-mm accesses remain at this stage until fabric de-asserts avm_waitrequest signal
6. Align (Optional, used only by memory loads)
 - Align and sign or zero-extend Load data
 - Avalon-mm accesses remain at this stage until fabric asserts avm_readdatavalid signal



