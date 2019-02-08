library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity n2alu_halfwidth is
 generic (DATA_WIDTH : natural);
 port (
  clk        : in  std_logic;
  start      : in  boolean;
  op         : in  natural range 0 to 15;
  a          : in  unsigned(DATA_WIDTH/2-1 downto 0);
  b          : in  unsigned(DATA_WIDTH/2-1 downto 0);
  -- results
  result     : out unsigned(DATA_WIDTH/2-1 downto 0); -- first half available on the next clock after start
  result_a0  : out natural range 0 to 1;              -- 0 - lower half of result, 1 - upper half of result
  agu_result : out unsigned(DATA_WIDTH-1 downto 0);   -- available 2 clocks after start
  cmp_result : buffer boolean                         -- for branches, available 2 clocks after start
 );
end entity n2alu_halfwidth;

use work.alu_opcodes.all;

architecture a of n2alu_halfwidth is
  subtype halfword_t is unsigned(DATA_WIDTH/2-1 downto 0);
  subtype word_t is unsigned(DATA_WIDTH-1 downto 0);
  function to_uns(x : boolean) return unsigned is
    variable res : halfword_t;
  begin
    res := (others => '0');
    if x then
      res(0) := '1';
    end if;
    return res;
  end function;

  signal start2   : boolean;
  signal op_reg   : natural range 0 to 15;
  signal cmp_op_reg : natural range 0 to 7;
  signal ge, eq   : boolean;
  signal logic_r  : halfword_t;
  signal addsub_r : unsigned(DATA_WIDTH/2 downto 0);
  signal msb_a, msb_b : std_logic;
  signal eq_l, eq_h : boolean;
  alias  addsub_w   : halfword_t is addsub_r(addsub_r'high-1 downto 0);
  alias  addsub_msb : std_logic is addsub_r(addsub_r'high);
begin

  process (clk)
   variable logic_op : natural range 0 to 3;
   variable addsub_a, addsub_b : unsigned(DATA_WIDTH/2 downto 0);
   variable carry : natural range 0 to 1;
   variable is_add : boolean;
  begin
    if rising_edge(clk) then
      start2 <= start;

      if start then
        op_reg <= op;
      end if;

      if start or start2 then

        logic_op := op mod 4;
        if start2 then
          logic_op := op_reg mod 4;
        end if;

        case logic_op is
          when ALU_OP_AND mod 4 => logic_r <= a and b;
          when ALU_OP_OR  mod 4 => logic_r <= a or  b;
          when ALU_OP_XOR mod 4 => logic_r <= a xor b;
          when ALU_OP_NOR mod 4 => logic_r <= not(a or b);
        end case;

        addsub_a := resize(a, DATA_WIDTH/2+1);
        addsub_b := resize(b, DATA_WIDTH/2+1);

        carry := 0;
        if start2 and addsub_msb='1' then
          carry := 1;
        end if;

        is_add := op < ALU_OP_SUB;
        if start2 then
          is_add := op_reg < ALU_OP_SUB;
        end if;

        if is_add then
          addsub_r <= addsub_a + addsub_b + carry;
        else
          addsub_r <= addsub_a - addsub_b - carry;
        end if;

        msb_a <= a(a'high);
        msb_b <= b(b'high);
      end if;

      result_a0 <= 0;
      if start and op > ALU_OP_SUB then
        result_a0 <= 1; -- comparison: upper half of results first
      end if;
      if start2 then
        result_a0 <= 1 - result_a0;
      end if;

      eq_l <= eq_h; -- comparison for equal

      if start2 then
        -- latch lower half of AGU result
        agu_result(DATA_WIDTH/2-1 downto 0) <= addsub_w;
      end if;

    end if;
  end process;

  eq_h <= addsub_w = 0; -- comparison for equal
  eq <= eq_h and eq_l;
  ge <= -- signed comparison
    (msb_a='0'   and msb_b='1') or
    (msb_a=msb_b and addsub_r(DATA_WIDTH/2-1)='0');

  cmp_op_reg <= op_reg mod 8;
  with cmp_op_reg select
   cmp_result <=
    ge              when ALU_OP_CMPGE  mod 8,
    not ge          when ALU_OP_CMPLT  mod 8,
    not eq          when ALU_OP_CMPNE  mod 8,
    eq              when ALU_OP_CMPEQ  mod 8,
    addsub_msb='0'  when ALU_OP_CMPGEU mod 8,
    addsub_msb='1'  when ALU_OP_CMPLTU mod 8,
    addsub_r(0)='1' when others;

  agu_result(DATA_WIDTH-1 downto DATA_WIDTH/2) <= addsub_w;
  result <=
    logic_r            when op_reg < ALU_OP_ADD else
    addsub_w           when op_reg <= ALU_OP_SUB else
    to_uns(cmp_result) when result_a0=0 else
    (others => '0');  -- upper half of comparison result

end architecture a;
