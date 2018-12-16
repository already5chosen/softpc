package nios2_opcodes is
  -- top-level opcodes
  constant OP_CALL    : natural := 0*16+0; -- J-TYPE
  constant OP_JMPI    : natural := 0*16+1; -- J-TYPE
  constant OP_02      : natural := 0*16+2;
  constant OP_LDBU    : natural := 0*16+3;
  constant OP_ADDI    : natural := 0*16+4;
  constant OP_STB     : natural := 0*16+5;
  constant OP_BR      : natural := 0*16+6;
  constant OP_LDB     : natural := 0*16+7;
  constant OP_CMPGE   : natural := 0*16+8;
  constant OP_09      : natural := 0*16+9;
  constant OP_0A      : natural := 0*16+10;
  constant OP_LDHU    : natural := 0*16+11;
  constant OP_ANDI    : natural := 0*16+12;
  constant OP_STH     : natural := 0*16+13;
  constant OP_BGE     : natural := 0*16+14;
  constant OP_LDH     : natural := 0*16+15;

  constant OP_CMPLTI  : natural := 1*16+0;
  constant OP_11      : natural := 1*16+1;
  constant OP_12      : natural := 1*16+2;
  constant OP_INITDA  : natural := 1*16+3;
  constant OP_ORI     : natural := 1*16+4;
  constant OP_STW     : natural := 1*16+5;
  constant OP_BLT     : natural := 1*16+6;
  constant OP_LDW     : natural := 1*16+7;
  constant OP_CMPNEI  : natural := 1*16+8;
  constant OP_19      : natural := 1*16+9;
  constant OP_1A      : natural := 1*16+10;
  constant OP_FLUSHDA : natural := 1*16+11;
  constant OP_XORI    : natural := 1*16+12;
  constant OP_1D      : natural := 1*16+13;
  constant OP_BNE     : natural := 1*16+14;
  constant OP_1F      : natural := 1*16+15;

  constant OP_CMPEQI  : natural := 2*16+0;
  constant OP_21      : natural := 2*16+1;
  constant OP_22      : natural := 2*16+2;
  constant OP_LDBUIO  : natural := 2*16+3;
  constant OP_MULI    : natural := 2*16+4;
  constant OP_STBIO   : natural := 2*16+5;
  constant OP_BEQ     : natural := 2*16+6;
  constant OP_LDBIO   : natural := 2*16+7;
  constant OP_CMPGEUI : natural := 2*16+8;
  constant OP_29      : natural := 2*16+9;
  constant OP_2A      : natural := 2*16+10;
  constant OP_LDHUIO  : natural := 2*16+11;
  constant OP_ANDHI   : natural := 2*16+12;
  constant OP_STHIO   : natural := 2*16+13;
  constant OP_BGEU    : natural := 2*16+14;
  constant OP_LDHIO   : natural := 2*16+15;

  constant OP_CMPLTUI : natural := 3*16+0;
  constant OP_31      : natural := 3*16+1;
  constant OP_CUSTOM  : natural := 3*16+2;
  constant OP_INITD   : natural := 3*16+3;
  constant OP_ORHI    : natural := 3*16+4;
  constant OP_STWIO   : natural := 3*16+5;
  constant OP_BLTU    : natural := 3*16+6;
  constant OP_LDWIO   : natural := 3*16+7;
  constant OP_RDPRS   : natural := 3*16+8;
  constant OP_39      : natural := 3*16+9;
  constant OP_RTYPE   : natural := 3*16+10;
  constant OP_FLUSHD  : natural := 3*16+11;
  constant OP_XORHI   : natural := 3*16+12;
  constant OP_3D      : natural := 3*16+13;
  constant OP_3E      : natural := 3*16+14;
  constant OP_3F      : natural := 3*16+15;

  -- R-TYPE instructions eXtended opcode (6 MS-bits)
  constant OPX_00     : natural := 0*16+0;
  constant OPX_ERET   : natural := 0*16+1;
  constant OPX_ROLI   : natural := 0*16+2;
  constant OPX_ROL    : natural := 0*16+3;
  constant OPX_FLUSHP : natural := 0*16+4;
  constant OPX_RET    : natural := 0*16+5;
  constant OPX_NOR    : natural := 0*16+6;
  constant OPX_MULXUU : natural := 0*16+7;
  constant OPX_CMPGE  : natural := 0*16+8;
  constant OPX_BRET   : natural := 0*16+9;
  constant OPX_0A     : natural := 0*16+10;
  constant OPX_ROR    : natural := 0*16+11;
  constant OPX_FLUSHI : natural := 0*16+12;
  constant OPX_JMP    : natural := 0*16+13;
  constant OPX_AND    : natural := 0*16+14;
  constant OPX_0F     : natural := 0*16+15;

  constant OPX_CMPLT  : natural := 1*16+0;
  constant OPX_11     : natural := 1*16+1;
  constant OPX_SLLI   : natural := 1*16+2;
  constant OPX_SLL    : natural := 1*16+3;
  constant OPX_WRPRS  : natural := 1*16+4;
  constant OPX_15     : natural := 1*16+5;
  constant OPX_OR     : natural := 1*16+6;
  constant OPX_MULXSU : natural := 1*16+7;
  constant OPX_CMPNE  : natural := 1*16+8;
  constant OPX_19     : natural := 1*16+9;
  constant OPX_SRLI   : natural := 1*16+10;
  constant OPX_SRL    : natural := 1*16+11;
  constant OPX_NEXTPC : natural := 1*16+12;
  constant OPX_CALLR  : natural := 1*16+13;
  constant OPX_XOR    : natural := 1*16+14;
  constant OPX_MULXSS : natural := 1*16+15;

  constant OPX_CMPEQ  : natural := 2*16+0;
  constant OPX_21     : natural := 2*16+1;
  constant OPX_22     : natural := 2*16+2;
  constant OPX_23     : natural := 2*16+3;
  constant OPX_DIVU   : natural := 2*16+4;
  constant OPX_DIV    : natural := 2*16+5;
  constant OPX_RDCTL  : natural := 2*16+6;
  constant OPX_MUL    : natural := 2*16+7;
  constant OPX_CMPGEU : natural := 2*16+8;
  constant OPX_INITI  : natural := 2*16+9;
  constant OPX_2A     : natural := 2*16+10;
  constant OPX_2B     : natural := 2*16+11;
  constant OPX_2C     : natural := 2*16+12;
  constant OPX_TRAP   : natural := 2*16+13;
  constant OPX_WRCTL  : natural := 2*16+14;
  constant OPX_2F     : natural := 2*16+15;

  constant OPX_CMPLTU : natural := 3*16+0;
  constant OPX_ADD    : natural := 3*16+1;
  constant OPX_32     : natural := 3*16+2;
  constant OPX_33     : natural := 3*16+3;
  constant OPX_BREAK  : natural := 3*16+4;
  constant OPX_35     : natural := 3*16+5;
  constant OPX_SYNC   : natural := 3*16+6;
  constant OPX_37     : natural := 3*16+7;
  constant OPX_38     : natural := 3*16+8;
  constant OPX_SUB    : natural := 3*16+9;
  constant OPX_SRAI   : natural := 3*16+10;
  constant OPX_SRA    : natural := 3*16+11;
  constant OPX_3C     : natural := 3*16+12;
  constant OPX_3D     : natural := 3*16+13;
  constant OPX_3E     : natural := 3*16+14;
  constant OPX_3F     : natural := 3*16+15;

end package nios2_opcodes;