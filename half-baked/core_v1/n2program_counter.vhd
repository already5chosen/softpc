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
begin
  process (clk)
    variable immx : unsigned(31 downto 0);
    variable addr_reg_ex, taken_branch_addr_ex : unsigned(31 downto 2);
  begin
    if rising_edge(clk) then

      addr_reg <= addr;

      if calc_nextpc then
        nextpc <= resize(addr_reg, 30) + 1 + TCM_BASE_ADDR;
      end if;

      -- sign-extend imm16
      immx := unsigned(resize(signed(imm26(15 downto 0)), 32));

      if update_addr then
        taken_branch_addr_ex := nextpc + immx(nextpc'high downto 2); -- calculate address of taken branch
        addr_reg_ex := resize(addr_reg, 30);
        case jump_class is
          when JUMP_CLASS_DIRECT   => addr_reg_ex(27 downto 2) := imm26; -- direct jumps and calls
          when JUMP_CLASS_INDIRECT => addr_reg_ex := reg_a(31 downto 2); -- indirect jumps, calls and returns
          when JUMP_CLASS_OTHERS   => addr_reg_ex := nextpc;
        end case;
        addr_reg <= addr_reg_ex(addr'range);
        taken_branch_addr <= taken_branch_addr_ex(addr'range);
      end if;

      if s_reset then
        addr_reg <= to_unsigned((RESET_ADDR mod TCM_REGION_SZ)/4, addr'length);
      end if;
    end if;
  end process;

  addr <= taken_branch_addr(addr'range) when branch and branch_taken else addr_reg;

end architecture a;
