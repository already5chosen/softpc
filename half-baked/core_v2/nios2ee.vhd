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
  -- Write result of the previous instruction into register file.
  -- When previous instruction was store - drive memory address/control/*_writedata and *_byteenable buses
  -- For Avalon-mm accesses remain at this phase until fabric de-asserts avm_waitrequest signal

  signal PH_Decode : boolean;
  -- Calculate NextPC
  -- Drive register file address with index of register A
  -- Latch instruction word

  signal PH_Regfile1 : boolean;
  -- Start to drive register file address with index of register B
  -- Latch value of register A
  -- For calls - write NextPC to RA
  -- Calculate branch target of taken PC-relative branches
  -- For jumps and calls - reload PC and finish
  -- For rest of instruction -  reload PC with NextPC and continue

  signal PH_Regfile2 : boolean;
  -- [Optional] used by instructions with 2 register sources except for integer stores
  -- Latch value of register B

  signal PH_Execute : boolean;
  -- Process operands by ALU/AGU/Shifter
  -- Latch writedata
  -- finish all instructions except conditional branches and memory accesses

  signal PH_Branch  : boolean;
  -- [Optional] used only by PC-relative branches
  -- Conditionally or unconditionally update PC with branch target
  -- This phase overlaps with PH_Fetch of the next instruction

  signal PH_Load_Address : boolean;
  -- [Optional] used only by memory loads
  -- Drive tcm_rdaddress&avm_address/control buses
  -- For Avalon-mm accesses remain at this phase until fabric de-asserts avm_waitrequest signal

  signal PH_Load_Data : boolean;
  -- [Optional] used only by memory loads
  -- For byte and half-word accesses align and sign-extend or zero-extend Load data
  -- For Avalon-mm accesses remain at this phase until fabric asserts avm_readdatavalid signal

  subtype u32 is unsigned(31 downto 0);
  signal pc, nextpc : unsigned(31 downto 2);
  signal iu_update_addr : boolean;

  alias instr_s1 : u32 is tcm_readdata;
  -- instruction decode signals
  -- alias instr_op    : unsigned(5  downto 0) is tcm_readdata( 5 downto  0);
  alias instr_imm16 : unsigned(15 downto 0) is instr_s1(21 downto  6); -- I-type
  alias instr_b     : unsigned(4  downto 0) is instr_s1(26 downto 22); -- I-type and R-type
  alias instr_a     : unsigned(4  downto 0) is instr_s1(31 downto 27); -- I-type and R-type
  -- alias instr_imm5  : unsigned(4  downto 0) is tcm_readdata(10 downto  6); -- R-type
  -- alias instr_opx   : unsigned(5  downto 0) is tcm_readdata(16 downto 11); -- R-type
  -- alias instr_c     : unsigned(4  downto 0) is instr_s1(21 downto 17); -- R-type
  alias instr_imm26 : unsigned(25 downto 0) is instr_s1(31 downto  6); -- J-type

  signal writeback_ex, is_call, is_next_pc, is_br, is_br_reg, is_call_reg, is_next_pc_reg : boolean;
  signal jump_class   : jump_class_t;
  signal instr_class  : instr_class_t;
  signal is_srcreg_b, is_b_zero, is_srcreg_b_reg, to_PH_Regfile2 : boolean;
  signal imm16_class  : imm16_class_t;
  signal alu_op, mem_op_i : natural range 0 to 15; -- ALU and memory(LSU) unit internal opcode
  signal shifter_op : natural range 0 to 7;  -- shift/rotate unit internal opcode
  signal mem_op_u : unsigned(3 downto 0);  -- unsigned representation of mem_op_i
  signal lsu_op_reg : natural range 0 to 7;  -- 3 LS bits of mem_op_i (registered)
  signal reg_a, src_a, src_b : u32;
  signal src_sel_ab : boolean;


  signal alu_result    : u32; -- ALU/AGU result
  --signal agu_result    : u32; -- AGU result
  signal sh_result     : u32; -- shifter result
  signal alu_sh_result : u32; -- combined ALU/shifter result
  signal ld_result     : u32; -- load result
  signal rf_wrdata_exu : u32; -- combined ALU/shifter/load result

  -- register file access
  signal rf_wrnextpc : boolean;
  signal rf_readdata : u32;
  signal rf_wraddr, rf_rdaddr, dst_reg_i : natural range 0 to 31;
  signal dstreg_wren, ld_wren, rf_read_en : boolean;

  alias rf_readdata_h : unsigned(15 downto 0) is rf_readdata(15 downto 0);
  alias rf_readdata_b : unsigned(7 downto 0)  is rf_readdata(7 downto 0);

  -- memory access signals
  signal is_tcm, is_tcm_reg, is_load, is_store : boolean;
  -- store data
  signal writedata_mux, dm_readdata : unsigned(31 downto 0);
  signal writedata  : std_logic_vector(31 downto 0);
  signal byteenable : std_logic_vector(3 downto 0);
  signal dm_address : std_logic_vector(CPU_ADDR_WIDTH-1 downto 0); -- 8-bit bytes
  signal dm_write   : std_logic;
  alias  readdata_bi : unsigned(1 downto 0) is alu_sh_result(1 downto 0); -- byte index of LS byte of load result in dm_readdata
  -- alias  readdata_bi : unsigned(1 downto 0) is agu_result(1 downto 0); -- byte index of LS byte of load result in dm_readdata

  signal uu_u32  : u32;
  signal uu_bool : boolean;
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
    instruction  => instr_s1,     -- in  unsigned(31 downto 0);
    r_type       => open,         -- out boolean;
    jump_class   => jump_class,   -- out jump_class_t;
    instr_class  => instr_class , -- out instr_class_t;
    is_br        => is_br,        -- out boolean;  -- unconditional branch
    is_srcreg_b  => is_srcreg_b,  -- out boolean;  -- true when r[B] is source for ALU, Branch or shift operation, but not for stores
    writeback_ex => writeback_ex, -- out boolean; -- true when destination register is updated with result of PH_execute stage
    is_call      => is_call,      -- out boolean;
    is_next_pc   => is_next_pc,   -- out boolean;
    imm16_class  => imm16_class,  -- out imm16_class_t;
    shifter_op   => shifter_op,   -- out natural range 0 to 7;  -- shift/rotate unit internal opcode
    mem_op       => mem_op_i,     -- out natural range 0 to 15; -- memory(LSU) unit internal opcode
    alu_op       => alu_op,       -- out natural range 0 to 15  -- ALU unit internal opcode
    dst_reg_i    => dst_reg_i     -- out natural range 0 to 31
   );
  mem_op_u <= to_unsigned(mem_op_i, 4);

  -- ALU/AGU
  a:entity work.n2alu
   generic map (DATA_WIDTH => 32)
   port map (
    op         => alu_op    , -- in  natural range 0 to 15;
    a          => src_a     , -- in  unsigned(DATA_WIDTH-1 downto 0);
    b          => src_b     , -- in  unsigned(DATA_WIDTH-1 downto 0);
    result     => alu_result, -- out unsigned(DATA_WIDTH-1 downto 0)
    agu_result => open,       -- out unsigned(DATA_WIDTH-1 downto 0)
    cmp_result => open        -- buffer boolean -- for branches
   );

  -- Shifter
  sha:entity work.n2shifter
   port map (
    op     => shifter_op,        -- in  natural range 0 to 7; -- shift/rotate unit internal opcode
    a      => src_a,             -- in  unsigned;
    b      => src_b(4 downto 0), -- in  unsigned;
    result => sh_result          -- out unsigned
   );

  -- Load alignment
  lda:entity work.n2aligner
   port map (
    -- align/sign-extend load data inputs
    ld_op  => lsu_op_reg,  -- in  natural range 0 to 7; -- memory(LSU) unit internal opcode
    a      => dm_readdata, -- in  unsigned(31 downto 0);
    bi     => readdata_bi, -- in  unsigned(1  downto 0); -- byte index of LS byte of load result in a
    result => ld_result    -- out unsigned
   );

  -- program counter/jumps/branches
  iu_update_addr <= PH_Execute or (PH_Regfile1 and (jump_class /= JUMP_CLASS_OTHERS or is_br));
  iu:entity work.n2program_counter
   generic map (RESET_ADDR => RESET_ADDR)
   port map (
    clk           => clk,                                   -- in  std_logic;
    s_reset       => s_reset,                               -- in  boolean; -- synchronous reset
    calc_nextpc   => PH_Decode,                             -- in  boolean;
    update_addr   => iu_update_addr,                        -- in  boolean;
    jump_class    => jump_class,                            -- in  jump_class_t;
    branch        => PH_Branch,                             -- in  boolean;
    branch_taken  => alu_sh_result(0)='1' or is_br_reg,     -- in  boolean;
    imm26         => instr_imm26,                           -- in  unsigned(25 downto 0);
    reg_a         => rf_readdata,                           -- in  unsigned(31 downto 0);
    addr          => pc,                                    -- out unsigned(31 downto 2)
    nextpc        => nextpc                                 -- out unsigned(31 downto 2)
   );

  to_PH_Regfile2 <= is_srcreg_b_reg and not is_b_zero;
  process (clk)
  begin
    if rising_edge(clk) then
      dm_write <= '0';
      dstreg_wren <= false;
      ld_wren     <= false;
      is_srcreg_b_reg <= is_srcreg_b;
      is_call_reg     <= is_call;
      is_next_pc_reg  <= is_next_pc;
      is_b_zero <= (instr_b = 0);
      is_br_reg   <= false;
      is_load     <= false;
      is_store    <= false;

      PH_Fetch        <= false;
      PH_Decode       <= false;
      PH_Regfile1     <= false;
      PH_Regfile2     <= false;
      PH_Execute      <= false;
      PH_Branch       <= false;
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
          src_sel_ab <= false;
        end if;

        if PH_Decode then
          PH_Regfile1 <= true;
        end if;

        if PH_Regfile1 then
          if jump_class/=JUMP_CLASS_OTHERS then
            PH_Fetch  <= true; -- last execution stage of direct and inderect jumps
          elsif is_br then
            PH_Fetch  <= true; -- last execution stage of unconditional branch
            PH_Branch <= true;
            is_br_reg <= true;
          elsif to_PH_Regfile2 then
            PH_Regfile2 <= true;
            src_sel_ab <= true;
          else
            PH_Execute  <= true;
          end if;
        end if;

        if PH_Regfile2 then
          PH_Execute <= true;
        end if;

        if PH_Execute then
          dstreg_wren <= writeback_ex;
          if is_load then
            PH_Load_Address <= true;
          else
            PH_Fetch <= true;
            if is_store then
              dm_write <= '1';
            end if;
            if instr_class=INSTR_CLASS_BRANCH then
              PH_Branch <= true;
            end if;
          end if;
        end if;

        if PH_Branch then
          PH_Fetch <= true;
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
          ld_wren <= true;
          if is_tcm_reg or avm_readdatavalid='1' then
            dstreg_wren <= true;
            PH_Fetch <= true;
          else
            PH_Load_Data <= true;
          end if;
        end if;
      end if;

      if PH_Regfile1 then
        lsu_op_reg <= mem_op_i mod 8;
        is_load    <= instr_class=INSTR_CLASS_MEMORY and mem_op_u(MEM_OP_BIT_STORE)='0';
        is_store   <= instr_class=INSTR_CLASS_MEMORY and mem_op_u(MEM_OP_BIT_STORE)='1';
      end if;

    end if;
  end process;

  process (clk)
  begin
    if rising_edge(clk) then
      -- register file access
      if PH_Regfile1 then
        reg_a <= rf_readdata; -- latch register A
      end if;

      -- alu/shifter result mux
      if PH_Execute then
        -- agu_result <= rf_readdata + unsigned(resize(signed(instr_imm16), 32));
        if instr_class=INSTR_CLASS_ALU then
          alu_sh_result <= alu_result;
        else
          alu_sh_result <= sh_result;
        end if;
      end if;
    end if;
  end process;

  process (all)
    constant sel_imm : natural := 0;
    constant sel_rf  : natural := 1;
    constant sel_0   : natural := 2;
    constant sel_1   : natural := 3;
    subtype l_sel_t is natural range sel_imm to sel_0;
    subtype h_sel_t is natural range sel_imm to sel_1;
    variable l_sel : l_sel_t;
    variable h_sel : h_sel_t;
  begin

    -- 1st source operand mux
    if src_sel_ab then
      src_a <= reg_a;
    else
      src_a <= rf_readdata;
    end if;

    -- 2nd source operand mux
    if is_srcreg_b_reg then
      if is_b_zero then
        l_sel := sel_0;
        h_sel := sel_0;
      else
        l_sel := sel_rf ;
        h_sel := sel_rf ;
      end if;
    elsif imm16_class = IMM16_CLASS_h16 then
      l_sel := sel_0;
      h_sel := sel_imm;
    else
      l_sel := sel_imm;
      if imm16_class = IMM16_CLASS_s16 and instr_imm16(15)='1' then
        h_sel := sel_1;
      else
        h_sel := sel_0;
      end if;
    end if;

    case l_sel is
      when sel_imm => src_b(15 downto 0) <= instr_imm16;
      when sel_rf  => src_b(15 downto 0) <= rf_readdata(15 downto 0);
      when sel_0   => src_b(15 downto 0) <= (others => '0');
    end case;

    case h_sel is
      when sel_imm => src_b(31 downto 16) <= instr_imm16;
      when sel_rf  => src_b(31 downto 16) <= rf_readdata(31 downto 16);
      when sel_0   => src_b(31 downto 16) <= (others => '0');
      when sel_1   => src_b(31 downto 16) <= (others => '1');
    end case;
  end process;

  -- RF read sequence when register B is not a source
  -- phase       Decode Regfile1 Execute Store
  -- read_en     1      0        1       x
  -- rdaddr      A      B        B       x
  -- q           x      reg_a    reg_a   reg_b
  -- src_sel_ab  0      0        0       0
  --
  -- RF read sequence when register B is source
  -- phase       Decode Regfile1 Regfile2 Execute
  -- read_en     1      1        0        1
  -- rdaddr      A      B        B        B
  -- q           x      reg_a    reg_b   reg_b
  -- src_sel_ab  0      0        1        1
  rf_read_en <= PH_Decode or PH_Execute or (PH_Regfile1 and to_PH_Regfile2);
  rf_rdaddr <= to_integer(instr_a) when PH_Decode else to_integer(instr_b);
  rf_wraddr <= dst_reg_i;
  rf_wrdata_exu <= ld_result when ld_wren else alu_sh_result;
  rf_wrnextpc <= (is_call_reg or is_next_pc_reg) and PH_Regfile1;
  rf:entity work.n2register_file
   port map (
    clk         => clk,            -- in  std_logic;
    read_en     => rf_read_en,     -- in  boolean;
    rdaddr      => rf_rdaddr,      -- in  natural range 0 to 31;
    wraddr      => rf_wraddr,      -- in  natural range 0 to 31;
    nextpc      => nextpc,         -- in  unsigned(31 downto 2);
    wrnextpc    => rf_wrnextpc,    -- in  boolean;
    wrdata_exu  => rf_wrdata_exu,  -- in  unsigned(31 downto 0);
    dstreg_wren => dstreg_wren,    -- in  boolean;
    -- read result q available on the next clock after rdaddr
    q => rf_readdata -- out unsigned(31 downto 0)
  );


  -- data bus address/writedata/byteenable/readdata_bi
  process (all)
    variable addr : u32;
    variable bi : natural range 0 to 3;
  begin
    addr := alu_sh_result;
    -- addr := agu_result;
    bi := to_integer(readdata_bi);
    byteenable <= (others => '0');
    case lsu_op_reg mod 4 is
      when MEM_OP_B =>
        byteenable(bi) <= '1';
        writedata_mux <= rf_readdata_b & rf_readdata_b & rf_readdata_b & rf_readdata_b;

      when MEM_OP_H =>
        byteenable((bi/2)*2+0) <= '1';
        byteenable((bi/2)*2+1) <= '1';
        writedata_mux <= rf_readdata_h & rf_readdata_h;

      when others =>
        byteenable <= (others => '1');
        writedata_mux <= rf_readdata;
    end case;

    dm_address(CPU_ADDR_WIDTH-1 downto 2) <= std_logic_vector(addr(CPU_ADDR_WIDTH-1 downto 2));
    dm_address(1 downto 0) <= (others => '0');

    is_tcm <= (to_integer(addr)/2**TCM_ADDR_WIDTH)=TCM_REGION_IDX;
  end process;

  tcm_rdaddress <=
    dm_address(TCM_ADDR_WIDTH-1 downto 2) when PH_Load_Address else
    std_logic_vector(pc(TCM_ADDR_WIDTH-1 downto 2));
  tcm_wraddress  <= dm_address(TCM_ADDR_WIDTH-1 downto 2);
  tcm_byteenable <= byteenable;
  tcm_writedata  <= writedata;
  tcm_write <= dm_write when is_tcm else '0';

  avm_address    <= dm_address;
  avm_byteenable <= byteenable;
  writedata      <= std_logic_vector(writedata_mux);
  avm_writedata  <= writedata;
  avm_write      <= dm_write when not is_tcm else '0';
  avm_read       <= '1' when PH_Load_Address and not is_tcm else '0';

  process (clk)
  begin
    if rising_edge(clk) then
      -- if PH_Load_Address and not is_tcm then avm_read <= '1'; else avm_read <= '0'; end if;
      if is_tcm_reg then
        dm_readdata <= tcm_readdata;
      else
        dm_readdata <= avm_readdata;
      end if;
    end if;
  end process;

end architecture a;
