library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity n2program_counter is
 generic ( RESET_ADDR : natural );
 port (
  clk         : in  std_logic;
  s_reset     : in  boolean; -- synchronous reset
  fetch       : in  boolean;
  jump        : in  boolean;
  direct_jump : in  boolean;
  branch      : in  boolean;
  branch_taken: in  boolean;
  imm26       : in  unsigned(25 downto 0);
  reg_a       : in  unsigned(31 downto 0);
  immx        : in  unsigned(31 downto 0);
  addr        : out unsigned(31 downto 2)
 );
end entity n2program_counter;

architecture a of n2program_counter is
  signal pc : unsigned(addr'range);
  signal pc_msbits : unsigned(31 downto 28);
begin
  addr <= pc;
  process (clk)
  begin
    if rising_edge(clk) then
      if fetch then
        pc <= pc + 1;
        pc_msbits <= pc(31 downto 28);
      end if;

      if jump then
        if direct_jump then
          pc <= pc_msbits & imm26;  -- direct jumps and calls
        else
          pc <= reg_a(31 downto 2); -- indirect jumps, calls and returns
        end if;
      end if;

      if branch and branch_taken then
        pc <= pc + immx(31 downto 2); -- branch taken
      end if;

      if s_reset then
        pc <= to_unsigned(RESET_ADDR, pc'length);
      end if;
    end if;
  end process;

end architecture a;
