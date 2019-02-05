-- n2bit_shifter_hw - shift/rotate half-word by 0 to 7 bits and prepare control sygnals for n2byte_shifter
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity n2bit_shifter_hw is
 generic (DATA_WIDTH : natural := 16; B_WIDTH : natural := 5 );
 port (
  op_shift      : in std_logic; -- '0' - rotate,      '1' - shift
  op_left       : in std_logic; -- '0' - shift right, '1' - shift left
  op_arith      : in std_logic; -- '0' - logical,     '1' - arithmetic (applicable when op_shift='1' and op_left='0')
  a             : in  unsigned(DATA_WIDTH+6 downto 0);
  b             : in  unsigned(B_WIDTH-1    downto 0);
  result        : out unsigned(DATA_WIDTH-1 downto 0); -- output shifted by (b % 8)
  byte_rshift   : out unsigned(B_WIDTH-4    downto 0); -- right shift signal for n2byte_shifter
  byte_b_lsbits : out boolean;               -- (b % 8) /= 0 for n2byte_shifter
  byte_op_left  : out std_logic              -- op_left for n2byte_shifter
 );
end entity n2bit_shifter_hw;

architecture a of n2bit_shifter_hw is
  subtype trellis_word_t is unsigned(a'range);
  type trellis_t is array (natural range <>) of trellis_word_t;

  signal eff_op_left, eff_op_arith : std_logic;
  signal rshift    : unsigned(B_WIDTH-1 downto 0);
  constant zero_b  : unsigned(B_WIDTH-1 downto 0) := (others => '0');
begin

  rshift <= zero_b-b when op_left='1' else b;
  eff_op_left <= '0' when b=0 else op_left;
  eff_op_arith <= '0' when a(DATA_WIDTH-1)='0' else op_arith;

  process(all)
    variable trellis : trellis_t(0 to 3);
    variable out_w : natural range DATA_WIDTH to DATA_WIDTH+3;
  begin
    trellis(3) := a;
    for k in 2 downto 0 loop
      out_w := DATA_WIDTH + 2**k - 1;
      trellis(k)(out_w-1 downto 0) := trellis(k+1)(out_w-1 downto 0);
      if rshift(k)='1' then
        for bi in 0 to out_w-1 loop
          trellis(k)(bi) := trellis(k+1)((2**k)+bi);
        end loop;
        if op_shift='1' then
          if eff_op_left='0' then
            trellis(k)(DATA_WIDTH-1 downto DATA_WIDTH-(2**k)) := (others => '0');
            if eff_op_arith='1' then
              trellis(k)(DATA_WIDTH-1 downto DATA_WIDTH-(2**k)) := (others => '1');
            end if;
          end if;
        end if;
      end if;
      if op_shift='1' and eff_op_left='1' and b(k)='1' then
        if rshift(k)='0' then
          -- [15:12], [11:10], [9:9]
          trellis(k)(DATA_WIDTH-9+(2**(k+1)) downto DATA_WIDTH-8+(2**k)) := (others => '0');
        else
          -- [11:8], [9:8], [8:8]
          trellis(k)(DATA_WIDTH-9+(2**k) downto DATA_WIDTH-8) := (others => '0');
        end if;
      end if;
    end loop;
    result <= trellis(0)(DATA_WIDTH-1 downto 0);
  end process;

  byte_rshift   <= rshift(B_WIDTH-1 downto 3);
  byte_b_lsbits <= b(2 downto 0)/=0;
  byte_op_left  <= eff_op_left;

end architecture a;
