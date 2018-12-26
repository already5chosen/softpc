library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity nios2ee is
 generic (
   CPU_ADDR_WIDTH : natural;
   TCM_ADDR_WIDTH : natural;
   RESET_ADDR     : natural;
   TCM_REGION_IDX : natural := 0
 );
 port (
  clk               : in  std_logic;
  reset             : in  std_logic;
  -- tightly-coupled memory (both program and data). Read latency=1 clock
  tcm_rdaddress     : out std_logic_vector(TCM_ADDR_WIDTH-1 downto 2); -- 32-bit words
  tcm_wraddress     : out std_logic_vector(TCM_ADDR_WIDTH-1 downto 2); -- 32-bit words
  tcm_write         : out std_logic;
  tcm_byteenable    : out std_logic_vector(3 downto 0);
  tcm_writedata     : out std_logic_vector(31 downto 0);
  tcm_readdata      : in  unsigned(31 downto 0);
  -- avalon-mm master port (data only)
  avm_address       : out std_logic_vector(CPU_ADDR_WIDTH-1 downto 0); -- 8-bit bytes, a[1:0]=0
  avm_read          : out std_logic;
  avm_write         : out std_logic;
  avm_byteenable    : out std_logic_vector(3 downto 0);
  avm_writedata     : out std_logic_vector(31 downto 0);
  avm_readdata      : in  unsigned(31 downto 0);
  avm_waitrequest   : in  std_logic;
  avm_readdatavalid : in  std_logic
 );
end entity nios2ee;

use work.n2decode_definitions.all;
use work.nios2_opcodes.all;
use work.alu_opcodes.all;
use work.shifter_opcodes.all;
use work.memory_opcodes.all;

architecture a of nios2ee is
  -- processing phases
  constant PH_Fetch : integer := 0;
  -- Drive instruction address on tcm_rdaddress.
  -- Write result of the previous instruction into register file.
  -- Increment PC

  -- PH_Decode - encoded by separate signal
  -- Drive register file address with index of register A
  -- Latch instruction word

  constant PH_Regfile1 : integer := 1;
  -- Start to drive register file address with index of register B
  -- Latch value of register A

  constant PH_Regfile2 : integer := 2;
  -- [Optional] used by instructions with 2 register sources except for integer stores
  -- Latch value of register A

  constant PH_Execute : integer := 3;
  -- Process operands by ALU/AGU/Shifter
  -- Calculate next PC for all instruction except conditional branches

  constant PH_Branch  : integer := 4;
  -- [Optional] used only by conditional branches
  -- Calculate next PC for conditional branches

  constant PH_Memory_Address : integer := 5;
  -- [Optional] used only by memory loads and stores
  -- Drive Data address/control signals on *_address buses
  -- Drive *_writedata and *_byteenable signals for stores
  -- For Avalon-mm accesses remain at this phase until fabric de-asserts avm_waitrequest signal

  constant PH_Memory_Data : integer := 6;
  -- [Optional] used only by memory loads
  -- Align and sign or zero-extend Load data
  -- For Avalon-mm accesses remain at this phase until fabric asserts avm_readdatavalid signal

  subtype phase_t is natural range 0 to PH_Memory_Data;
  signal phase : phase_t;
  signal PH_Decode : boolean;

  subtype u32 is unsigned(31 downto 0);
  signal pc    : unsigned(31 downto 2) := to_unsigned(RESET_ADDR/4, 30);
  signal pc_msbits : unsigned(31 downto 28);

  alias instr_s1 : u32 is tcm_readdata;
  -- instruction decode signals
  signal instr_s2 : u32;
  -- alias instr_op    : unsigned(5  downto 0) is tcm_readdata( 5 downto  0);
  alias instr_imm16 : unsigned(15 downto 0) is instr_s2(21 downto  6); -- I-type
  alias instr_b     : unsigned(4  downto 0) is instr_s2(26 downto 22); -- I-type and R-type
  alias instr_a     : unsigned(4  downto 0) is instr_s1(31 downto 27); -- I-type and R-type
  -- alias instr_imm5  : unsigned(4  downto 0) is tcm_readdata(10 downto  6); -- R-type
  -- alias instr_opx   : unsigned(5  downto 0) is tcm_readdata(16 downto 11); -- R-type
  alias instr_c     : unsigned(4  downto 0) is instr_s2(21 downto 17); -- R-type
  alias instr_imm26 : unsigned(25 downto 0) is instr_s2(31 downto  6); -- J-type

  signal instr_class  : instr_class_t;
  signal srcreg_class : src_reg_class_t;
  signal dstreg_class : dest_reg_class_t;
  signal imm16_class  : imm16_class_t;
  signal fu_op_i, fu_op_reg_i : natural range 0 to 15; -- ALU, shift or memory(LSU) unit internal opcode
  signal fu_op_u, fu_op_reg_u : unsigned(3 downto 0);  -- unsigned representation of fu_op_i
  signal reg_a, reg_b : u32;
  signal immx         : u32; -- imm16 field, properly extended to 32 bits

  -- ALU/AGU
  signal alu_op : natural range 0 to 15;
  signal alu_result, alu_result_reg : u32;

  -- shifter
  signal sh_op_shift, sh_op_left, sh_op_arith, byte_op_left, bysh_op_left : std_logic;
  signal byte_b_lsbits, bysh_b_lsbits : boolean;
  signal bysh_op_align, byte_rshift, bysh_rshift : unsigned(1 downto 0);
  signal bish_result, bysh_a, sh_result : u32;

  -- register file
  type rf_t is array (natural range <>) of u32;
  signal rf : rf_t(0 to 31);
  attribute ramstyle : string;
  attribute ramstyle of rf : signal is "no_rw_check";
  signal rf_readdata : u32;
  signal rf_wraddr : natural range 0 to 31;
  signal rf_wren : boolean;

  -- register writeback data selector
  type rf_wrsel_t is (RF_WR_ALU, RF_WR_NEXTPC, RF_WR_SHIFTER);
  signal rf_wrsel : rf_wrsel_t;

  alias rf_readdata_h : unsigned(15 downto 0) is rf_readdata(15 downto 0);
  alias rf_readdata_b : unsigned(7 downto 0)  is rf_readdata(7 downto 0);

  -- memory access signals
  signal is_tcm, is_tcm_reg : boolean;
  -- store data
  signal writedata, dm_readdata : unsigned(31 downto 0);
  signal byteenable : std_logic_vector(3 downto 0);
  signal dm_address : std_logic_vector(CPU_ADDR_WIDTH-1 downto 0); -- 8-bit bytes
  signal dm_write, dm_read : std_logic;
  signal readdata_bi : natural range 0 to 3; -- byte index of LS byte of load result in dm_readdata

begin

  -- instruction decoder, results available in PH_Regfile1 stage
  d:entity work.n2decode
   port map (
    instruction  => instr_s2,     -- in  unsigned(31 downto 0);
    instr_class  => instr_class , -- out instr_class_t;
    srcreg_class => srcreg_class, -- out src_reg_class_t;
    dstreg_class => dstreg_class, -- out dest_reg_class_t;
    imm16_class  => imm16_class,  -- out imm16_class_t;
    fu_op        => fu_op_i       -- out natural range 0 to 15  -- ALU, shift or memory(LSU) unit internal opcode
   );
  fu_op_u     <= to_unsigned(fu_op_i, 4);
  fu_op_reg_u <= to_unsigned(fu_op_reg_i, 4);
  with imm16_class select
   immx <=
     unsigned(resize(signed(instr_imm16), 32)) when IMM16_CLASS_s16,
     resize(instr_imm16, 32)                   when IMM16_CLASS_z16,
     resize(instr_imm16, 32) sll 16            when others;

  -- post-decode, results available in PH_Execute stage
  process (clk)
  begin
    if rising_edge(clk) then
      -- ALU/AGU
      if instr_class=INSTR_CLASS_MEMORY then
        alu_op <= ALU_OP_ADD; -- AGU
      else
        alu_op <= fu_op_i;     -- ALU
      end if;

      -- shifter/Load alignment
      sh_op_left <= fu_op_u(SHIFTER_OP_BIT_LEFT);
      if instr_class=INSTR_CLASS_MEMORY then
        -- Load alignment
        case fu_op_i mod 4 is
          when MEM_OP_B => bysh_op_align <= "11";
          when MEM_OP_H => bysh_op_align <= "10";
          when others   => bysh_op_align <= "00";
        end case;
        bysh_rshift   <= to_unsigned(readdata_bi, 2);
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
    end if;
  end process;

  -- ALU/AGU
  a:entity work.n2alu
   generic map (DATA_WIDTH => 32)
   port map (
    op     => alu_op     , -- in  natural range 0 to 15;
    a      => reg_a      , -- in  unsigned(DATA_WIDTH-1 downto 0);
    b      => reg_b      , -- in  unsigned(DATA_WIDTH-1 downto 0);
    result => alu_result   -- out unsigned(DATA_WIDTH-1 downto 0)
   );

  -- bit shifter - the first phase of full 32-bit shifter. Shift by (b mod 8)
  bish:entity work.n2bit_shifter
   generic map (DATA_WIDTH => 32, B_WIDTH => 5 )
   port map (
    op_shift      => sh_op_shift,       -- in std_logic; -- '0' - rotate,      '1' - shift
    op_left       => sh_op_left ,       -- in std_logic; -- '0' - shift right, '1' - shift left
    op_arith      => sh_op_arith,       -- in std_logic; -- '0' - arithmetic,  '1' - logical (applicable when op_shift='1' and op_left='0')
    a             => reg_a,             -- in  unsigned(DATA_WIDTH-1 downto 0);
    b             => reg_b(4 downto 0), -- in  unsigned(B_WIDTH-1    downto 0);
    byte_rshift   => byte_rshift  ,     -- out unsigned(B_WIDTH-4 downto 0);    -- right shift signal for n2byte_shifter
    byte_b_lsbits => byte_b_lsbits,     -- out boolean;                         -- (b % 8) /= 0 for n2byte_shifter
    byte_op_left  => byte_op_left ,     -- out std_logic                        -- op_left for n2byte_shifter
    result        => bish_result        -- out unsigned(DATA_WIDTH-1 downto 0)
  );
  -- byte shifter (also used for alignment of load data)
  process (clk)
  begin
    if rising_edge(clk) then
      bysh_a <= bish_result;
      if phase = PH_Memory_Data then
         bysh_a <= dm_readdata;
      end if;
    end if;
  end process;
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
    result   => sh_result      -- out unsigned(DATA_WIDTH-1 downto 0)
  );

  process (clk, reset)
  begin
    if reset='1' then
      phase          <= PH_Fetch;
      PH_Decode      <= false;
      pc             <= to_unsigned(RESET_ADDR/4, 30);
      pc_msbits      <= (others => '0');
      alu_result_reg <= (others => '0');
      dm_write       <= '0';
      dm_read        <= '0';
      rf_wren        <= false;
      is_tcm_reg     <= false;
    elsif rising_edge(clk) then
      dm_write <= '0';
      dm_read  <= '0';
      rf_wren  <= false;

      PH_Decode <= false;
      if not PH_Decode then
        case phase is
          when PH_Fetch =>
            PH_Decode <= true;
            phase     <= PH_Regfile1;
            pc        <= pc + 1;
            pc_msbits <= pc(31 downto 28);

          when PH_Regfile1 =>
            if srcreg_class=SRC_REG_CLASS_AB and instr_b/=0 then
              phase  <= PH_Regfile2;
            else
              phase  <= PH_Execute;
            end if;

          when PH_Regfile2 =>
            phase  <= PH_Execute;

          when PH_Execute =>
            alu_result_reg <= alu_result;
            phase   <= PH_Fetch;
            rf_wren <= true;
            if instr_class=INSTR_CLASS_BRANCH then
              phase <= PH_Branch;
            elsif instr_class=INSTR_CLASS_MEMORY then
              phase <= PH_Memory_Address;
              rf_wren <= false;
              if fu_op_reg_u(MEM_OP_BIT_STORE)='1' then
                dm_write <= '1';
              else
                dm_read  <= '1';
              end if;
            elsif instr_class=INSTR_CLASS_JUMP then
              if srcreg_class=SRC_REG_CLASS_A then
                pc <= reg_a(31 downto 2);      -- indirect jumps, calls and returns
              else
                pc <= pc_msbits & instr_imm26; -- direct jumps and calls
              end if;
            end if;

          when PH_Branch =>
            if alu_result_reg(0)='1' then
              pc <= pc + reg_b(31 downto 2); -- branch taken
            end if;
            phase <= PH_Fetch;

          when PH_Memory_Address =>
            dm_write <= dm_write;
            dm_read  <= dm_read;
            is_tcm_reg <= is_tcm;
            if is_tcm or avm_waitrequest='0' then
              dm_write <= '0';
              dm_read  <= '0';
              phase    <= PH_Fetch;
              if dm_read='1' then
                -- TODO - case of avm read with latency=0
                phase  <= PH_Memory_Data;
              end if;
            end if;

          when PH_Memory_Data =>
            if is_tcm_reg or avm_readdatavalid='1' then
              rf_wren <= true;
              phase   <= PH_Fetch;
            end if;

          when others =>
            -- should never come here
            phase <= PH_Fetch;
            pc    <= to_unsigned(RESET_ADDR/4, 30);
        end case;
      end if;


    end if;
  end process;

  -- register file access
  process (clk)
    variable rf_rdaddr : natural range 0 to 31;
    variable rf_d      : u32;
  begin
    if rising_edge(clk) then

      fu_op_reg_i <= fu_op_i;
      -- register file read address
      if PH_Decode then
        rf_rdaddr := to_integer(instr_a);
        instr_s2 <= instr_s1;
      else
        rf_rdaddr := to_integer(instr_b);
        case phase is
          when PH_Regfile1 =>
            reg_a <= rf_readdata; -- latch register A
            reg_b <= immx;        -- type-I instructions except branches or shifts by immediate - the second source operand is immediate
            if srcreg_class=SRC_REG_CLASS_AB then
              reg_b <= (others => '0');
            end if;

          when PH_Regfile2 =>
            reg_b <= rf_readdata; -- latch register B

          when PH_Execute =>
            reg_b <= immx;        -- for branches

          when others =>
            null;
        end case;
      end if;

      -- register file write
      case dstreg_class is
        when DEST_REG_CLASS_CALL => rf_wraddr <= 31;                  -- ra==r31
        when DEST_REG_CLASS_B    => rf_wraddr <= to_integer(instr_b); -- r[B]
        when DEST_REG_CLASS_C    => rf_wraddr <= to_integer(instr_c); -- r[C]
        when others              => rf_wraddr <= 0;                   -- no destination register
      end case;
      case instr_class is
        when INSTR_CLASS_JUMP   => rf_wrsel <= RF_WR_NEXTPC;
        when INSTR_CLASS_SHIFT  => rf_wrsel <= RF_WR_SHIFTER;
        when INSTR_CLASS_MEMORY => rf_wrsel <= RF_WR_SHIFTER;
        when others             => rf_wrsel <= RF_WR_ALU;
      end case;
      case rf_wrsel is
        when RF_WR_NEXTPC =>
          rf_d(31 downto 2) := pc;
          rf_d(1 downto 0)  := (others => '0');
        when RF_WR_SHIFTER =>
          rf_d := sh_result;
        when others =>
          rf_d := alu_result_reg;
      end case;

      if rf_wren and rf_wraddr/=0 then
        rf(rf_wraddr) <= rf_d;
      end if;

      -- register file read
      rf_readdata <= rf(rf_rdaddr);
    end if;
  end process;

  -- data bus address/writedata/byteenable/readdata_bi
  process (all)
    variable addr : u32;
    variable bi : natural range 0 to 3;
  begin
    addr := alu_result_reg;
    bi := to_integer(addr) mod 4;
    byteenable <= (others => '0');
    case fu_op_reg_i mod 4 is
      when MEM_OP_B =>
        byteenable(bi) <= '1';
        writedata <= rf_readdata_b & rf_readdata_b & rf_readdata_b & rf_readdata_b;
        readdata_bi <= bi;

      when MEM_OP_H =>
        byteenable((bi/2)*2+0) <= '1';
        byteenable((bi/2)*2+1) <= '1';
        writedata <= rf_readdata_h & rf_readdata_h;
        readdata_bi <= (bi/2)*2;

      when others =>
        byteenable <= (others => '1');
        writedata  <= rf_readdata;
        readdata_bi <= 0;
    end case;

    dm_address(CPU_ADDR_WIDTH-1 downto 2) <= std_logic_vector(addr(CPU_ADDR_WIDTH-1 downto 2));
    dm_address(1 downto 0) <= (others => '0');

    is_tcm <= (to_integer(addr)/2**TCM_ADDR_WIDTH)=TCM_REGION_IDX;
  end process;

  tcm_rdaddress <=
    dm_address(TCM_ADDR_WIDTH-1 downto 2) when phase=PH_Memory_Address else
    std_logic_vector(pc(TCM_ADDR_WIDTH-1 downto 2));
  tcm_wraddress  <= dm_address(TCM_ADDR_WIDTH-1 downto 2);
  tcm_byteenable <= byteenable;
  tcm_writedata  <= std_logic_vector(writedata);
  tcm_write <= dm_write when is_tcm else '0';

  avm_address    <= dm_address;
  avm_byteenable <= byteenable;
  avm_writedata  <= std_logic_vector(writedata);
  avm_write      <= dm_write when not is_tcm else '0';
  avm_read       <= dm_read  when not is_tcm else '0';

  dm_readdata <= tcm_readdata when is_tcm_reg else avm_readdata;

end architecture a;
