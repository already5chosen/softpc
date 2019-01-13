library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity n2aligner is
 port (
  ld_op  : in  natural range 0 to 7;  -- memory(LSU) unit internal opcode
  a      : in  unsigned(31 downto 0);
  bi     : in  unsigned(1  downto 0); -- byte index of LS byte of load result in a
  result : out unsigned(31 downto 0)
 );
end entity n2aligner;

use work.memory_opcodes.all;

architecture a of n2aligner is
  type bytes_arr_t is array (natural range 0 to 3) of unsigned(7 downto 0);
  signal ld_size  : natural range 0 to 3;
  signal ld_arith, sign_bit, sign_one : std_logic;
  signal eff_bi  : unsigned(1 downto 0);
  signal aa, ra  : bytes_arr_t;
begin

  ld_size  <= ld_op mod 4;
  ld_arith <= not to_unsigned(ld_op, 3)(MEM_OP_BIT_UNS);

  g_a:for k in 0 to 3 generate
    aa(k) <= a(k*8+7 downto k*8);
    result(k*8+7 downto k*8) <= ra(k);
  end generate;

  eff_bi(0) <= bi(0) when ld_size = MEM_OP_B else '0';
  eff_bi(1) <= bi(1) when ld_size < MEM_OP_W else '0';

  sign_bit <=
    aa(to_integer(bi))(7) when ld_size = MEM_OP_B else
    aa(1)(7)              when ld_size = MEM_OP_W and bi(1)='0' else
    aa(3)(7);
  sign_one <= sign_bit and ld_arith;

  ra(0) <= aa(to_integer(eff_bi));
  ra(1) <=
    (others => '1') when ld_size = MEM_OP_B and sign_one='1' else
    (others => '0') when ld_size = MEM_OP_B                  else
    aa(3)           when ld_size = MEM_OP_H and bi(1)='1'    else
    aa(1);
  ra(2) <=
    (others => '1') when ld_size < MEM_OP_W and sign_one='1' else
    (others => '0') when ld_size < MEM_OP_W                  else
    aa(2);
  ra(3) <=
    (others => '1') when ld_size < MEM_OP_W and sign_one='1' else
    (others => '0') when ld_size < MEM_OP_W                  else
    aa(3);

end architecture a;
