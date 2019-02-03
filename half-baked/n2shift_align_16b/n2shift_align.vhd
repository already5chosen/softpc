-- n2shift_align - shift/rotate or align/sign-extend load data
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.n2decode_definitions.all;

entity n2shift_align is
 port (
  clk           : in  std_logic;
  do_shift      : in  boolean;
  -- shift/rotate inputs
  sh_op_i       : in  natural range 0 to 7;  -- shift/rotate unit internal opcode
  a             : in  unsigned(22 downto 0); -- data[6:0] & data[31:16] when do_shift=true
                                             -- data[22:0] on the next clock
  b             : in  unsigned(4 downto 0);
  -- align/sign-extend load data inputs
  ld_op_i       : in  natural range 0 to 15; -- memory(LSU) unit internal opcode
  readdata      : in  unsigned(31 downto 0);
  readdata_bi   : in  unsigned(1 downto 0);  -- byte index of LS byte of load result in dm_readdata
  -- result
  result        : out unsigned(31 downto 0); -- result latency = 1 clock for align, 2 clocks for shift
  rot16         : out std_logic              -- '0' - result written to register file as is,
                                             -- '1' - result rotated by 16 before it is written to register file
 );
end entity n2shift_align;

use work.shifter_opcodes.all;
use work.memory_opcodes.all;

architecture a of n2shift_align is
  constant HALF_DATA_WIDTH : natural := a'length-7;
  constant DATA_WIDTH : natural := HALF_DATA_WIDTH*2;
  constant B_WIDTH    : natural := b'length;

  signal do_shift2 : boolean;
  signal bish_op_shift : std_logic;
  signal byte_op_left  : std_logic;
  signal bysh_op_shift, bysh_op_left, bysh_op_arith : std_logic;
  signal byte_b_lsbits, bysh_b_lsbits : boolean;
  signal bysh_op_align, byte_rshift, bysh_rshift, bysh_sign_pos : unsigned(B_WIDTH-4 downto 0);
  signal bysh_a : unsigned(DATA_WIDTH-1 downto 0);
  signal bish_result : unsigned(HALF_DATA_WIDTH-1 downto 0);
  signal sh_op_u : unsigned(2 downto 0);  -- unsigned representation of sh_op_i
  signal ld_op_u : unsigned(3 downto 0);  -- unsigned representation of ld_op_i
  alias sh_op_shift : std_logic is sh_op_u(SHIFTER_OP_BIT_SHIFT);
  alias sh_op_arith : std_logic is sh_op_u(SHIFTER_OP_BIT_ARITH);
  alias sh_op_left  : std_logic is sh_op_u(SHIFTER_OP_BIT_LEFT);
begin

  sh_op_u <= to_unsigned(sh_op_i, 3);
  ld_op_u <= to_unsigned(ld_op_i, 4);

  process (clk)
  begin
    if rising_edge(clk) then
      do_shift2 <= do_shift;
      -- shifter/Load alignment
      if not do_shift2 then
        -- Load alignment
        case ld_op_i mod 4 is
          when MEM_OP_B => bysh_op_align <= "11"; bysh_sign_pos <= readdata_bi;
          when MEM_OP_H => bysh_op_align <= "10"; bysh_sign_pos <= to_unsigned((to_integer(readdata_bi)/2)*2 + 1, B_WIDTH-3);
          when others   => bysh_op_align <= "00"; bysh_sign_pos <= to_unsigned((to_integer(readdata_bi)/2)*2 + 1, B_WIDTH-3);
        end case;
        bysh_op_shift <= '0';
        bysh_op_arith <= not ld_op_u(MEM_OP_BIT_UNS);
        bysh_b_lsbits <= false;
        bysh_op_left  <= '0';
        bysh_rshift   <= readdata_bi;
      else
        -- shift/rotate instructions
        bysh_op_align <= "00";
        bysh_op_shift <= sh_op_shift;
        bysh_op_arith <= sh_op_arith;
        bysh_b_lsbits <= byte_b_lsbits;
        bysh_op_left  <= byte_op_left;
        bysh_sign_pos <= (others => '1'); -- sign in MS byte
        bysh_rshift   <= byte_rshift;
      end if;

      -- byte shifter input mux
      if do_shift then        -- shift/rotate instructions - upper half
        bysh_a(HALF_DATA_WIDTH*2-1 downto HALF_DATA_WIDTH*1) <= bish_result;
      elsif do_shift2 then    -- shift/rotate instructions - lower half
        bysh_a(HALF_DATA_WIDTH*1-1 downto HALF_DATA_WIDTH*0) <= bish_result;
      else                    -- Load alignment
        bysh_a <= readdata;
      end if;

    end if;
  end process;

  -- bit shifter - the first phase of full 32-bit shifter. Shift by (b mod 8)
  bish_op_shift <= '0' when do_shift2 else sh_op_shift;
  bish:entity work.n2bit_shifter_hw
   generic map (DATA_WIDTH => HALF_DATA_WIDTH, B_WIDTH => 5 )
   port map (
    op_shift      => bish_op_shift, -- in std_logic; -- '0' - rotate,      '1' - shift
    op_left       => sh_op_left ,   -- in std_logic; -- '0' - shift right, '1' - shift left
    op_arith      => sh_op_arith,   -- in std_logic; -- '0' - logical,     '1' - arithmetic (applicable when op_shift='1' and op_left='0')
    a             => a,             -- in  unsigned(DATA_WIDTH+6 downto 0);
    b             => b,             -- in  unsigned(B_WIDTH-1    downto 0);
    byte_rshift   => byte_rshift  , -- out unsigned(B_WIDTH-4 downto 0);    -- right shift signal for n2byte_shifter
    byte_b_lsbits => byte_b_lsbits, -- out boolean;                         -- (b % 8) /= 0 for n2byte_shifter
    byte_op_left  => byte_op_left , -- out std_logic                        -- op_left for n2byte_shifter
    result        => bish_result    -- out unsigned(DATA_WIDTH-1 downto 0)
  );

  -- byte shifter (also used for alignment of load data)
  bysh:entity work.n2byte_shifter_hw
   -- generic map (DATA_WIDTH => DATA_WIDTH, B_WIDTH => 5 )
   port map (
    op_align => bysh_op_align, -- in  unsigned(1 downto 0); -- '00' - shift/rotate, '10' - 16-bit align, '11' - 8-bit align
    op_shift => bysh_op_shift, -- in  std_logic; -- '0' - rotate,      '1' - shift
    op_left  => bysh_op_left , -- in  std_logic; -- '0' - shift right, '1' - shift left
    op_arith => bysh_op_arith, -- in  std_logic; -- '0' - logical,     '1' - arithmetic (applicable when op_shift='1' and op_left='0')
    a        => bysh_a       , -- in  unsigned(DATA_WIDTH-1 downto 0);
    sign_pos => bysh_sign_pos, -- in  unsigned(B_WIDTH-1    downto 3);
    rshift   => bysh_rshift  , -- in  unsigned(B_WIDTH-1    downto 3);
    b_lsbits => bysh_b_lsbits, -- in  boolean;   -- (b % 8) /= 0, to restore original b for use by left shifts
    result   => result,        -- out unsigned(DATA_WIDTH-1 downto 0)
    rot16    => rot16          -- out std_logic -- '0' - result written to register file as is, '1' - result rotated by 16 before it is written to register file
  );

end architecture a;
