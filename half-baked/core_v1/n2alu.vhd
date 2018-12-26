library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity n2alu is
 generic (DATA_WIDTH : natural);
 port (
  clk    : in  std_logic;
  start  : in  boolean;
  op     : in  natural range 0 to 15;
  a      : in  unsigned(DATA_WIDTH-1 downto 0);
  b      : in  unsigned(DATA_WIDTH-1 downto 0);
  result : out unsigned(DATA_WIDTH-1 downto 0) -- available on the next clock after start
 );
end entity n2alu;

use work.alu_opcodes.all;

architecture a of n2alu is
  subtype word_t is unsigned(DATA_WIDTH-1 downto 0);
  function to_uns(x : boolean) return unsigned is
    variable res : word_t;
  begin
    res := (others => '0');
    if x then
      res(0) := '1';
    end if;
    return res;
  end function;

  signal aluOp    : natural range 0 to 14;
  signal diff     : unsigned(DATA_WIDTH downto 0);
  signal ge, eq   : boolean;
  signal aresult  : word_t;
begin

  diff <= resize(a, 33) - resize(b, 33);
  eq <= diff(31 downto 0) = 0;
  ge <=
    (a(31)='0'   and b(31)='1') or
    (a(31)=b(31) and diff(31)='0');
  with op select
   aresult <=
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
    to_uns(true)         when others;

  process (clk)
  begin
    if rising_edge(clk) then
      if start then
        result <= aresult;
      end if;
    end if;
  end process;

end architecture a;
