library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity n2byte_shifter is
 generic (DATA_WIDTH : natural := 32; B_WIDTH : natural := 5 );
 port (
  op_align : in  unsigned(1 downto 0); -- '00' - shift/rotate, '10' - 16-bit align, '11' - 8-bit align
  op_shift : in  std_logic; -- '0' - rotate,      '1' - shift
  op_left  : in  std_logic; -- '0' - shift right, '1' - shift left
  op_arith : in  std_logic; -- '0' - logical,     '1' - arithmetic (applicable when op_shift='1' and op_left='0')
  a        : in  unsigned(DATA_WIDTH-1 downto 0);
  rshift   : in  unsigned(B_WIDTH-1    downto 3);
  sign_pos : in  unsigned(B_WIDTH-1    downto 3);
  b_lsbits : in  boolean;   -- (b % 8) /= 0, to restore original b for use by left shifts
  result   : out unsigned(DATA_WIDTH-1 downto 0)
 );
end entity n2byte_shifter;

architecture a of n2byte_shifter is
  subtype trellis_word_t is unsigned(DATA_WIDTH-1 downto 0);
  type trellis_t is array (natural range <>) of trellis_word_t;

  signal eff_op_arith : std_logic;
  signal b         : unsigned(B_WIDTH-1 downto 3);
  constant zero_b  : unsigned(B_WIDTH-4 downto 0) := (others => '0');
begin

  b <= zero_b-rshift-1 when b_lsbits else zero_b-rshift;

  process(all)
    variable trellis : trellis_t(3 to B_WIDTH);
  begin
    eff_op_arith <= '0';
    if op_arith='1' then
      eff_op_arith <= a(to_integer(sign_pos)*8+7);
    end if;

    trellis(3) := a;
    for k in 3 to B_WIDTH-1 loop
      trellis(k+1) := trellis(k);
      if rshift(k)='1' then
        for bi in 0 to DATA_WIDTH-1 loop
          trellis(k+1)(bi) := trellis(k)(((2**k)+bi) mod DATA_WIDTH);
        end loop;
        if op_shift='1' then
          if op_left='0' then
            trellis(k+1)(DATA_WIDTH-1 downto DATA_WIDTH-(2**k)) := (others => '0');
            if eff_op_arith='1' then
              trellis(k+1)(DATA_WIDTH-1 downto DATA_WIDTH-(2**k)) := (others => '1');
            end if;
          end if;
        end if;
      end if;
      if op_shift='1' and op_left='1' and b(k)='1' then
        trellis(k+1)(DATA_WIDTH-1-(2**k) downto DATA_WIDTH-(2**(k+1))) := (others => '0');
      end if;
      if op_align(k-3)='1' then
        for kk in 1 to 2**(B_WIDTH-1-k) loop
          trellis(k+1)((2**k)*(2*kk)-1 downto (2**k)*(2*kk-1)) := (others => '0');
          if eff_op_arith='1' then
            trellis(k+1)((2**k)*(2*kk)-1 downto (2**k)*(2*kk-1)) := (others => '1');
          end if;
        end loop;
      end if;
    end loop;
    result <= trellis(B_WIDTH);
  end process;

end architecture a;
