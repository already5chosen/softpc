library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity n2register_file is
 port (
  clk         : in  std_logic;
  rdaddr      : in  natural range 0 to 31;
  wraddr      : in  natural range 0 to 31;
  wrdata      : in  unsigned(31 downto 0);
  wren        : in  boolean;
  -- read result q available on the next clock after rdaddr
  q : out unsigned(31 downto 0)
 );
end entity n2register_file;

architecture a of n2register_file is
  subtype u32 is unsigned(31 downto 0);
  type rf_t is array (natural range <>) of u32;
  signal rf : rf_t(0 to 31);

  signal rf_q, wrdata_reg : u32;
  signal rdaddr_reg : natural range 0 to 31;
  signal bypass0, bypass1 : boolean;

  attribute ramstyle : string;
  attribute ramstyle of rf : signal is "no_rw_check";
begin
  process (clk)
  begin
    if rising_edge(clk) then
      -- read
      rf_q <= rf(rdaddr);

      -- write
      if wren then
        rf(wraddr) <= wrdata;
      end if;

      -- bypass registers
      rdaddr_reg <= rdaddr; -- for 0-clock bypass
      wrdata_reg <= wrdata; -- for 1-clock bypass
      bypass1 <= wren and rdaddr=wraddr; -- for 1-clock bypass
    end if;
  end process;

  bypass0 <= wren and rdaddr_reg=wraddr;
  q <=
    wrdata     when bypass0 else -- 0-clock bypass
    wrdata_reg when bypass1 else -- 1-clock bypass
    rf_q;

end architecture a;
