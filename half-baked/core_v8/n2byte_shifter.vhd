library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity n2byte_shifter is
 port (
  op_align : in  unsigned(1 downto 0); -- '00' - shift/rotate, '10' - 16-bit align, '11' - 8-bit align
  op_shift : in  std_logic; -- '0' - rotate,      '1' - shift
  op_left  : in  std_logic; -- '0' - shift right, '1' - shift left
  op_arith : in  std_logic; -- '0' - logical,     '1' - arithmetic (applicable when op_shift='1' and op_left='0')
  a        : in  unsigned(31 downto 0);
  rshift   : in  unsigned(4 downto 3);
  sign_pos : in  unsigned(4 downto 3);
  b_lsbits : in  boolean;   -- (b % 8) /= 0, to restore original b for use by left shifts
  result   : out unsigned(31 downto 0);
  rot16    : out std_logic -- '0' - result written to register file as is, '1' - result rotated by 16 before it is written to register file
 );
end entity n2byte_shifter;

architecture a of n2byte_shifter is
  constant DATA_WIDTH : natural := 32;
  constant B_WIDTH    : natural := 5;
  subtype sel_t is natural range 0 to 3;
  type sel_arr_t is array (natural range <>) of sel_t;
  signal sel : sel_arr_t(0 to 3);

  signal eff_op_arith : std_logic;
  signal b         : unsigned(B_WIDTH-1 downto 3);
  constant zero_b  : unsigned(B_WIDTH-4 downto 0) := (others => '0');
begin

  b <= zero_b-rshift-1 when b_lsbits else zero_b-rshift;

  process(all)
    variable sx   : natural range 2 to 3;
    variable bval : unsigned(7 downto 0);
    variable k1   : natural range 0 to 3;
  begin
    eff_op_arith <= '0';
    if op_arith='1' then
      eff_op_arith <= a(to_integer(sign_pos)*8+7);
    end if;
    sx := 2;
    if eff_op_arith='1' then
      sx := 3;
    end if;

    rot16 <= rshift(4);
    if    op_align(1)='0' then -- shift/rotate
      sel <= (others => 0);
      if rshift(3)='1' then
        sel <= (others => 1);
      end if;
      if op_shift='1' then
        if op_left='0' then -- rigth shift
          if rshift(3)='1' then
            sel(3) <= sx;
          end if;
          if rshift(4)='1' then
            sel(0) <= sx;
            sel(1) <= sx;
          end if;
        else                -- left shift
          if b=3 then
            sel(0) <= 2;
            sel(1) <= 2;
            sel(2) <= 2;
          elsif b=2 then
            if rshift(4)='0' then
              sel(0) <= 2;
              sel(1) <= 2;
            else
              sel(2) <= 2;
              sel(3) <= 2;
            end if;
          elsif b=1 then
            sel(2) <= 2;
          end if;
        end if;
      end if;
    elsif op_align(0)='0' then -- 16-bit align
      if rshift(4)='0' then
        sel <= (0=>0, 1=>0, 2=>sx, 3=>sx);
      else
        sel <= (0=>sx, 1=>sx, 2=>0, 3=>0);
      end if;
    else                       -- 8-bit align
      sel <= (others => sx);
      if rshift(4)='0' then
        sel(0) <= to_integer(rshift) mod 2;
      else
        sel(2) <= to_integer(rshift) mod 2;
      end if;
    end if;

    for k0 in 0 to 3 loop
      k1 := (k0 + 1) mod 4;
      case sel(k0) is
        when 0 => bval := a(8*k0+7 downto 8*k0);
        when 1 => bval := a(8*k1+7 downto 8*k1);
        when 2 => bval := (others => '0');
        when 3 => bval := (others => '1');
      end case;
      result(8*k0+7 downto 8*k0) <= bval;
    end loop;

  end process;

end architecture a;
