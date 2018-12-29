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
  signal s_reset : boolean := true;
  -- processing phases
  signal PH_Fetch : boolean;
  -- Drive instruction address on tcm_rdaddress.
  -- Write result of the previous instruction into register file.
  -- Increment PC

  signal PH_Decode : boolean;
  -- Drive register file address with index of register A
  -- Latch instruction word

  signal PH_Regfile1 : boolean;
  -- Start to drive register file address with index of register B
  -- Latch value of register A

  signal PH_Regfile2 : boolean;
  -- [Optional] used by instructions with 2 register sources except for integer stores
  -- Latch value of register A

  signal PH_Execute : boolean;
  -- Process operands by ALU/AGU/Shifter
  -- Calculate next PC for all instruction except conditional branches

  signal PH_Branch  : boolean;
  -- [Optional] used only by conditional branches
  -- Calculate next PC for conditional branches

  signal PH_Memory_Address : boolean;
  -- [Optional] used only by memory loads and stores
  -- Drive Data address/control signals on *_address buses
  -- Drive *_writedata and *_byteenable signals for stores
  -- For Avalon-mm accesses remain at this phase until fabric de-asserts avm_waitrequest signal

  signal PH_Memory_Data : boolean;
  -- [Optional] used only by memory loads
  -- Align and sign or zero-extend Load data
  -- For Avalon-mm accesses remain at this phase until fabric asserts avm_readdatavalid signal

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

  signal r_type, writeback_ex, is_call, is_next_pc : boolean;
  signal instr_class  : instr_class_t;
  signal srcreg_class : src_reg_class_t;
  signal imm16_class  : imm16_class_t;
  signal fu_op_i, fu_op_reg_i : natural range 0 to 15; -- ALU, shift or memory(LSU) unit internal opcode
  signal fu_op_u, fu_op_reg_u : unsigned(3 downto 0);  -- unsigned representation of fu_op_i
  signal reg_a, reg_b : u32;
  signal immx         : u32; -- imm16 field, properly extended to 32 bits

  -- ALU/AGU
  signal alu_op : natural range 0 to 15;
  signal alu_result, agu_result : u32;
  signal cmp_result : boolean; -- for branches

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
  signal dstreg_wren, result_sel_alu : boolean;

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

  process (clk, reset)
  begin
    if reset='1' then
      s_reset <= true;
    elsif rising_edge(clk) then
      s_reset <= false;
    end if;
  end process;

  -- instruction decoder, results available in PH_Regfile1 stage
  d:entity work.n2decode
   port map (
    clk          => clk,          -- in  std_logic;
    start        => PH_Decode,    -- in  boolean;
    instruction  => instr_s1,     -- in  unsigned(31 downto 0);
    -- decode results are available on the next clock after start
    r_type       => r_type,       -- buffer boolean;
    instr_class  => instr_class , -- out instr_class_t;
    srcreg_class => srcreg_class, -- out src_reg_class_t;
    writeback_ex => writeback_ex, -- out boolean; -- true when destination register is updated with result of PH_execute stage
    is_call      => is_call,      -- out boolean;
    is_next_pc   => is_next_pc,   -- out boolean;
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
    clk    => clk        , -- in  std_logic;
    start  => PH_Execute , -- in  boolean;
    op     => alu_op     , -- in  natural range 0 to 15;
    a      => reg_a      , -- in  unsigned(DATA_WIDTH-1 downto 0);
    b      => reg_b      , -- in  unsigned(DATA_WIDTH-1 downto 0);
    -- results are available on the next clock after start
    result     => alu_result, -- out unsigned(DATA_WIDTH-1 downto 0)
    agu_result => agu_result, -- out unsigned(DATA_WIDTH-1 downto 0)
    cmp_result => cmp_result  -- buffer boolean -- for branches
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
      if PH_Memory_Data then
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
    if rising_edge(clk) then
      dm_write <= '0';
      dm_read  <= '0';
      dstreg_wren <= false;

      PH_Fetch          <= false;
      PH_Decode         <= false;
      PH_Regfile1       <= false;
      PH_Regfile2       <= false;
      PH_Execute        <= false;
      PH_Branch         <= false;
      PH_Memory_Address <= false;
      PH_Memory_Data    <= false;

      if s_reset then
        PH_Fetch <= true;
        pc       <= to_unsigned(RESET_ADDR/4, 30);
      else
        if PH_Fetch then
          pc        <= pc + 1;
          pc_msbits <= pc(31 downto 28);
        end if;
        PH_Decode   <= PH_Fetch;
        PH_Regfile1 <= PH_Decode;

        if PH_Regfile1 then
          if srcreg_class=SRC_REG_CLASS_AB and instr_b/=0 then
            PH_Regfile2 <= true;
          else
            PH_Execute  <= true;
          end if;
        end if;

        if PH_Regfile2 then
          PH_Execute <= true;
        end if;

        if PH_Execute then
          dstreg_wren <= writeback_ex;
          if instr_class=INSTR_CLASS_BRANCH then
            PH_Branch <= true;
          elsif instr_class=INSTR_CLASS_MEMORY then
            PH_Memory_Address <= true;
            if fu_op_reg_u(MEM_OP_BIT_STORE)='1' then
              dm_write <= '1';
            else
              dm_read  <= '1';
            end if;
          else
            PH_Fetch <= true;
            if instr_class=INSTR_CLASS_JUMP then
              if srcreg_class=SRC_REG_CLASS_A then
                pc <= reg_a(31 downto 2);      -- indirect jumps, calls and returns
              else
                pc <= pc_msbits & instr_imm26; -- direct jumps and calls
              end if;
            end if;
          end if;
        end if;

        if PH_Branch then
          if cmp_result then
            pc <= pc + reg_b(31 downto 2); -- branch taken
          end if;
          PH_Fetch <= true;
        end if;

        if PH_Memory_Address then
          dm_write   <= dm_write;
          dm_read    <= dm_read;
          is_tcm_reg <= is_tcm;
          PH_Memory_Address <= true;
          if is_tcm or avm_waitrequest='0' then
            dm_write <= '0';
            dm_read  <= '0';
            PH_Memory_Address <= false;
            if dm_read='0' then
              PH_Fetch <= true;
            else
              -- TODO - case of avm read with latency=0
              PH_Memory_Data <= true;
            end if;
          end if;
        end if;

        if PH_Memory_Data then
          if is_tcm_reg or avm_readdatavalid='1' then
            dstreg_wren <= true;
            PH_Fetch <= true;
          else
            PH_Memory_Data <= true;
          end if;
        end if;
      end if;

    end if;
  end process;

  -- register file access
  process (clk)
    variable rf_rdaddr : natural range 0 to 31;
    variable rf_d    : u32;
    variable rf_wren : boolean;
  begin
    if rising_edge(clk) then

      fu_op_reg_i <= fu_op_i;
      -- register file read address
      rf_rdaddr := to_integer(instr_b);
      if PH_Decode then
        rf_rdaddr := to_integer(instr_a);
        instr_s2 <= instr_s1;
        rf_wraddr  <= 31; -- prepare for call
      end if;

      if PH_Regfile1 then
        reg_a <= rf_readdata; -- latch register A
        reg_b <= immx;        -- type-I instructions except branches or shifts by immediate - the second source operand is immediate
        if r_type then
          rf_wraddr <= to_integer(instr_c); -- r[C]
        else
          rf_wraddr <= to_integer(instr_b); -- r[B]
        end if;
      end if;

      if PH_Regfile2 then
        reg_b <= rf_readdata; -- latch register B
      end if;

      if PH_Execute then
        reg_b <= immx;        -- for branches
      end if;

      -- register file write
      rf_wren := dstreg_wren and (rf_wraddr/=0);
      result_sel_alu <= instr_class=INSTR_CLASS_ALU;
      -- if instr_class=INSTR_CLASS_ALU then
      if result_sel_alu then
        rf_d := alu_result;
      else
        rf_d := sh_result;
      end if;

      if is_call or is_next_pc then
        rf_wren := true;
        rf_d(31 downto 2) := pc;
        rf_d(1 downto 0)  := (others => '0');
      end if;

      if rf_wren then
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
    addr := agu_result;
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
    dm_address(TCM_ADDR_WIDTH-1 downto 2) when PH_Memory_Address else
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
