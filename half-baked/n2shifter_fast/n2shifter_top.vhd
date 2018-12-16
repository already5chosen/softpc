library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity n2shifter_top is
 generic (DATA_WIDTH : natural := 32; B_WIDTH : natural := 5 );
 port (
  clk      : in std_logic;
  op_shift : in std_logic; -- '0' - rotate,      '1' - shift
  op_left  : in std_logic; -- '0' - shift right, '1' - shift left
  op_arith : in std_logic; -- '0' - arithmetic,  '1' - logical (applicable when op_shift='1' and op_left='0')
  a        : in  unsigned(DATA_WIDTH-1 downto 0);
  b        : in  unsigned(B_WIDTH-1    downto 0);
  result   : out unsigned(DATA_WIDTH-1 downto 0)
 );
end entity n2shifter_top;

architecture a of n2shifter_top is
  signal aresult : unsigned(DATA_WIDTH-1 downto 0);
begin
  c:entity work.n2shifter
   generic map (DATA_WIDTH => DATA_WIDTH, B_WIDTH => B_WIDTH )
   port map (
    op_shift => op_shift, -- in std_logic; -- '0' - rotate,      '1' - shift
    op_left  => op_left , -- in std_logic; -- '0' - shift right, '1' - shift left
    op_arith => op_arith, -- in std_logic; -- '0' - arithmetic,  '1' - logical (applicable when op_shift='1' and op_left='0')
    a        => a       , -- in  unsigned(DATA_WIDTH-1 downto 0);
    b        => b       , -- in  unsigned(B_WIDTH-1    downto 0);
    result   => aresult   -- out unsigned(DATA_WIDTH-1 downto 0)
   );
  
  process(clk)
  begin
    if rising_edge(clk) then
      result <= aresult;
    end if;
  end process;

end architecture a;
