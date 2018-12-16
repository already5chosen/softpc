library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity n2shifter is
 generic (DATA_WIDTH : natural := 32; B_WIDTH : natural := 5 );
 port (
  op_shift : in std_logic; -- '0' - rotate,      '1' - shift
  op_left  : in std_logic; -- '0' - shift right, '1' - shift left
  op_arith : in std_logic; -- '0' - arithmetic,  '1' - logical (applicable when op_shift='1' and op_left='0')
  a        : in  unsigned(DATA_WIDTH-1 downto 0);
  b        : in  unsigned(B_WIDTH-1    downto 0);
  result   : out unsigned(DATA_WIDTH-1 downto 0)
 );
end entity n2shifter;

architecture a of n2shifter is
  subtype trellis_word_t is unsigned(DATA_WIDTH-1 downto 0);
  type trellis_t is array (natural range <>) of trellis_word_t;

  signal eff_op_left, eff_op_arith : std_logic;
  signal rshift                    : unsigned(B_WIDTH-1 downto 0);
  -- signal trellis          : trellis_t(0 to B_WIDTH);
  -- signal rr : trellis_word_t;

  constant zero_b  : unsigned(B_WIDTH-1 downto 0) := (others => '0');
  constant zeros31 : unsigned(DATA_WIDTH-2 downto 0) := (others => '0');
  constant ones31  : unsigned(DATA_WIDTH-2 downto 0) := (others => '1');
  constant zeros32 : unsigned(DATA_WIDTH-1 downto 0) := (others => '0');

  -- attribute keep : boolean;
  -- attribute keep of  trellis : signal is false;

begin

  rshift <= zero_b-b when op_left='1' else b;
  eff_op_left <= '0' when b=0 else op_left;
  eff_op_arith <= '0' when a(a'high)='0' else op_arith;

  process(all)
    variable trellis : trellis_t(0 to B_WIDTH);
  begin
    trellis(0) := a;
    for k in 0 to B_WIDTH-1 loop
      trellis(k+1) := trellis(k);
      if rshift(k)='1' then
        for bi in 0 to DATA_WIDTH-1 loop
          trellis(k+1)(bi) := trellis(k)(((2**k)+bi) mod DATA_WIDTH);
        end loop;
        if op_shift='1' then
          if eff_op_left='0' then
            trellis(k+1)(DATA_WIDTH-1 downto DATA_WIDTH-(2**k)) := (others => '0');
            if eff_op_arith='1' then
              trellis(k+1)(DATA_WIDTH-1 downto DATA_WIDTH-(2**k)) := (others => '1');
            end if;
          end if;
        end if;
      end if;
      if op_shift='1' and eff_op_left='1' and b(k)='1' then
        trellis(k+1)(DATA_WIDTH-1-(2**k) downto DATA_WIDTH-(2**(k+1))) := (others => '0');
      end if;
    end loop;
    result <= trellis(B_WIDTH);
  end process;

end architecture a;
