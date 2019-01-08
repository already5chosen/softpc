library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity n2alu is
 generic (DATA_WIDTH : natural);
 port (
  op         : in  natural range 0 to 15;
  a          : in  unsigned(DATA_WIDTH-1 downto 0);
  b          : in  unsigned(DATA_WIDTH-1 downto 0);
  result     : out unsigned(DATA_WIDTH-1 downto 0);
  agu_result : out unsigned(DATA_WIDTH-1 downto 0);
  cmp_result : buffer boolean
 );
end entity n2alu;

use work.alu_opcodes.all;

architecture a of n2alu is
  subtype word_t is unsigned(DATA_WIDTH-1 downto 0);
begin

  process (all)
   variable logic_op : natural range 0 to 3;
   variable logic_r  : word_t;
   variable addsub_r : unsigned(DATA_WIDTH downto 0);
   variable cmp_op   : natural range 0 to 7;
   variable msb_a, msb_b : std_logic;
   variable ge, eq, cmp_res : boolean;
  begin

    logic_op := op mod 4;
    case logic_op is
      when ALU_OP_AND mod 4 => logic_r := a and b;
      when ALU_OP_OR  mod 4 => logic_r := a or  b;
      when ALU_OP_XOR mod 4 => logic_r := a xor b;
      when ALU_OP_NOR mod 4 => logic_r := not(a or b);
    end case;

    if op < ALU_OP_SUB then
      addsub_r := resize(a, DATA_WIDTH+1) + resize(b, DATA_WIDTH+1);
    else
      addsub_r := resize(a, DATA_WIDTH+1) - resize(b, DATA_WIDTH+1);
    end if;

    msb_a := a(a'high);
    msb_b := b(b'high);

    eq := addsub_r(DATA_WIDTH-1 downto 0) = 0;
    ge := -- signed comparison
      (msb_a='0'   and msb_b='1') or
      (msb_a=msb_b and addsub_r(DATA_WIDTH-1)='0');

    cmp_op := op mod 8;
    case cmp_op is
      when ALU_OP_CMPGE  mod 8 => cmp_res := ge;
      when ALU_OP_CMPLT  mod 8 => cmp_res := not ge;
      when ALU_OP_CMPNE  mod 8 => cmp_res := not eq;
      when ALU_OP_CMPEQ  mod 8 => cmp_res := eq;
      when ALU_OP_CMPGEU mod 8 => cmp_res := addsub_r(DATA_WIDTH)='0';
      when ALU_OP_CMPLTU mod 8 => cmp_res := addsub_r(DATA_WIDTH)='1';
      when others              => cmp_res := addsub_r(0)='1';
    end case;

    cmp_result <= cmp_res;
    agu_result <= addsub_r(DATA_WIDTH-1 downto 0);

    if op < ALU_OP_ADD then
      -- logicals
      result <= logic_r;
    elsif op <= ALU_OP_SUB then
      -- add/sub
      result <= addsub_r(DATA_WIDTH-1 downto 0);
    else
      -- comparisons
      result <= (others => '0');
      if cmp_res then
        result(0) <= '1';
      end if;
    end if;

  end process;

end architecture a;
