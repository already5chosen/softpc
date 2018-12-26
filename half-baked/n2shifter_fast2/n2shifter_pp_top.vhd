library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity n2shifter_pp_top is
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
end entity n2shifter_pp_top;

architecture a of n2shifter_pp_top is
  signal aresult, abit_result, abit_result_reg : unsigned(DATA_WIDTH-1 downto 0);
  signal byte_rshift   , byte_rshift_reg  : unsigned(B_WIDTH-4 downto 0); -- right shift signal for n2byte_shifter
  signal byte_b_lsbits , byte_b_lsbits_reg: boolean;                         -- (b % 8) /= 0 for n2byte_shifter
  signal byte_op_left  , byte_op_left_reg : std_logic;                       -- op_left for n2byte_shifter
  signal op_shift_reg, op_arith_reg : std_logic;
begin
  bi:entity work.n2bit_shifter
   generic map (DATA_WIDTH => DATA_WIDTH, B_WIDTH => B_WIDTH )
   port map (
    op_shift      => op_shift, -- in std_logic; -- '0' - rotate,      '1' - shift
    op_left       => op_left , -- in std_logic; -- '0' - shift right, '1' - shift left
    op_arith      => op_arith, -- in std_logic; -- '0' - arithmetic,  '1' - logical (applicable when op_shift='1' and op_left='0')
    a             => a       , -- in  unsigned(DATA_WIDTH-1 downto 0);
    b             => b       , -- in  unsigned(B_WIDTH-1    downto 0);
    result        => abit_result  , -- out unsigned(DATA_WIDTH-1 downto 0); -- output shifted by (b % 8)
    byte_rshift   => byte_rshift  , -- out unsigned(B_WIDTH-4 downto 0);    -- right shift signal for n2byte_shifter
    byte_b_lsbits => byte_b_lsbits, -- out boolean;                         -- (b % 8) /= 0 for n2byte_shifter
    byte_op_left  => byte_op_left   -- out std_logic                        -- op_left for n2byte_shifter
   );

  by:entity work.n2byte_shifter
   generic map (DATA_WIDTH => DATA_WIDTH, B_WIDTH => B_WIDTH )
   port map (
    op_align => (others => '0')  , -- in  unsigned(1 downto 0); -- '00' - shift/rotate, '10' - 16-bit align, '11' - 8-bit align
    op_shift => op_shift_reg     , -- in  std_logic; -- '0' - rotate,      '1' - shift
    op_left  => byte_op_left_reg , -- in  std_logic; -- '0' - shift right, '1' - shift left
    op_arith => op_arith_reg     , -- in  std_logic; -- '0' - arithmetic,  '1' - logical (applicable when op_shift='1' and op_left='0')
    a        => abit_result_reg  , -- in  unsigned(DATA_WIDTH-1 downto 0);
    rshift   => byte_rshift_reg  , -- in  unsigned(B_WIDTH-1    downto 3);
    b_lsbits => byte_b_lsbits_reg, -- in  boolean;   -- (b % 8) /= 0, to restore original b for use by left shifts
    result   => aresult            -- out unsigned(DATA_WIDTH-1 downto 0)
   );

  process(clk)
  begin
    if rising_edge(clk) then
      abit_result_reg   <= abit_result;
      byte_rshift_reg   <= byte_rshift;
      byte_b_lsbits_reg <= byte_b_lsbits;
      byte_op_left_reg  <= byte_op_left;
      op_shift_reg      <= op_shift;
      op_arith_reg      <= op_arith;

      result <= aresult;
    end if;
  end process;

end architecture a;
