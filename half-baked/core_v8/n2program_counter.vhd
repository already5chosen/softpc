library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.n2decode_definitions.all;

entity n2program_counter is
 generic (
   TCM_ADDR_WIDTH : natural;
   RESET_ADDR     : natural;
   TCM_REGION_IDX : natural
 );
 port (
  clk           : in  std_logic;
  s_reset       : in  boolean; -- synchronous reset
  calc_nextpc   : in  boolean;
  update_addr   : in  boolean;
  jump_class    : in  jump_class_t;
  branch        : in  boolean;
  branch_taken  : in  boolean;
  imm26         : in  unsigned(25 downto 0);
  reg_a         : in  unsigned(31 downto 0);
  addr          : out unsigned(TCM_ADDR_WIDTH-1 downto 2);
  nextpc        : out unsigned(31 downto 2)
 );
end entity n2program_counter;

architecture a of n2program_counter is
  constant TCM_REGION_SZ : natural := 2**TCM_ADDR_WIDTH;
  constant TCM_BASE_ADDR : natural := (TCM_REGION_SZ/4)*TCM_REGION_IDX;
  signal addr_reg, taken_branch_addr : unsigned(addr'range);
  signal indirect_jump : boolean;
  signal addr_reg_ex, direct_jump_target : unsigned(nextpc'range);
begin
  addr_reg_ex <= resize(addr_reg, nextpc'length) + TCM_BASE_ADDR;
  process (clk)
    variable immx : unsigned(31 downto 0);
    variable taken_branch_addr_ex : unsigned(nextpc'range);
  begin
    if rising_edge(clk) then

      addr_reg <= addr;
      indirect_jump <= false;

      if calc_nextpc then
        addr_reg <= addr_reg + 1;
      end if;

      -- sign-extend imm16
      immx := unsigned(resize(signed(imm26(15 downto 0)), 32));

      if update_addr then
        taken_branch_addr_ex := addr_reg_ex + immx(nextpc'high downto 2); -- calculate address of taken branch
        taken_branch_addr <= taken_branch_addr_ex(addr'range);
        indirect_jump <= jump_class=JUMP_CLASS_INDIRECT;   -- indirect jumps, calls and returns
      end if;

      if s_reset then
        addr_reg <= to_unsigned((RESET_ADDR mod TCM_REGION_SZ)/4, addr'length);
        indirect_jump <= false;
      end if;
    end if;
  end process;

  direct_jump_target <= addr_reg_ex(addr_reg_ex'high downto 28) & imm26; -- direct jumps and calls
            -- for sake of brevity ignore cases when direct jump/call
            -- is a last instruction of 256MB segment
  addr <=
    direct_jump_target(addr'range)when update_addr and jump_class=JUMP_CLASS_DIRECT else
    reg_a(addr'range)             when indirect_jump else
    taken_branch_addr(addr'range) when branch and branch_taken else
    addr_reg;

  nextpc <= resize(addr_reg, nextpc'length) + TCM_BASE_ADDR;

end architecture a;
