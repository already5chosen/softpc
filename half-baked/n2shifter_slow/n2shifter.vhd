library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity n2shifter is
 generic (DATA_WIDTH : natural := 32; B_WIDTH : natural := 5 );
 port (
  clk      : in  std_logic;
  start    : in  std_logic;
  op_shift : in  std_logic; -- '0' - rotate,      '1' - shift
  op_left  : in  std_logic; -- '0' - shift right, '1' - shift left
  op_arith : in  std_logic; -- '0' - arithmetic,  '1' - logical (applicable when op_shift='1' and op_left='0')
  a        : in  unsigned(DATA_WIDTH-1 downto 0);
  b        : in  unsigned(B_WIDTH-1    downto 0);
  result   : out unsigned(DATA_WIDTH-1 downto 0);
  rvalid   : out std_logic
 );
end entity n2shifter;

architecture a of n2shifter is
  signal bi : natural range 0 to 31;
begin

  process (clk)
  begin
    if rising_edge(clk) then
      if op_left='0' then
        result <= result ror 1;
        if op_shift='1' then
          if op_arith='0' then
            result(31) <= '0';
          else
            result(31) <= result(31);
          end if;
        end if;
      else
        result <= result rol 1;
        if op_shift='1' then
          result(0) <= '1';
        end if;
      end if;

      rvalid <= '0';
      if bi /= 0 then
        bi <= bi - 1;
        if bi = 1 then
          rvalid <= '1';
        end if;
      end if;
      if start='1' then
        result <= a;
        bi     <= to_integer(b);
        if b=0 then
          rvalid <= '1';
        end if;
      end if;
    end if;
  end process;

end architecture a;
