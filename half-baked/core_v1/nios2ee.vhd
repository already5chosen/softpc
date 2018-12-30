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
  signal pc, nextpc : unsigned(31 downto 2);

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
  signal fu_op_reg_u : unsigned(3 downto 0);  -- unsigned representation of fu_op_i
  signal reg_a, reg_b : u32;
  signal immx         : u32; -- imm16 field, properly extended to 32 bits

  -- ALU/AGU
  signal alu_op : natural range 0 to 15;
  signal alu_result, agu_result : u32;
  signal cmp_result : boolean; -- for branches

  -- shifter
  signal sh_result : u32;

  -- register file access
  signal rf_wrnextpc : boolean;
  signal rf_readdata : u32;
  signal rf_wraddr, rf_rdaddr : natural range 0 to 31;
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
  fu_op_reg_u <= to_unsigned(fu_op_reg_i, 4);
  with imm16_class select
   immx <=
     unsigned(resize(signed(instr_imm16), 32)) when IMM16_CLASS_s16,
     resize(instr_imm16, 32)                   when IMM16_CLASS_z16,
     shift_left(resize(instr_imm16, 32), 16)   when others;

  -- post-decode, results available in PH_Execute stage
  process (clk)
  begin
    if rising_edge(clk) then
      -- ALU/AGU
      if instr_class=INSTR_CLASS_MEMORY then
        alu_op <= ALU_OP_ADD; -- AGU
      else
        alu_op <= fu_op_i;    -- ALU
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

  -- shifter/Load alignment
  sha:entity work.n2shift_align
   port map (
    clk           => clk,               -- in  std_logic;
    instr_class   => instr_class,       -- in  instr_class_t;
    fu_op_i       => fu_op_i,           -- in  natural range 0 to 15; -- ALU, shift or memory(LSU) unit internal opcode
    -- shift/rotate inputs
    a             => reg_a,             -- in  unsigned;
    b             => reg_b(4 downto 0), -- in  unsigned;
    -- align/sign-extend load data inputs
    readdata      => dm_readdata, -- in  unsigned;
    readdata_bi   => to_unsigned(readdata_bi, 2), -- in  unsigned; -- byte index of LS byte of load result in dm_readdata
    readdatavalid => PH_Memory_Data, -- in  boolean;
    -- result
    result        => sh_result  -- out unsigned  -- result latency = 1 clock
   );

  -- program counter/jumps/branches
  iu:entity work.n2program_counter
   generic map (RESET_ADDR => RESET_ADDR)
   port map (
    clk           => clk,                                   -- in  std_logic;
    s_reset       => s_reset,                               -- in  boolean; -- synchronous reset
    fetch         => PH_Fetch,                              -- in  boolean;
    incremet_addr => PH_Regfile1,                           -- in  boolean;
    indirect_jump => PH_Regfile1 and instr_class=INSTR_CLASS_INDIRECT_JUMP, -- in  boolean;
    direct_jump   => PH_Regfile1 and instr_class=INSTR_CLASS_DIRECT_JUMP,   -- in  boolean;
    branch        => PH_Branch,                             -- in  boolean;
    branch_taken  => cmp_result,                            -- in  boolean;
    imm26         => instr_imm26,                           -- in  unsigned(25 downto 0);
    reg_a         => rf_readdata,                           -- in  unsigned(31 downto 0);
    addr          => pc,                                    -- out unsigned(31 downto 2)
    nextpc        => nextpc                                 -- out unsigned(31 downto 2)
   );

  process (clk)
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
      else
        PH_Decode   <= PH_Fetch;
        PH_Regfile1 <= PH_Decode;

        if PH_Regfile1 then
          if instr_class=INSTR_CLASS_DIRECT_JUMP then
            PH_Fetch <= true; -- last execution stage of direct jumps
          elsif instr_class=INSTR_CLASS_INDIRECT_JUMP then
            PH_Fetch <= true; -- last execution stage of indirect jumps
          elsif srcreg_class=SRC_REG_CLASS_AB and instr_b/=0 then
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
          end if;
        end if;

        if PH_Branch then
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
  begin
    if rising_edge(clk) then

      fu_op_reg_i <= fu_op_i;
      -- register file read address
      if PH_Decode then
        instr_s2  <= instr_s1;
        rf_wraddr <= 31; -- prepare for call
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

      -- register file write
      result_sel_alu <= instr_class=INSTR_CLASS_ALU;

    end if;
  end process;

  rf_rdaddr <= to_integer(instr_a) when PH_Decode else to_integer(instr_b);
  rf_wrnextpc <= is_call or is_next_pc;
  rf:entity work.n2register_file
   port map (
    clk         => clk,            -- in  std_logic;
    rdaddr      => rf_rdaddr,      -- in  natural range 0 to 31;
    wraddr      => rf_wraddr,      -- in  natural range 0 to 31;
    nextpc      => nextpc,         -- in  unsigned(31 downto 2);
    wrnextpc    => rf_wrnextpc,    -- in  boolean;
    wrdata0     => alu_result,     -- in  unsigned(31 downto 0);
    wrdata1     => sh_result,      -- in  unsigned(31 downto 0);
    wrdata_sel0 => result_sel_alu, -- in  boolean;
    dstreg_wren => dstreg_wren,    -- in  boolean;
    -- read result q available on the next clock after rdaddr
    q => rf_readdata -- out unsigned(31 downto 0)
  );


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
