library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity n2register_file is
 port (
  clk         : in  std_logic;
  rdaddr      : in  natural range 0 to 31;
  wraddr      : in  natural range 0 to 31;
  nextpc      : in  unsigned(31 downto 2);
  wrnextpc    : in  boolean;
  wrdata_exu  : in  unsigned(31 downto 0);
  dstreg_wren : in  boolean;
  -- read result q available on the next clock after rdaddr
  q : out unsigned(31 downto 0)
 );
end entity n2register_file;

architecture a of n2register_file is
  subtype u32 is unsigned(31 downto 0);
  type rf_t is array (natural range <>) of u32;
  signal rf : rf_t(0 to 31);
  attribute ramstyle : string;
  attribute ramstyle of rf : signal is "no_rw_check";
begin
  process (clk)
   variable wren   : boolean;
   variable wrdata : u32;
  begin
    if rising_edge(clk) then
      -- read
      q <= rf(rdaddr);

      -- write
      wren := dstreg_wren and (wraddr/=0);
      wrdata := wrdata_exu;

      if wrnextpc then
        wren := true;
        wrdata(31 downto 2) := nextpc;
        wrdata(1 downto 0)  := (others => '0');
      end if;

      if wren then
        rf(wraddr) <= wrdata;
      end if;

    end if;
  end process;

end architecture a;
