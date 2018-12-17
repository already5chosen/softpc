package alu_opcodes is
  constant ALU_OP_AND     : natural :=  0;
  constant ALU_OP_OR      : natural :=  1;
  constant ALU_OP_XOR     : natural :=  2;
  constant ALU_OP_NOR     : natural :=  3;
  constant ALU_OP_ADD     : natural :=  4;
  constant ALU_OP_SUB     : natural :=  8;
  constant ALU_OP_CMPGE   : natural :=  9;
  constant ALU_OP_CMPLT   : natural := 10;
  constant ALU_OP_CMPNE   : natural := 11;
  constant ALU_OP_CMPEQ   : natural := 12;
  constant ALU_OP_CMPGEU  : natural := 13;
  constant ALU_OP_CMPLTU  : natural := 14;
  constant ALU_OP_TRUE    : natural := 15; -- for BR instruction
end package alu_opcodes;
