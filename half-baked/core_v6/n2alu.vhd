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
  signal cmp_op_reg : natural range 0 to 7;
  signal ge, eq   : boolean;
  signal logic_r  : word_t;
  signal addsub_r : unsigned(DATA_WIDTH downto 0);
  signal msb_a, msb_b : std_logic;
  signal ne_bytes : unsigned(DATA_WIDTH/8-1 downto 0);
begin

  process (clk)
   variable logic_op : natural range 0 to 3;
  begin
    if rising_edge(clk) then
      if start then

        logic_op := op mod 4;
        case logic_op is
          when ALU_OP_AND mod 4 => logic_r <= a and b;
          when ALU_OP_OR  mod 4 => logic_r <= a or  b;
          when ALU_OP_XOR mod 4 => logic_r <= a xor b;
          when ALU_OP_NOR mod 4 => logic_r <= not(a or b);
        end case;

        if op < ALU_OP_SUB then
          addsub_r <= resize(a, DATA_WIDTH+1) + resize(b, DATA_WIDTH+1);
        else
          addsub_r <= resize(a, DATA_WIDTH+1) - resize(b, DATA_WIDTH+1);
        end if;

        op_reg <= op;
        msb_a <= a(a'high);
        msb_b <= b(b'high);

        for k in 0 to DATA_WIDTH/8-1 loop
          if a(k*8+7 downto k*8) = b(k*8+7 downto k*8) then
            ne_bytes(k) <= '0';
          else
            ne_bytes(k) <= '1';
          end if;
        end loop;

      end if;
    end if;
  end process;

  eq <= ne_bytes = 0;
  ge <= -- signed comparison
    (msb_a='0'   and msb_b='1') or
    (msb_a=msb_b and addsub_r(DATA_WIDTH-1)='0');
  cmp_op_reg <= op_reg mod 8;

  with cmp_op_reg select
   cmp_result <=
    ge                       when ALU_OP_CMPGE  mod 8,
    not ge                   when ALU_OP_CMPLT  mod 8,
    not eq                   when ALU_OP_CMPNE  mod 8,
    eq                       when ALU_OP_CMPEQ  mod 8,
    addsub_r(DATA_WIDTH)='0' when ALU_OP_CMPGEU mod 8,
    addsub_r(DATA_WIDTH)='1' when ALU_OP_CMPLTU mod 8,
    addsub_r(0)='1'          when others;

  agu_result <= addsub_r(DATA_WIDTH-1 downto 0);
  result <=
    logic_r            when op_reg < ALU_OP_ADD else
    to_uns(cmp_result) when op_reg > ALU_OP_SUB else
    agu_result;

end architecture a;
