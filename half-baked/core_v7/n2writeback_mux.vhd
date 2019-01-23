library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity n2writeback_mux is
 port (
  wraddr      : in  natural range 0 to 31;
  nextpc      : in  unsigned(31 downto 2);
  wrnextpc    : in  boolean;
  wrdata0     : in  unsigned(31 downto 0);
  wrdata1     : in  unsigned(31 downto 0);
  wrdata_sel0 : in  boolean;
  dstreg_wren : in  boolean;
  wrdata      : out unsigned(31 downto 0);
  wren        : out boolean
 );
end entity n2writeback_mux;

architecture a of n2writeback_mux is
begin
  process (all)
  begin
    if wrnextpc then
      wrdata(31 downto 2) <= nextpc;
      wrdata(1 downto 0)  <= (others => '0');
    elsif wrdata_sel0 then
      wrdata <= wrdata0;
    else
      wrdata <= wrdata1;
    end if;
  end process;
  wren <= (wraddr /= 0) and (wrnextpc or dstreg_wren);
end architecture a;
