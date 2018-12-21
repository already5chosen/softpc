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
  tcm_address       : out std_logic_vector(TCM_ADDR_WIDTH-1 downto 2); -- 32-bit words
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
  -- Start driving instruction address on tcm_address.
  -- Write result of the previous instruction into register file.
  constant PH_Decode1 : integer := 1;
  -- drive register file address with index of the first source register
  constant PH_Decode2 : integer := 2;
  -- [Optional] used only by instructions with 2 register sources except for integer stores
  -- drive register file address with index of the second source register
  -- latch value of the first source register
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
  constant PH_Align : integer := 6;
  -- [Optional] used only by memory loads
  -- Align and sign or zero-extend Load data
  -- For Avalon-mm accesses remain at this phase until fabric asserts avm_readdatavalid signal
  subtype phase_t is natural range 0 to PH_Align;
  signal phase : phase_t;

  subtype u32 is unsigned(31 downto 0);
  signal pc      : unsigned(31 downto 2) := to_unsigned(RESET_ADDR/4, 30);
  signal next_pc : unsigned(31 downto 2);

  -- instruction decode signals
  -- alias instr_op    : unsigned(5  downto 0) is tcm_readdata( 5 downto  0);
  alias instr_imm16 : unsigned(15 downto 0) is tcm_readdata(21 downto  6); -- I-type
  alias instr_b     : unsigned(4  downto 0) is tcm_readdata(26 downto 22); -- I-type and R-type
  alias instr_a     : unsigned(4  downto 0) is tcm_readdata(31 downto 27); -- I-type and R-type
  -- alias instr_imm5  : unsigned(4  downto 0) is tcm_readdata(10 downto  6); -- R-type
  -- alias instr_opx   : unsigned(5  downto 0) is tcm_readdata(16 downto 11); -- R-type
  alias instr_c     : unsigned(4  downto 0) is tcm_readdata(21 downto 17); -- R-type
  -- alias instr_imm26 : unsigned(25 downto 0) is tcm_readdata(31 downto  6); -- J-type

  signal instr_class  : instr_class_t;
  signal srcreg_class : src_reg_class_t;
  signal dstreg_class : dest_reg_class_t;
  signal fu_op, fu_op_reg : natural range 0 to 15; -- ALU, shift or memory(LSU) unit internal opcode
  signal reg_b, immx  : u32;
  signal fu_op_reg_u : unsigned(3 downto 0);

  -- ALU/AGU
  signal alu_op : natural range 0 to 15;
  signal alu_result, alu_result_reg : u32;

  -- shifter
  signal sh_op_shift, sh_op_left, sh_op_arith : std_logic;
  signal sh_a, sh_result, sh_result_reg : u32;
  signal sh_b :  unsigned(4 downto 0);

  -- register file
  type rf_t is array (natural range <>) of u32;
  signal rf : rf_t(0 to 31);
  signal rf_q, rf_readdata : u32;
  signal rf_wraddr : natural range 0 to 31;
  signal rf_wren, rf_q_zero : boolean;
  type rf_wrsel_t is (RF_WR_ALU, RF_WR_NEXTPC, RF_WR_SHIFTER);
  signal rf_wrsel : rf_wrsel_t;

  alias rf_readdata_h : unsigned(15 downto 0) is rf_readdata(15 downto 0);
  alias rf_readdata_b : unsigned(7 downto 0)  is rf_readdata(7 downto 0);

  signal is_tcm, is_tcm_reg : boolean;
  -- store data
  signal writedata, dm_readdata : unsigned(31 downto 0);
  signal byteenable : std_logic_vector(3 downto 0);
  signal dm_address : std_logic_vector(CPU_ADDR_WIDTH-1 downto 0); -- 8-bit bytes
  signal dm_write, dm_read : std_logic;
  signal readdata_bi : natural range 0 to 3; -- byte index of LS byte of load result in dm_readdata

begin

  -- instruction decoder
  d:entity work.n2decode
   port map (
    instruction  => tcm_readdata, -- in  unsigned(31 downto 0);
    instr_class  => instr_class , -- out instr_class_t;
    srcreg_class => srcreg_class, -- out src_reg_class_t;
    dstreg_class => dstreg_class, -- out dest_reg_class_t;
    immx         => immx,         -- out unsigned(31 downto 0); -- immediate field, properly extended to 32 bits
    fu_op        => fu_op         -- out natural range 0 to 15  -- ALU, shift or memory(LSU) unit internal opcode
   );
  fu_op_reg_u <= to_unsigned(fu_op_reg, 4);

  -- ALU/AGU
  alu_op <= ALU_OP_ADD when instr_class=INSTR_CLASS_MEMORY else fu_op_reg;
  a:entity work.n2alu
   generic map (DATA_WIDTH => 32)
   port map (
    op     => alu_op     , -- in  natural range 0 to 15;
    a      => rf_readdata, -- in  unsigned(DATA_WIDTH-1 downto 0);
    b      => reg_b      , -- in  unsigned(DATA_WIDTH-1 downto 0);
    result => alu_result  -- out unsigned(DATA_WIDTH-1 downto 0)
   );

  -- shifter (also used for alignment of load data)
  process (all)
  begin
    if phase=PH_Execute then
      -- shift instructions
      sh_op_shift <= fu_op_reg_u(SHIFTER_OP_BIT_SHIFT);
      sh_op_left  <= fu_op_reg_u(SHIFTER_OP_BIT_LEFT);
      sh_op_arith <= fu_op_reg_u(SHIFTER_OP_BIT_ARITH);
      sh_a        <= rf_readdata;
      sh_b        <= reg_b(4 downto 0);
    else
      -- memory load instructions
      sh_op_shift <= '0';
      sh_op_left  <= '0';
      sh_op_arith <= '0';
      sh_a        <= dm_readdata;
      sh_b        <= to_unsigned(readdata_bi*8, 5);
    end if;
  end process;
  sh:entity work.n2shifter
   generic map (DATA_WIDTH => 32, B_WIDTH => 5 )
   port map (
    op_shift => sh_op_shift, -- in std_logic; -- '0' - rotate,      '1' - shift
    op_left  => sh_op_left , -- in std_logic; -- '0' - shift right, '1' - shift left
    op_arith => sh_op_arith, -- in std_logic; -- '0' - arithmetic,  '1' - logical (applicable when op_shift='1' and op_left='0')
    a        => sh_a,        -- in  unsigned(DATA_WIDTH-1 downto 0);
    b        => sh_b,        -- in  unsigned(B_WIDTH-1    downto 0);
    result   => sh_result    -- out unsigned(DATA_WIDTH-1 downto 0)
  );

  process (clk, reset)
  begin
    if reset='1' then
      phase <= PH_Fetch;
      pc    <= to_unsigned(RESET_ADDR/4, 30);
      next_pc <= (others => '0');
      fu_op_reg <= 0;
      alu_result_reg <= (others => '0');
      sh_result_reg  <= (others => '0');
      dm_write <= '0';
      dm_read  <= '0';
      rf_wren   <= false;
      is_tcm_reg <= false;
    elsif rising_edge(clk) then
      dm_write <= '0';
      dm_read  <= '0';
      rf_wren  <= false;
      next_pc  <= pc + 1;
      sh_result_reg <= sh_result;
      case phase is
        when PH_Fetch =>
          phase <= PH_Decode1;

        when PH_Decode1 =>
          fu_op_reg <= fu_op;
          phase  <= PH_Execute;
          if srcreg_class=SRC_REG_CLASS_AB and instr_class /= INSTR_CLASS_MEMORY then
            if instr_b /= 0 then
              phase <= PH_Decode2;
            end if;
          end if;

        when PH_Decode2 =>
          phase  <= PH_Execute;

        when PH_Execute =>
          alu_result_reg <= alu_result;
          phase   <= PH_Fetch;
          pc      <= next_pc;
          rf_wren <= true;
          if instr_class=INSTR_CLASS_BRANCH then
            phase  <= PH_Branch;
          elsif instr_class=INSTR_CLASS_MEMORY then
            phase   <= PH_Memory_Address;
            rf_wren <= false;
            if fu_op_reg_u(MEM_OP_BIT_STORE)='1' then
              dm_write <= '1';
            else
              dm_read  <= '1';
            end if;
          elsif instr_class=INSTR_CLASS_JUMP then
            if srcreg_class=SRC_REG_CLASS_A then
              pc <= rf_readdata(31 downto 2); -- indirect jumps, calls and returns
            else
              pc <= pc;
              pc(27 downto 2) <= reg_b(25 downto 0); -- direct jumps and calls
            end if;
          end if;

        when PH_Branch =>
          if alu_result_reg(0)='1' then
            pc <= pc + unsigned(resize(signed(instr_imm16(15 downto 2)), 30)); -- branch taken
          end if;
          phase  <= PH_Fetch;

        when PH_Memory_Address =>
          dm_write <= dm_write;
          dm_read  <= dm_read;
          is_tcm_reg <= is_tcm;
          if is_tcm or avm_waitrequest='0' then
            dm_write <= '0';
            dm_read  <= '0';
            phase  <= PH_Fetch;
            if dm_read='1' then
              -- TODO - case of avm read with latency=0
              phase  <= PH_Align;
            end if;
          end if;

        when PH_Align =>
          if is_tcm_reg or avm_readdatavalid='1' then
            rf_wren <= true;
            phase  <= PH_Fetch;
          end if;

        when others =>
          -- should never come here
          phase <= PH_Fetch;
          pc    <= to_unsigned(RESET_ADDR/4, 30);
      end case;


    end if;
  end process;

  -- register file access
  process (clk)
    variable rf_rdaddr : natural range 0 to 31;
    variable rf_d      : u32;
  begin
    if rising_edge(clk) then

      -- register file read address
      rf_rdaddr := to_integer(instr_b);
      case phase is
        when PH_Decode1 =>
          reg_b <= immx;
          rf_rdaddr := to_integer(instr_a);
          if srcreg_class=SRC_REG_CLASS_AB and instr_class /= INSTR_CLASS_MEMORY then
            reg_b <= (others => '0');
            if instr_b /= 0 then
              rf_rdaddr := to_integer(instr_b);
            end if;
          end if;

          case instr_class is
            when INSTR_CLASS_JUMP   => rf_wrsel <= RF_WR_NEXTPC;
            when INSTR_CLASS_SHIFT  => rf_wrsel <= RF_WR_SHIFTER;
            when INSTR_CLASS_MEMORY => rf_wrsel <= RF_WR_SHIFTER;
            when others             => rf_wrsel <= RF_WR_ALU;
          end case;

          case dstreg_class is
            when DEST_REG_CLASS_CALL => rf_wraddr <= 31;                  -- ra==r31
            when DEST_REG_CLASS_B    => rf_wraddr <= to_integer(instr_b); -- r[B]
            when DEST_REG_CLASS_C    => rf_wraddr <= to_integer(instr_c); -- r[C]
            when others              => rf_wraddr <= 0;                   -- no destination register
          end case;

        when PH_Decode2 =>
          rf_rdaddr := to_integer(instr_a);
          reg_b <= rf_q; -- latch register B

        when others =>
          null;
      end case;

      -- register file write
      case rf_wrsel is
        when RF_WR_NEXTPC =>
          rf_d(31 downto 2) := next_pc;
          rf_d(1 downto 0)  := (others => '0');
        when RF_WR_SHIFTER =>
          rf_d := sh_result_reg;
        when others =>
          rf_d := alu_result_reg;
      end case;

      if rf_wren then
        rf(rf_wraddr) <= rf_d;
      end if;

      -- register file read
      rf_q <= rf(rf_rdaddr);
      rf_q_zero <= rf_rdaddr=0;

    end if;
  end process;
  rf_readdata <= (others => '0') when rf_q_zero else rf_q;

  -- data bus address/writedata/byteenable/readdata_bi
  process (all)
    variable addr : u32;
    variable bi : natural range 0 to 3;
  begin
    addr := alu_result_reg;
    bi := to_integer(addr) mod 4;
    byteenable <= (others => '0');
    case fu_op_reg mod 4 is
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

  tcm_address <=
    dm_address(TCM_ADDR_WIDTH-1 downto 2) when phase=PH_Memory_Address else
    std_logic_vector(pc(TCM_ADDR_WIDTH-1 downto 2));
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
