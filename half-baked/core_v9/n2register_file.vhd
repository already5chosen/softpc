library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity n2register_file is
 port (
  clk         : in  std_logic;
  rdaddr_a    : in  natural range 0 to 63;
  rdaddr_b    : in  natural range 0 to 63;
  wraddr      : in  natural range 0 to 31;
  nextpc      : in  unsigned(31 downto 2);
  wrnextpc    : in  boolean;
  wrdata0     : in  unsigned(15 downto 0);
  wraddr0_lsb : in  natural range 0 to 1;
  wrdata1     : in  unsigned(31 downto 0);
  wrdata1_rot16 : in  std_logic; -- '0' - wrdata1 written to register file as is,
                                 -- '1' - wrdata1 rotated by 16 before it is written to register file
  wrdata_sel0 : in  boolean;
  dstreg_wren : in  boolean;
  -- read result q available on the next clock after rdaddr
  q_a, q_b    : out unsigned(15 downto 0)
 );
end entity n2register_file;

architecture a of n2register_file is
  subtype u32 is unsigned(31 downto 0);
  subtype u16 is unsigned(15 downto 0);
  type rf_t is array (natural range <>) of u16;
  signal rf : rf_t(0 to 63);
  signal addr_a, addr_b : natural range 0 to 63;
  signal wren_a, wren_b : boolean;
  signal wrdata_a, wrdata_b : u16;

  attribute ramstyle : string;
  attribute ramstyle of rf : signal is "no_rw_check";
begin

  process (all)
   variable wren   : boolean;
   variable wrdata : u32;
   variable wraddr_a, wraddr_b : natural range 0 to 63;
  begin

    -- read
    addr_a <= rdaddr_a;
    addr_b <= rdaddr_b;

    -- write
    wren_a <= false;
    wren_b <= false;
    wrdata := wrdata1;
    wraddr_a := wraddr*2 + 0;
    wraddr_b := wraddr*2 + 1;
    wren := dstreg_wren and (wraddr/=0);
    if wrnextpc then
      wrdata(31 downto 2) := nextpc;
      wrdata(1 downto 0)  := (others => '0');
      wren := true;
      wren_a <= true;
      wren_b <= true;
    elsif wrdata_sel0 then
      wrdata(15 downto 0) := wrdata0;
      wraddr_a := wraddr*2 + wraddr0_lsb;
      wren_a <= wren;
    else
      if wrdata1_rot16='1' then
        wraddr_a := wraddr*2 + 1;
        wraddr_b := wraddr*2 + 0;
      end if;
      wren_a <= wren;
      wren_b <= wren;
    end if;

    if wren then
      addr_a <= wraddr_a;
      addr_b <= wraddr_b;
    end if;
    wrdata_a <= wrdata(15 downto 0);
    wrdata_b <= wrdata(31 downto 16);

  end process;


  process (clk)
  begin
    if rising_edge(clk) then
      q_a <= rf(addr_a);
      if wren_a then
        rf(addr_a) <= wrdata_a;
      end if;
    end if;
  end process;

  process (clk)
  begin
    if rising_edge(clk) then
      q_b <= rf(addr_b);
      if wren_b then
        rf(addr_b) <= wrdata_b;
      end if;
    end if;
  end process;

end architecture a;
