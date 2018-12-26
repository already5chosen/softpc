library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity n2alu is
 generic (DATA_WIDTH : natural);
 port (
  clk        : in  std_logic;
  start      : in  boolean;
  op         : in  natural range 0 to 15;
  a          : in  unsigned(DATA_WIDTH-1 downto 0);
  b          : in  unsigned(DATA_WIDTH-1 downto 0);
  -- results are available on the next clock after start
  result     : out unsigned(DATA_WIDTH-1 downto 0);
  agu_result : out unsigned(DATA_WIDTH-1 downto 0); -- available on the next clock after start
  cmp_result : buffer boolean                       -- for branches
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

  signal op_reg   : natural range 0 to 15;
  signal diff     : unsigned(DATA_WIDTH downto 0);
  signal ge, eq   : boolean;
  signal aresult, aresult_reg : word_t;
  signal msb_a, msb_b : std_logic;
begin

  with op select
   aresult <=
    a and b     when ALU_OP_AND,
    a or  b     when ALU_OP_OR ,
    a xor b     when ALU_OP_XOR,
    not(a or b) when ALU_OP_NOR,
    a +   b     when others;

  eq <= diff(31 downto 0) = 0;
  ge <= -- signed comparison
    (msb_a='0'   and msb_b='1') or
    (msb_a=msb_b and diff(31)='0');
  with op_reg mod 8 select
   cmp_result <=
    ge           when ALU_OP_CMPGE  mod 8,
    not ge       when ALU_OP_CMPLT  mod 8,
    not eq       when ALU_OP_CMPNE  mod 8,
    eq           when ALU_OP_CMPEQ  mod 8,
    diff(32)='0' when ALU_OP_CMPGEU mod 8,
    diff(32)='1' when ALU_OP_CMPLTU mod 8,
    true         when others;

  process (clk)
  begin
    if rising_edge(clk) then
      if start then
        op_reg <= op;
        aresult_reg <= aresult;
        diff  <= resize(a, 33) - resize(b, 33);
        msb_a <= a(a'high);
        msb_b <= b(b'high);
      end if;
    end if;
  end process;

  agu_result <= aresult_reg;
  result <=
    aresult_reg       when op_reg < ALU_OP_SUB else
    diff(31 downto 0) when op_reg = ALU_OP_SUB else
    to_uns(cmp_result);

end architecture a;
