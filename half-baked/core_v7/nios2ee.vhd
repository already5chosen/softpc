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
  -- Drive instruction address on tcm_rdaddress.
  -- PH_Fetch is 1st pipeline stage

  signal PH_Decode : boolean;
  -- Calculate NextPC
  -- Drive register file address with index of register A
  -- Latch instruction word
  -- PH_Decode is 2nd pipeline stage

  signal PH_Regfile1 : boolean;
  -- Start to drive register file address with index of register B
  -- Latch value of register A
  -- For calls - write NextPC to RA
  -- Calculate branch target of taken PC-relative branches
  -- For jumps and calls - reload PC and finish
  -- For rest of instruction -  reload PC with NextPC and continue
  -- PH_Regfile1 is 3rd pipeline stage

  signal PH_Regfile2 : boolean;
  -- [Optional] used by instructions with 2 register sources except for integer stores
  -- Latch value of register B
  -- PH_Regfile2 is 4th pipeline stage (follows PH_Regfile1)

  signal PH_Execute1, PH_Execute2 : boolean;
  -- Process operands by ALU/AGU/Shifter
  -- finish all instructions except conditional branches and memory accesses
  -- PH_Execute1 is 4th pipeline stage (follows PH_Regfile1)
  -- PH_Execute2 is 5th pipeline stage (follows PH_Regfile2)

  signal PH_Memory : boolean;
  -- Drive tcm_rdaddress
  -- Start to drive other address buses, but don't assert control signals yet
  -- Latch writedata
  -- PH_Memory is 4th pipeline stage (follows PH_Regfile1)

  signal PH_Load : boolean;
  -- [Optional] used only by memory loads
  -- For TCM accesses it is single-clock data acquisition phase
  -- For Avalon-mm accesses it is whole load state machine consisting of address and data stages
  -- with each statge lasting from 1 to many clocks
  -- in Avalon-mm address phase:
  --  drive avm_address bus
  --  assert avm_read signal
  --  remain at this phase until fabric de-asserts avm_waitrequest signal
  -- in Avalon-mm data acquisition phase:
  --  remain at this phase until fabric asserts avm_readdatavalid signal
  -- Both for TCM and Avalon-mm accesses during last clock of data acquisition phase
  -- xxx_readdata is forwarded to n2shift_align module in order for alignment and
  -- zero-extension of sign-extension of byte and half-word accesses

  signal Stall_Fetch, Stall_Regfile1, Stall_Memory, Stall_Load, cond_branch : boolean;
  signal do_Fetch, do_Decode, do_Regfile1, done_Regfile1, do_Memory : boolean;


  subtype u32 is unsigned(31 downto 0);
  signal pc     : unsigned(TCM_ADDR_WIDTH-1 downto 2);
  signal nextpc : unsigned(31 downto 2);
  signal iu_branch  : boolean; -- true=instruct program counter block to select instruction address with accordance to iu_taken_branch
  signal iu_branch_taken : boolean;

  alias instr_s1 : u32 is tcm_readdata;
  -- instruction decode signals
  signal instr_s2 : unsigned(31 downto 6);
  -- alias instr_op    : unsigned(5  downto 0) is tcm_readdata( 5 downto  0);
  alias instr_s2_imm16 : unsigned(15 downto 0) is instr_s2(21 downto  6); -- I-type
  alias instr_s2_b     : unsigned(4  downto 0) is instr_s2(26 downto 22); -- I-type and R-type
  alias instr_s1_a     : unsigned(4  downto 0) is instr_s1(31 downto 27); -- I-type and R-type
  alias instr_s2_a     : unsigned(4  downto 0) is instr_s2(31 downto 27); -- I-type and R-type
  -- alias instr_imm5  : unsigned(4  downto 0) is tcm_readdata(10 downto  6); -- R-type
  -- alias instr_opx   : unsigned(5  downto 0) is tcm_readdata(16 downto 11); -- R-type
  alias instr_s2_c     : unsigned(4  downto 0) is instr_s2(21 downto 17); -- R-type
  alias instr_s2_imm26 : unsigned(25 downto 0) is instr_s2(31 downto  6); -- J-type

  signal r_type, writeback_ex, writeback_ex_s, is_call, is_next_pc, is_br, is_b_zero, is_srcreg_b : boolean;
  signal jump_class   : jump_class_t;
  signal instr_class  : instr_class_t;
  signal imm16_class  : imm16_class_t;
  signal alu_op, mem_op_i : natural range 0 to 15; -- ALU and memory(LSU) unit internal opcode
  signal shifter_op : natural range 0 to 7;  -- shift/rotate unit internal opcode
  signal mem_op_u : unsigned(3 downto 0);    -- unsigned representation of mem_op_i
  signal ls_op_i  : natural range 0 to 7;    -- LS bits of mem_op_i latched at do_memory
  signal alu_sh_op_reg : natural range 0 to 15; -- ALU or shifter opcode latched at do_Regfile1
  signal reg_a, reg_b : u32;

  -- ALU/AGU
  signal alu_result, agu_result : u32;
  signal cmp_result : boolean; -- for branches

  -- shifter
  signal sh_result : u32;

  -- register file access
  signal rf_wrsel_nextpc : boolean;
  signal rf_readdata, rf_wrdata : u32;
  signal rf_wraddr, rf_rdaddr : natural range 0 to 31;
  signal dstreg_wren, rf_wrsel_alu, rf_wren : boolean;

  alias rf_storedata_w : unsigned(31 downto 0) is rf_readdata(31 downto 0);
  alias rf_storedata_h : unsigned(15 downto 0) is rf_readdata(15 downto 0);
  alias rf_storedata_b : unsigned(7 downto 0)  is rf_readdata(7 downto 0);

  -- memory access signals
  signal is_tcm, is_tcm_reg : boolean;
  -- store data
  signal dm_readdata : unsigned(31 downto 0);
  signal writedata  : std_logic_vector(31 downto 0);
  signal byteenable : std_logic_vector(3 downto 0);
  signal dm_address : std_logic_vector(CPU_ADDR_WIDTH-1 downto 0); -- 8-bit bytes
  signal dm_write, dm_read : std_logic;
  signal agu_result_reg : unsigned(CPU_ADDR_WIDTH-1 downto 0);
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
    start        => do_Decode,    -- in  boolean;
    instruction  => instr_s1,     -- in  unsigned(31 downto 0);
    -- decode results are available on the next clock after start
    r_type       => r_type,       -- out boolean;
    jump_class   => jump_class,   -- out jump_class_t;
    instr_class  => instr_class , -- out instr_class_t;
    is_srcreg_b  => is_srcreg_b,  -- out boolean; -- true when r[B] is source for ALU, Branch or shift operation, but not for stores
    is_b_zero    => is_b_zero,    -- out boolean;
    is_br        => is_br,        -- out boolean; -- unconditional branch
    writeback_ex => writeback_ex, -- out boolean; -- true when destination register is updated with result of PH_execute stage
    is_call      => is_call,      -- out boolean; -- CALL/CALLR
    is_next_pc   => is_next_pc,   -- out boolean; -- NEXTPC
    imm16_class  => imm16_class,  -- out imm16_class_t;
    shifter_op   => shifter_op,   -- out natural range 0 to 7;  -- shift/rotate unit internal opcode
    mem_op       => mem_op_i,     -- out natural range 0 to 15; -- memory(LSU) unit internal opcode
    alu_op       => alu_op        -- out natural range 0 to 15  -- ALU unit internal opcode
   );
  mem_op_u <= to_unsigned(mem_op_i, 4);

  -- ALU/AGU
  a:entity work.n2alu
   generic map (DATA_WIDTH => 32)
   port map (
    clk => clk,           -- in  std_logic;
    op  => alu_sh_op_reg, -- in  natural range 0 to 15;
    a   => reg_a,         -- in  unsigned(DATA_WIDTH-1 downto 0);
    b   => reg_b,         -- in  unsigned(DATA_WIDTH-1 downto 0);
    -- results are available on the next clock after start
    result     => alu_result, -- out unsigned(DATA_WIDTH-1 downto 0)
    cmp_result => cmp_result  -- buffer boolean -- for branches
   );

  -- shifter/Load alignment
  sha:entity work.n2shift_align
   port map (
    clk           => clk,         -- in  std_logic;
    do_shift      => PH_Execute1 or PH_Execute2,  -- in  boolean;
    -- shift/rotate inputs
    sh_op_i       => alu_sh_op_reg mod 8,         -- in  natural range 0 to 7; -- shift/rotate unit internal opcode
    a             => reg_a,                       -- in  unsigned;
    b             => reg_b(4 downto 0),           -- in  unsigned;
    -- align/sign-extend load data inputs
    ld_op_i       => ls_op_i,                     -- in  natural range 0 to 7; -- memory(LSU) unit internal opcode
    readdata      => dm_readdata,                 -- in  unsigned;
    readdata_bi   => to_unsigned(readdata_bi, 2), -- in  unsigned; -- byte index of LS byte of load result in dm_readdata
    -- result
    result        => sh_result    -- out unsigned -- result latency = 1 clock
   );

  -- program counter/jumps/branches
  iu_branch_taken <= cmp_result or is_br;
  iu:entity work.n2program_counter
   generic map (
    TCM_ADDR_WIDTH => TCM_ADDR_WIDTH,
    RESET_ADDR     => RESET_ADDR    ,
    TCM_REGION_IDX => TCM_REGION_IDX)
   port map (
    clk           => clk,                                   -- in  std_logic;
    s_reset       => s_reset,                               -- in  boolean; -- synchronous reset
    calc_nextpc   => PH_Decode,                             -- in  boolean;
    update_addr   => do_Regfile1,                           -- in  boolean;
    jump_class    => jump_class,                            -- in  jump_class_t;
    branch        => iu_branch,                             -- in  boolean;
    branch_taken  => iu_branch_taken,                       -- in  boolean;
    imm26         => instr_s2_imm26,                        -- in  unsigned(25 downto 0);
    reg_a         => reg_a,                                 -- in  unsigned(31 downto 0);
    addr          => pc,                                    -- out unsigned(TCM_ADDR_WIDTH-1 downto 2)
    nextpc        => nextpc                                 -- out unsigned(31 downto 2)
   );

  -- pipeline stalls
  process (all)
  begin

    Stall_Fetch <= false;
    if PH_Fetch then
      -- Fetch stalls because previous instruction is control transfer
      Stall_Fetch <= cond_branch;
      if PH_Regfile1 then
        Stall_Fetch <=
          (jump_class/=JUMP_CLASS_OTHERS) or (instr_class=INSTR_CLASS_BRANCH) or is_next_pc;
      end if;
    end if;

    Stall_Regfile1 <= false;
    if PH_Regfile1 then
      -- Regfile stalls because register A is late result of previous instruction
      if PH_Execute2 or PH_Load then
        Stall_Regfile1 <= rf_wraddr=instr_s2_a and rf_wraddr/=0;
      end if;
    end if;

    Stall_Memory <= false;
    if PH_Memory then
      -- Memory stalls because of unfinished AVM store
      Stall_Memory <= avm_write='1' and avm_waitrequest='1';
    end if;

    Stall_Load <= false;
    if PH_Load then
      -- Load stalls for the full duration of AVM readdata wait
      Stall_Load <= avm_read='1' or avm_readdatavalid='0';
    end if;

    -- stall at later even stage affects all earlier even stages
    -- stall at later odd stage affects all earlier off stages
    do_Fetch    <= PH_Fetch    and (not Stall_Fetch) and (not Stall_Regfile1) and (not Stall_Load);
    do_Decode   <= PH_Decode   and (not Stall_Memory);
    do_Regfile1 <= PH_Regfile1 and (not Stall_Regfile1) and (not Stall_Load);
    do_Memory   <= PH_Memory   and (not Stall_Memory);

  end process;

  process (clk)
  begin
    if rising_edge(clk) then

      if is_tcm_reg or avm_waitrequest='0' then
        dm_read  <= '0';
        dm_write <= '0';
      end if;

      dstreg_wren <= false;
      iu_branch   <= false;
      PH_Regfile2 <= false; -- never stalls
      PH_Execute1 <= false; -- never stalls
      PH_Execute2 <= false; -- never stalls

      if s_reset then
        PH_Fetch    <= true;
        PH_Decode   <= false;
        PH_Regfile1 <= false;
        PH_Memory   <= false;
        PH_Load     <= false;
        cond_branch <= false;
        writeback_ex_s <= false;
      else

        if do_Fetch then
          PH_Fetch  <= false;
          PH_Decode <= true;
        end if;

        if do_Decode then
          PH_Decode   <= false;
          PH_Regfile1 <= true;
          PH_Fetch    <= true; -- start the next instruction
        end if;

        if do_Regfile1 then
          PH_Regfile1 <= false;
          writeback_ex_s <= writeback_ex;
          if jump_class=JUMP_CLASS_OTHERS then
            if is_br then
              iu_branch <= true;
            else
              cond_branch <= (instr_class=INSTR_CLASS_BRANCH);
              if is_srcreg_b and not is_b_zero then
                PH_Regfile2 <= true;
              elsif instr_class=INSTR_CLASS_MEMORY then
                PH_Memory <= true;
              else
                PH_Execute1 <= true;
              end if;
            end if;
          end if;
          if is_call then
            PH_Execute1 <= true;
            writeback_ex_s <= true;
          end if;
        end if;

        if PH_Regfile2 then
          PH_Execute2 <= true;
        end if;

        if PH_Execute1 or PH_Execute2 then
          dstreg_wren <= writeback_ex_s;
          cond_branch <= false;
          iu_branch   <= cond_branch;
        end if;

        if do_Memory then
          PH_Memory <= false;
          is_tcm_reg <= is_tcm;
          if mem_op_u(MEM_OP_BIT_STORE)='1' then
            dm_write <= '1'; -- memory stores
          else
            dm_read <= '1';  -- memory loads
            PH_Load <= true;
          end if;
        end if;

        if PH_Load then
          if is_tcm_reg or (dm_read='0' and avm_readdatavalid='1') then
            dstreg_wren <= true;
            PH_Load <= false;
          end if;
        end if;

      end if;

    end if;
  end process;

  -- register file access
  process (clk)
  begin
    if rising_edge(clk) then

      -- register file read address
      if do_Decode then
        instr_s2  <= instr_s1(31 downto 6);
      end if;

      if PH_Regfile1 then
        reg_a <= rf_readdata; -- latch register A
      end if;

      if do_Regfile1 then
        -- latch alu or shifter sub-opcode so the same node can be used
        -- by EUs regardless of timing of execution phase (PH_Execute1 or PH_Execute1)
        if instr_class=INSTR_CLASS_ALU then
          alu_sh_op_reg <= alu_op;
        else
          alu_sh_op_reg <= shifter_op;
        end if;
      end if;

      -- register file write address and data selection
      -- done at the first clock of the 4th stage of the pipeline
      done_Regfile1 <= do_Regfile1;
      if done_Regfile1 then
        rf_wrsel_nextpc <= is_call or is_next_pc;
        rf_wrsel_alu <= instr_class=INSTR_CLASS_ALU;
        if is_call then
          rf_wraddr <= 31;
        elsif r_type then
          rf_wraddr <= to_integer(instr_s2_c);
        else
          rf_wraddr <= to_integer(instr_s2_b);
        end if;
      end if;

    end if;
  end process;

  -- reg_b as a source mux
  process (clk)
    constant sel_imm : natural := 0;
    constant sel_rf  : natural := 1;
    constant sel_0   : natural := 2;
    constant sel_1   : natural := 3;
    subtype l_sel_t is natural range sel_imm to sel_0;
    subtype h_sel_t is natural range sel_imm to sel_1;
    variable l_sel : l_sel_t;
    variable h_sel : h_sel_t;
  begin
    if rising_edge(clk) then
      if PH_Regfile1 then
        -- type-I instructions except branches or shifts by immediate - the second source operand is immediate
        if is_srcreg_b then
           l_sel := sel_0;
           h_sel := sel_0;
        elsif imm16_class = IMM16_CLASS_h16 then
           l_sel := sel_0;
           h_sel := sel_imm;
        else
           l_sel := sel_imm;
           if imm16_class = IMM16_CLASS_s16 and instr_s2_imm16(15)='1' then
             h_sel := sel_1;
           else
             h_sel := sel_0;
           end if;
        end if;
      else
        l_sel := sel_rf ;
        h_sel := sel_rf ;
      end if;

      case l_sel is
        when sel_imm => reg_b(15 downto 0) <= instr_s2_imm16;
        when sel_rf  => reg_b(15 downto 0) <= rf_readdata(15 downto 0);
        when sel_0   => reg_b(15 downto 0) <= (others => '0');
      end case;

      case h_sel is
        when sel_imm => reg_b(31 downto 16) <= instr_s2_imm16;
        when sel_rf  => reg_b(31 downto 16) <= rf_readdata(31 downto 16);
        when sel_0   => reg_b(31 downto 16) <= (others => '0');
        when sel_1   => reg_b(31 downto 16) <= (others => '1');
      end case;
    end if;
  end process;

  rf_rdaddr <= to_integer(instr_s1_a) when PH_Decode else to_integer(instr_s2_b);
  wbm:entity work.n2writeback_mux
   port map (
    wraddr      => rf_wraddr,      -- in  natural range 0 to 31;
    nextpc      => nextpc,         -- in  unsigned(31 downto 2);
    wrnextpc    => rf_wrsel_nextpc,    -- in  boolean;
    wrdata0     => alu_result,     -- in  unsigned(31 downto 0);
    wrdata1     => sh_result,      -- in  unsigned(31 downto 0);
    wrdata_sel0 => rf_wrsel_alu, -- in  boolean;
    dstreg_wren => dstreg_wren,    -- in  boolean;
    wrdata      => rf_wrdata,      -- out unsigned(31 downto 0)
    wren        => rf_wren         -- out boolean
  );
  rf:entity work.n2register_file
   port map (
    clk         => clk,        -- in  std_logic;
    rdaddr      => rf_rdaddr,  -- in  natural range 0 to 31;
    wraddr      => rf_wraddr,  -- in  natural range 0 to 31;
    wrdata      => rf_wrdata,  -- in  unsigned(31 downto 0);
    wren        => rf_wren,    -- in  boolean;
    -- read result q available on the next clock after rdaddr
    q => rf_readdata -- out unsigned(31 downto 0)
  );

  -- data bus address/writedata/byteenable/readdata_bi
  agu_result <= unsigned(resize(signed(instr_s2_imm16), 32)) + reg_a;
  process (clk)
    variable writedata_mux : unsigned(31 downto 0);
  begin
    if rising_edge(clk) then
      case mem_op_i mod 4 is
        when MEM_OP_B => writedata_mux := rf_storedata_b & rf_storedata_b & rf_storedata_b & rf_storedata_b;
        when MEM_OP_H => writedata_mux := rf_storedata_h & rf_storedata_h;
        when others   => writedata_mux := rf_storedata_w;
      end case;
      if do_Memory then
        agu_result_reg <= agu_result(CPU_ADDR_WIDTH-1 downto 0);
        ls_op_i   <= mem_op_i mod 8;
        writedata <= std_logic_vector(writedata_mux); -- latch writedata (read from register B)
      end if;
    end if;
  end process;

  process (all)
    variable bi : natural range 0 to 3;
  begin
    bi := to_integer(agu_result_reg(1 downto 0));
    byteenable <= (others => '0');

    case ls_op_i mod 4 is
      when MEM_OP_B =>
        byteenable(bi) <= '1';
        readdata_bi <= bi;

      when MEM_OP_H =>
        byteenable((bi/2)*2+0) <= '1';
        byteenable((bi/2)*2+1) <= '1';
        readdata_bi <= (bi/2)*2;

      when others =>
        byteenable <= (others => '1');
        readdata_bi <= 0;
    end case;

    dm_address(CPU_ADDR_WIDTH-1 downto 2) <= std_logic_vector(agu_result_reg(CPU_ADDR_WIDTH-1 downto 2));
    dm_address(1 downto 0) <= (others => '0');

    is_tcm <= (to_integer(agu_result)/2**TCM_ADDR_WIDTH)=TCM_REGION_IDX;
  end process;

  tcm_rdaddress <=
    std_logic_vector(agu_result(TCM_ADDR_WIDTH-1 downto 2)) when do_Memory else
    std_logic_vector(pc);
  tcm_wraddress  <= dm_address(TCM_ADDR_WIDTH-1 downto 2);
  tcm_byteenable <= byteenable;
  tcm_writedata  <= writedata;
  tcm_write      <= dm_write when is_tcm_reg else '0';

  avm_address    <= dm_address;
  avm_byteenable <= byteenable;
  avm_writedata  <= writedata;
  avm_write      <= dm_write when not is_tcm_reg else '0';
  avm_read       <= dm_read when  not is_tcm_reg else '0';

  dm_readdata <= tcm_readdata when is_tcm_reg else avm_readdata;

end architecture a;
