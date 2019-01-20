package memory_opcodes is
  constant MEM_OP_BIT_UNS   : natural :=  2; -- not applicable to stores
  constant MEM_OP_BIT_STORE : natural :=  3;
  constant MEM_OP_B         : natural :=  0;
  constant MEM_OP_H         : natural :=  1;
  constant MEM_OP_W         : natural :=  2;
  constant MEM_OP_LDW       : natural := MEM_OP_W;
  constant MEM_OP_LDH       : natural := MEM_OP_H;
  constant MEM_OP_LDB       : natural := MEM_OP_B;
  constant MEM_OP_LDHU      : natural := MEM_OP_H + 2**MEM_OP_BIT_UNS;
  constant MEM_OP_LDBU      : natural := MEM_OP_B + 2**MEM_OP_BIT_UNS;
  constant MEM_OP_STW       : natural := MEM_OP_W + 2**MEM_OP_BIT_STORE;
  constant MEM_OP_STH       : natural := MEM_OP_H + 2**MEM_OP_BIT_STORE;
  constant MEM_OP_STB       : natural := MEM_OP_B + 2**MEM_OP_BIT_STORE;
end package memory_opcodes;
