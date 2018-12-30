-- n2shift_align - shift/rotate or align/sign-extend load data
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.n2decode_definitions.all;

entity n2shift_align is
 port (
  clk           : in  std_logic;
  instr_class   : in  instr_class_t;
  fu_op_i       : in  natural range 0 to 15; -- ALU, shift or memory(LSU) unit internal opcode
  -- shift/rotate inputs
  a             : in  unsigned;
  b             : in  unsigned;
  -- align/sign-extend load data inputs
  readdata      : in  unsigned;
  readdata_bi   : in  unsigned; -- byte index of LS byte of load result in dm_readdata
  readdatavalid : in  boolean;
  -- result
  result        : out unsigned  -- result latency = 1 clock
 );
end entity n2shift_align;

use work.shifter_opcodes.all;
use work.memory_opcodes.all;

architecture a of n2shift_align is
  constant DATA_WIDTH : natural := a'length;
  constant B_WIDTH    : natural := b'length;

  signal sh_op_shift, sh_op_left, sh_op_arith, byte_op_left, bysh_op_left : std_logic;
  signal byte_b_lsbits, bysh_b_lsbits : boolean;
  signal bysh_op_align, byte_rshift, bysh_rshift : unsigned(B_WIDTH-4 downto 0);
  signal bish_result, bysh_a : unsigned(a'range);
begin

  process (clk)
    variable fu_op_u : unsigned(3 downto 0);  -- unsigned representation of fu_op_i
  begin
    if rising_edge(clk) then
      -- post-decode, results available in PH_Execute stage
      -- shifter/Load alignment
      fu_op_u := to_unsigned(fu_op_i, 4);
      sh_op_left <= fu_op_u(SHIFTER_OP_BIT_LEFT);
      if instr_class=INSTR_CLASS_MEMORY then
        -- Load alignment
        case fu_op_i mod 4 is
          when MEM_OP_B => bysh_op_align <= "11";
          when MEM_OP_H => bysh_op_align <= "10";
          when others   => bysh_op_align <= "00";
        end case;
        bysh_rshift   <= readdata_bi;
        sh_op_shift   <= '0';
        sh_op_arith   <= fu_op_u(MEM_OP_BIT_UNS);
        bysh_b_lsbits <= false;
        bysh_op_left  <= '0';
      else
        -- shift/rotate instructions
        bysh_op_align <= "00";
        bysh_rshift   <= byte_rshift;
        sh_op_shift   <= fu_op_u(SHIFTER_OP_BIT_SHIFT);
        sh_op_arith   <= fu_op_u(SHIFTER_OP_BIT_ARITH);
        bysh_b_lsbits <= byte_b_lsbits;
        bysh_op_left  <= byte_op_left;
      end if;

      -- byte shifter input mux
      bysh_a <= bish_result;
      if readdatavalid then
         bysh_a <= readdata;
      end if;

    end if;
  end process;

  -- bit shifter - the first phase of full 32-bit shifter. Shift by (b mod 8)
  bish:entity work.n2bit_shifter
   generic map (DATA_WIDTH => 32, B_WIDTH => 5 )
   port map (
    op_shift      => sh_op_shift,   -- in std_logic; -- '0' - rotate,      '1' - shift
    op_left       => sh_op_left ,   -- in std_logic; -- '0' - shift right, '1' - shift left
    op_arith      => sh_op_arith,   -- in std_logic; -- '0' - arithmetic,  '1' - logical (applicable when op_shift='1' and op_left='0')
    a             => a,             -- in  unsigned(DATA_WIDTH-1 downto 0);
    b             => b,             -- in  unsigned(B_WIDTH-1    downto 0);
    byte_rshift   => byte_rshift  , -- out unsigned(B_WIDTH-4 downto 0);    -- right shift signal for n2byte_shifter
    byte_b_lsbits => byte_b_lsbits, -- out boolean;                         -- (b % 8) /= 0 for n2byte_shifter
    byte_op_left  => byte_op_left , -- out std_logic                        -- op_left for n2byte_shifter
    result        => bish_result    -- out unsigned(DATA_WIDTH-1 downto 0)
  );

  -- byte shifter (also used for alignment of load data)
  bysh:entity work.n2byte_shifter
   generic map (DATA_WIDTH => 32, B_WIDTH => 5 )
   port map (
    op_align => bysh_op_align, -- in  unsigned(1 downto 0); -- '00' - shift/rotate, '10' - 16-bit align, '11' - 8-bit align
    op_shift => sh_op_shift  , -- in  std_logic; -- '0' - rotate,      '1' - shift
    op_left  => bysh_op_left , -- in  std_logic; -- '0' - shift right, '1' - shift left
    op_arith => sh_op_arith  , -- in  std_logic; -- '0' - arithmetic,  '1' - logical (applicable when op_shift='1' and op_left='0')
    a        => bysh_a       , -- in  unsigned(DATA_WIDTH-1 downto 0);
    rshift   => bysh_rshift  , -- in  unsigned(B_WIDTH-1    downto 3);
    b_lsbits => bysh_b_lsbits, -- in  boolean;   -- (b % 8) /= 0, to restore original b for use by left shifts
    result   => result         -- out unsigned(DATA_WIDTH-1 downto 0)
  );

end architecture a;