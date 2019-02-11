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
use work.memory_opcodes.all;

architecture a of nios2ee is
  signal s_reset : boolean := true;
  -- processing phases
  signal PH_Fetch : boolean;
  -- Calculate instruction address as combinatorial function of iu_branch, comparison result and "indirect_jump" flag
  -- Drive instruction address on tcm_rdaddress.
  -- Write result of the previous instruction into register file.
  -- When previous instruction was store - drive memory address/control/*_writedata and *_byteenable buses
  -- For Avalon-mm accesses remain at this phase until fabric de-asserts avm_waitrequest signal
  -- Proceed to PH_Decode

  signal PH_Decode : boolean;
  -- Calculate NextPC
  -- Drive register file read addresses with indices of lower halves of registers A and B
  -- Latch instruction word
  -- Proceed to PH_Regfile1

  signal PH_Regfile1 : boolean;
  -- Latch value of lower half of register A
  -- Latch value of lower half of source operand B
  -- Update writedata with lower half of register B
  -- Calculate branch target of taken PC-relative branches
  -- For direct jumps and calls - drive new instruction address on tcm_rdaddress and proceed to PH_Decode
  -- For direct calls - write NextPC to RA (R31)
  -- For NEXTPC instruction - write NextPC to R[C] and proceed to PH_Decode
  -- For unconditional branches - set relevant branch flags and proceed to PH_Fetch
  -- For indirect jumps and calls -
  --     Drive register file read addresses with indices of both halves of registers A
  -- For shift/rotate instructions -
  --     Drive register file read addresses with indices of both halves of registers A
  -- For ALU/Branch/Memory instructions -
  --     Drive register file read addresses with indices of upper halves of registers A and B
  -- For all instructions except direct jumps, calls, NEXTPC and unconditional branches - Proceed to PH_Regfile2

  signal PH_Regfile2 : boolean;
  -- For indirect jumps and calls -
  --    Latch values of both halves of registers A
  --    Set "indirect_jump" flag and proceed to PH_Fetch
  -- For indirect calls - write NextPC to RA (R31)
  -- For shift/rotate instructions -
  --    Latch values of both halves of registers A
  -- For ALU/Branch/Memory instructions -
  --    Process latched lower halves of operands by ALU/AGU
  --    Latch value of upper half of register A
  --    Latch value of upper half of source operand B
  --    Update writedata with upper half of register B
  -- For all instructions except indirect jumps and calls - Proceed to PH_Execute

  signal PH_Execute : boolean;
  -- For shift/rotate instructions      - Process latched operands by Shifter
  -- For ALU/Branch/Memory instructions - Process latched upper halves of operands by ALU/AGU
  -- For ALU instructions               - write half (16 bits) of result to register file
  -- For shift/rotate instructions      - Set flags for 32-bit result writeback
  -- For ALU instructions               - Set flags for 16-bit result writeback
  -- For conditional branches           - Set iu_branch flag
  -- For all instructions except memory loads -  proceed to PH_Fetch
  -- For memory loads -  proceed to PH_Load_Address

  signal PH_Load_Address : boolean;
  -- [Optional] used only by memory loads
  -- Drive tcm_rdaddress&avm_address/control buses
  -- For Avalon-mm accesses remain at this phase until fabric de-asserts avm_waitrequest signal

  signal PH_Load_Data : boolean;
  -- [Optional] used only by memory loads
  -- For byte and half-word accesses align and sign-extend or zero-extend Load data
  -- For Avalon-mm accesses remain at this phase until fabric asserts avm_readdatavalid signal

  subtype u16 is unsigned(15 downto 0);
  subtype u32 is unsigned(31 downto 0);
  signal pc     : unsigned(TCM_ADDR_WIDTH-1 downto 2);
  signal nextpc : unsigned(31 downto 2);
  signal iu_branch  : boolean; -- true=instruct program counter block to select instruction address with accordance to iu_taken_branch
  signal iu_pre_indirect_jump  : boolean;

  alias instr_s1 : u32 is tcm_readdata;
  -- instruction decode signals
  signal instr_s2 : unsigned(31 downto 6);
  -- alias instr_op    : unsigned(5  downto 0) is tcm_readdata( 5 downto  0);
  alias instr_s2_imm16 : unsigned(15 downto 0) is instr_s2(21 downto  6); -- I-type
  alias instr_s1_b     : unsigned(4  downto 0) is instr_s1(26 downto 22); -- I-type and R-type
  alias instr_s2_b     : unsigned(4  downto 0) is instr_s2(26 downto 22); -- I-type and R-type
  alias instr_s1_a     : unsigned(4  downto 0) is instr_s1(31 downto 27); -- I-type and R-type
  alias instr_s2_a     : unsigned(4  downto 0) is instr_s2(31 downto 27); -- I-type and R-type
  -- alias instr_imm5  : unsigned(4  downto 0) is tcm_readdata(10 downto  6); -- R-type
  -- alias instr_opx   : unsigned(5  downto 0) is tcm_readdata(16 downto 11); -- R-type
  alias instr_s2_c     : unsigned(4  downto 0) is instr_s2(21 downto 17); -- R-type
  alias instr_s2_imm26 : unsigned(25 downto 0) is instr_s2(31 downto  6); -- J-type

  signal r_type, writeback_ex, is_call, is_direct_call, is_indirect_call, is_next_pc, is_br, is_srcreg_b : boolean;
  signal jump_class   : jump_class_t;
  signal instr_class  : instr_class_t;
  signal imm16_class  : imm16_class_t;
  signal alu_op, mem_op_i : natural range 0 to 15; -- ALU and memory(LSU) unit internal opcode
  signal shifter_op : natural range 0 to 7;  -- shift/rotate unit internal opcode
  signal mem_op_u : unsigned(3 downto 0);  -- unsigned representation of mem_op_i
  signal reg_a, reg_b : u16;
  signal reg_a32 : u32;

  -- ALU/AGU
  signal alu_result : u16;
  signal alu_result_a0 : natural range 0 to 1;
  signal agu_result : u32;
  signal cmp_result : boolean; -- for branches

  -- shifter
  signal sh_result : u32;
  signal shifter_b : unsigned(4 downto 0);
  signal sh_rot16  : std_logic;

  -- register file access
  signal rf_wrnextpc : boolean;
  signal rf_readdata_a, rf_readdata_b : u16;
  signal rf_rdaddr_a, rf_rdaddr_b : natural range 0 to 63;
  signal rf_ra_a32, rf_rd_a32 : boolean;
  signal rf_wraddr : natural range 0 to 31;
  signal dstreg_wren, result_sel_alu : boolean;

  alias rf_storedata_h : std_logic_vector(15 downto 0) is std_logic_vector(rf_readdata_b(15 downto 0));
  alias rf_storedata_b : std_logic_vector( 7 downto 0) is std_logic_vector(rf_readdata_b( 7 downto 0));

  -- memory access signals
  signal is_tcm, is_tcm_reg : boolean;
  -- store data
  signal dm_readdata : unsigned(31 downto 0);
  signal writedata  : std_logic_vector(31 downto 0);
  signal byteenable : std_logic_vector(3 downto 0);
  signal dm_address : std_logic_vector(CPU_ADDR_WIDTH-1 downto 0); -- 8-bit bytes
  signal dm_write   : std_logic;

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
    r_type           => r_type,           -- out boolean;
    jump_class       => jump_class,       -- out jump_class_t;
    instr_class      => instr_class ,     -- out instr_class_t;
    is_srcreg_b      => is_srcreg_b,      -- out boolean; -- true when r[B] is source for ALU, Branch or shift operation, but not for stores
    is_br            => is_br,            -- out boolean; -- unconditional branch
    writeback_ex     => writeback_ex,     -- out boolean; -- true when destination register is updated with result of PH_execute stage
    is_direct_call   => is_direct_call,   -- out boolean;
    is_indirect_call => is_indirect_call, -- out boolean;
    is_next_pc       => is_next_pc,       -- out boolean; -- active for nextpc instruction on the next clock after start
    imm16_class      => imm16_class,      -- out imm16_class_t;
    shifter_op       => shifter_op,       -- out natural range 0 to 7;  -- shift/rotate unit internal opcode
    mem_op           => mem_op_i,         -- out natural range 0 to 15; -- memory(LSU) unit internal opcode
    alu_op           => alu_op            -- out natural range 0 to 15  -- ALU unit internal opcode
   );
  mem_op_u <= to_unsigned(mem_op_i, 4);

  -- ALU/AGU
  a:entity work.n2alu_halfwidth
   generic map (DATA_WIDTH => 32)
   port map (
    clk    => clk        , -- in  std_logic;
    start  => PH_Regfile2, -- in  boolean;
    op     => alu_op     , -- in  natural range 0 to 15;
    a      => reg_a      , -- in  unsigned(DATA_WIDTH/2-1 downto 0);
    b      => reg_b      , -- in  unsigned(DATA_WIDTH/2-1 downto 0);
    -- results
    result     => alu_result   , -- out unsigned(DATA_WIDTH/2-1 downto 0); -- first half available on the next clock after start
    result_a0  => alu_result_a0, -- out natural range 0 to 1;              -- 0 - lower half of result, 1 - upper half of result
    agu_result => agu_result   , -- out unsigned(DATA_WIDTH-1 downto 0);   -- available 2 clocks after start
    cmp_result => cmp_result     -- buffer boolean                         -- for branches, available 2 clocks after start
   );

  -- shifter/Load alignment
  sha:entity work.n2shift_align
   port map (
    clk           => clk,         -- in  std_logic;
    do_shift      => PH_Execute,  -- in  boolean;
    -- shift/rotate inputs
    sh_op_i       => shifter_op,  -- in  natural range 0 to 7; -- shift/rotate unit internal opcode
    a             => reg_a32,     -- in  unsigned;
    b             => shifter_b,   -- in  unsigned;
    -- align/sign-extend load data inputs
    ld_op_i       => mem_op_i,               -- in  natural range 0 to 15; -- memory(LSU) unit internal opcode
    readdata      => dm_readdata,            -- in  unsigned;
    readdata_bi   => agu_result(1 downto 0), -- in  unsigned; -- byte index of LS byte of load result in dm_readdata
    -- result
    result        => sh_result,   -- out unsigned -- result latency = 1 clock
    rot16         => sh_rot16     -- out std_logic
                                  -- '0' - result written to register file as is,
                                  -- '1' - result rotated by 16 before it is written to register file
   );

  -- program counter/jumps/branches
  iu:entity work.n2program_counter
   generic map (
    TCM_ADDR_WIDTH => TCM_ADDR_WIDTH,
    RESET_ADDR     => RESET_ADDR    ,
    TCM_REGION_IDX => TCM_REGION_IDX)
   port map (
    clk           => clk,                                   -- in  std_logic;
    s_reset       => s_reset,                               -- in  boolean; -- synchronous reset
    calc_nextpc   => PH_Decode,                             -- in  boolean;
    update_addr   => PH_Regfile1,                           -- in  boolean;
    jump_class    => jump_class,                            -- in  jump_class_t;
    branch        => iu_branch,                             -- in  boolean;
    branch_taken  => cmp_result or is_br,                   -- in  boolean;
    imm26         => instr_s2_imm26,                        -- in  unsigned(25 downto 0);
    reg_a         => reg_a32,                               -- in  unsigned(31 downto 0);
    pre_indirect_jump => iu_pre_indirect_jump,              -- out boolean;
    addr          => pc,                                    -- out unsigned(TCM_ADDR_WIDTH-1 downto 2)
    nextpc        => nextpc                                 -- out unsigned(31 downto 2)
   );

  process (clk)
  begin
    if rising_edge(clk) then
      dm_write <= '0';
      dstreg_wren <= false;
      iu_branch   <= false;

      PH_Fetch        <= false;
      PH_Decode       <= false;
      PH_Regfile1     <= false;
      PH_Regfile2     <= false;
      PH_Execute      <= false;
      PH_Load_Address <= false;
      PH_Load_Data    <= false;

      if s_reset then
        PH_Fetch <= true;
      else
        if PH_Fetch then
          if dm_write='1' then
            -- memory store
            if is_tcm or avm_waitrequest='0' then
              PH_Decode <= true;
            else
              dm_write <= '1';
              PH_Fetch <= true;
            end if;
          else
            PH_Decode <= true;
          end if;
        end if;

        PH_Regfile1 <= PH_Decode;

        if PH_Regfile1 then
          if jump_class=JUMP_CLASS_DIRECT or is_next_pc then
            PH_Decode <= true; -- last execution stage of direct jumps overlaps with first stage of the next instruction
          elsif is_br then
            PH_Fetch <= true;  -- last execution stage of unconditional branch
            iu_branch <= true;
          else
            PH_Regfile2 <= true;
          end if;
        end if;

        if PH_Regfile2 then
          if iu_pre_indirect_jump then
            PH_Fetch <= true;  -- last execution stage indirect jumps
          else
            PH_Execute <= true;
            if result_sel_alu then
              dstreg_wren <= writeback_ex;
            end if;
          end if;
        end if;

        if PH_Execute then
          dstreg_wren <= writeback_ex;
          if instr_class=INSTR_CLASS_MEMORY then
            if mem_op_u(MEM_OP_BIT_STORE)='1' then
              dm_write <= '1';
              PH_Fetch <= true;
            else
              PH_Load_Address <= true;
            end if;
          else
            PH_Fetch <= true;
            if instr_class=INSTR_CLASS_BRANCH then
              iu_branch <= true;
            end if;
          end if;
        end if;

        if PH_Load_Address then
          is_tcm_reg <= is_tcm;
          PH_Load_Address <= true;
          if is_tcm or avm_waitrequest='0' then
            PH_Load_Address <= false;
            -- TODO - case of avm read with latency=0
            PH_Load_Data <= true;
          end if;
        end if;

        if PH_Load_Data then
          if is_tcm_reg or avm_readdatavalid='1' then
            dstreg_wren <= true;
            PH_Fetch <= true;
          else
            PH_Load_Data <= true;
          end if;
        end if;
      end if;

    end if;
  end process;

  -- register file access
  -- RF read address mux
  process (all)
  begin
    rf_rdaddr_a <= to_integer(instr_s1_a)*2 + 0; -- LSH of r[A]
    rf_rdaddr_b <= to_integer(instr_s1_b)*2 + 0; -- LSH of r[B]
    rf_ra_a32 <= false;
    if PH_Regfile1 then
      rf_rdaddr_a <= to_integer(instr_s2_a)*2 + 1; -- MSH of r[A]
      if jump_class=JUMP_CLASS_OTHERS and instr_class/=INSTR_CLASS_SHIFT then
        -- ALU/Memory/Branches
        rf_rdaddr_b <= to_integer(instr_s2_b)*2 + 1; -- MSH of r[B]
      else
        -- Shifter/Direct jumps and calls
        rf_rdaddr_b <= to_integer(instr_s2_a)*2 + 0; -- LSH of r[A]
        rf_ra_a32 <= true;
      end if;
    end if;
  end process;

  process (clk)
  begin
    if rising_edge(clk) then

      -- register file read address
      if PH_Decode then
        instr_s2  <= instr_s1(31 downto 6);
      end if;

      if PH_Regfile1 or PH_Regfile2 then
        reg_a <= rf_readdata_a; -- latch register A
      end if;

      -- register file write
      result_sel_alu <= instr_class=INSTR_CLASS_ALU;

    end if;
  end process;

  -- reg_b as a source mux
  process (clk)
    constant sel_imm : natural := 0;
    constant sel_rf  : natural := 1;
    constant sel_0   : natural := 2;
    constant sel_1   : natural := 3;
    subtype sel_t is natural range sel_imm to sel_1;
    variable sel : sel_t;
  begin
    if rising_edge(clk) then
      rf_rd_a32 <= rf_ra_a32;
      if PH_Regfile1 then
        if is_srcreg_b then
          sel := sel_rf;
        elsif imm16_class = IMM16_CLASS_h16 then
          sel := sel_0;
        else
          sel := sel_imm;
        end if;
      elsif rf_rd_a32 then
        sel := sel_rf; -- shifter/direct jump - latch LSH of R[A]
      else -- PH_Regfile1
        if is_srcreg_b then
          sel := sel_rf;
        elsif imm16_class = IMM16_CLASS_h16 then
          sel := sel_imm;
        elsif imm16_class = IMM16_CLASS_s16 and instr_s2_imm16(15)='1' then
          sel := sel_1;
        else
          sel := sel_0;
        end if;
      end if;

      case sel is
        when sel_imm => reg_b <= instr_s2_imm16;
        when sel_rf  => reg_b <= rf_readdata_b;
        when sel_0   => reg_b <= (others => '0');
        when sel_1   => reg_b <= (others => '1');
      end case;

      shifter_b <= reg_b(4 downto 0);
    end if;
  end process;
  reg_a32 <= reg_a & reg_b;

  is_call <=
    is_direct_call   when PH_Regfile1 else
    is_indirect_call when PH_Regfile2 else
    false;
  rf_wraddr <= 31 when is_call else to_integer(instr_s2_c) when r_type else to_integer(instr_s2_b);
  rf_wrnextpc <= is_call or is_next_pc;
  rf:entity work.n2register_file
   port map (
    clk         => clk,            -- in  std_logic;
    rdaddr_a    => rf_rdaddr_a,    -- in  natural range 0 to 63;
    rdaddr_b    => rf_rdaddr_b,    -- in  natural range 0 to 63;
    wraddr      => rf_wraddr,      -- in  natural range 0 to 31;
    nextpc      => nextpc,         -- in  unsigned(31 downto 2);
    wrnextpc    => rf_wrnextpc,    -- in  boolean;
    wrdata0     => alu_result,     -- in  unsigned(15 downto 0);
    wraddr0_lsb => alu_result_a0,  -- in  natural range 0 to 1;
    wrdata1     => sh_result,      -- in  unsigned(31 downto 0);
    wrdata1_rot16 => sh_rot16,     -- in  std_logic;
                                   -- '0' - wrdata1 written to register file as is,
                                   -- '1' - wrdata1 rotated by 16 before it is written to register file
    wrdata_sel0 => result_sel_alu, -- in  boolean;
    dstreg_wren => dstreg_wren,    -- in  boolean;
    -- read result q available on the next clock after rdaddr
    q_a         => rf_readdata_a,  -- out unsigned(15 downto 0);
    q_b         => rf_readdata_b  -- out unsigned(15 downto 0);
  );


  -- writedata
  process (clk)
  begin
    if rising_edge(clk) then
      case mem_op_i mod 4 is
        when MEM_OP_B =>
          if PH_Regfile1 then
            writedata <= rf_storedata_b & rf_storedata_b & rf_storedata_b & rf_storedata_b;
          end if;

        when MEM_OP_H =>
          if PH_Regfile1 then
            writedata <= rf_storedata_h & rf_storedata_h;
          end if;

        when others =>
          if PH_Regfile1 then
            writedata <= rf_storedata_h & rf_storedata_h;
          elsif PH_Regfile2 then
            writedata(31 downto 16) <= rf_storedata_h;
          end if;
      end case;
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
    case mem_op_i mod 4 is
      when MEM_OP_B =>
        byteenable(bi) <= '1';

      when MEM_OP_H =>
        byteenable((bi/2)*2+0) <= '1';
        byteenable((bi/2)*2+1) <= '1';

      when others =>
        byteenable <= (others => '1');
    end case;

    dm_address(CPU_ADDR_WIDTH-1 downto 2) <= std_logic_vector(addr(CPU_ADDR_WIDTH-1 downto 2));
    dm_address(1 downto 0) <= (others => '0');

    is_tcm <= (to_integer(addr)/2**TCM_ADDR_WIDTH)=TCM_REGION_IDX;
  end process;

  tcm_rdaddress <=
    dm_address(TCM_ADDR_WIDTH-1 downto 2) when PH_Load_Address else
    std_logic_vector(pc);
  tcm_wraddress  <= dm_address(TCM_ADDR_WIDTH-1 downto 2);
  tcm_byteenable <= byteenable;
  tcm_writedata  <= writedata;
  tcm_write      <= dm_write when is_tcm else '0';

  avm_address    <= dm_address;
  avm_byteenable <= byteenable;
  avm_writedata  <= writedata;
  avm_write      <= dm_write when not is_tcm else '0';
  avm_read       <= '1' when PH_Load_Address and not is_tcm else '0';

  dm_readdata <= tcm_readdata when is_tcm_reg else avm_readdata;

end architecture a;
