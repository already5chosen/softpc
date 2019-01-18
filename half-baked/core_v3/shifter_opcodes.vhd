package shifter_opcodes is
  constant SHIFTER_OP_BIT_SHIFT : natural :=  0;
  constant SHIFTER_OP_BIT_ARITH : natural :=  1;
  constant SHIFTER_OP_BIT_LEFT  : natural :=  2;
  constant SHIFTER_OP_ROR : natural := 0;
  constant SHIFTER_OP_SRL : natural := 2**SHIFTER_OP_BIT_SHIFT;
  constant SHIFTER_OP_SRA : natural := 2**SHIFTER_OP_BIT_SHIFT + 2**SHIFTER_OP_BIT_ARITH;
  constant SHIFTER_OP_ROL : natural := 2**SHIFTER_OP_BIT_LEFT;
  constant SHIFTER_OP_SLL : natural := 2**SHIFTER_OP_BIT_LEFT  + 2**SHIFTER_OP_BIT_SHIFT;
end package shifter_opcodes;
