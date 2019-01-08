library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity n2program_counter is
 generic ( RESET_ADDR : natural );
 port (
  clk           : in  std_logic;
  s_reset       : in  boolean; -- synchronous reset
  calc_nextpc   : in  boolean;
  incremet_addr : in  boolean;
  indirect_jump : in  boolean;
  direct_jump   : in  boolean;
  branch        : in  boolean;
  branch_taken  : in  boolean;
  imm26         : in  unsigned(25 downto 0);
  reg_a         : in  unsigned(31 downto 0);
  addr          : out unsigned(31 downto 2);
  nextpc        : out unsigned(31 downto 2)
 );
end entity n2program_counter;

architecture a of n2program_counter is
  signal addr_reg : unsigned(addr'range);
begin
  process (clk)
    variable immx : unsigned(31 downto 0);
  begin
    if rising_edge(clk) then

      addr_reg <= addr;

      if calc_nextpc then
        nextpc <= addr_reg + 1;
      end if;

      -- sign-extend imm16
      immx := unsigned(resize(signed(imm26(15 downto 0)), 32));

      if incremet_addr then
        addr_reg <= nextpc;
        nextpc <= nextpc + immx(nextpc'high downto 2); -- calculate address of taken branch
      end if;

      if indirect_jump then
        addr_reg <= reg_a(addr'high downto 2); -- indirect jumps, calls and returns
      end if;

      if direct_jump then
        addr_reg(27 downto 2) <= imm26;  -- direct jumps and calls
      end if;

      if s_reset then
        addr_reg <= to_unsigned(RESET_ADDR, addr'length);
      end if;
    end if;
  end process;

  addr <= nextpc when branch and branch_taken else addr_reg;

end architecture a;
