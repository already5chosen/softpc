library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity n2alu is
 generic (DATA_WIDTH : natural := 32 );
 port (
  clk    : in std_logic;
  op     : in  unsigned(5 downto 0);
  a      : in  unsigned(DATA_WIDTH-1 downto 0);
  b      : in  unsigned(DATA_WIDTH-1 downto 0);
  result : out unsigned(DATA_WIDTH-1 downto 0)
 );
end entity n2alu;

architecture a of n2alu is
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

  function to_uns(x : boolean) return unsigned is
    variable res : unsigned(31 downto 0);
  begin
    res := (others => '0');
    if x then
      res(0) := '1';
    end if;
    return res;
  end function;

  signal aluOp, r : natural range 0 to 14;
  signal diff     : unsigned(32 downto 0);
  signal ge, eq   : boolean;
begin

  with to_integer(op) select
   aluOp <=
     ALU_OP_AND    when OPX_AND,
     ALU_OP_OR     when OPX_OR ,
     ALU_OP_XOR    when OPX_XOR,
     ALU_OP_NOR    when OPX_NOR,
     ALU_OP_ADD    when OPX_ADD,
     ALU_OP_SUB    when OPX_SUB,
     ALU_OP_CMPGE  when OPX_CMPGE ,
     ALU_OP_CMPLT  when OPX_CMPLT ,
     ALU_OP_CMPNE  when OPX_CMPNE ,
     ALU_OP_CMPEQ  when OPX_CMPEQ ,
     ALU_OP_CMPGEU when OPX_CMPGEU,
     ALU_OP_CMPLTU when OPX_CMPLTU,
     ALU_OP_AND    when others;

  process (clk)
  begin
    if rising_edge(clk) then
      r <= aluOp;
    end if;
  end process;

  diff <= resize(a, 33) - resize(b, 33);
  eq <= diff(31 downto 0) = 0;
  ge <=
    (a(31)='0'   and b(31)='1') or
    (a(31)=b(31) and diff(31)='0');
  -- with aluOp select
  with r select
   result <=
    a +   b              when ALU_OP_ADD,
    diff(31 downto 0)    when ALU_OP_SUB,
    a and b              when ALU_OP_AND,
    a or  b              when ALU_OP_OR ,
    a xor b              when ALU_OP_XOR,
    not(a or b)          when ALU_OP_NOR,
    to_uns(ge)           when ALU_OP_CMPGE,
    to_uns(not ge)       when ALU_OP_CMPLT,
    to_uns(not eq)       when ALU_OP_CMPNE,
    to_uns(eq)           when ALU_OP_CMPEQ,
    to_uns(diff(32)='0') when ALU_OP_CMPGEU,
    to_uns(diff(32)='1') when ALU_OP_CMPLTU,
    to_uns(eq)  when others;

end architecture a;
