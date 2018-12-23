library ieee;
use ieee.std_logic_1164.all;

entity nios2ee_test is
	port (
		clk     : in std_logic;
		reset_n : in std_logic
	);
end entity nios2ee_test;


library ieee;
use ieee.numeric_std.all;

library altera_mf;
use altera_mf.altera_mf_components.all;

library nios2ee_peripherals;

architecture rtl of nios2ee_test is
  -- peripheral avalon-mm master signals
  signal avm_waitrequest   : std_logic;                      -- m.waitrequest
  signal avm_readdata      : std_logic_vector(31 downto 0);  --  .readdata
  signal avm_readdatavalid : std_logic;                      --  .readdatavalid
  signal avm_burstcount    : std_logic_vector(0 downto 0);   --  .burstcount
  signal avm_writedata     : std_logic_vector(31 downto 0);  --  .writedata
  signal avm_address       : std_logic_vector(13 downto 0);  --  .address
  signal avm_write         : std_logic;                      --  .write
  signal avm_read          : std_logic;                      --  .read
  signal avm_byteenable    : std_logic_vector(3 downto 0);   --  .byteenable
  -- tightly-coupled memory port
  signal tcm_rdaddress, tcm_wraddress : std_logic_vector(12 downto 2);  -- 32-bit words
  signal tcm_write         : std_logic;
  signal tcm_byteenable    : std_logic_vector(3 downto 0);
  signal tcm_writedata     : std_logic_vector(31 downto 0);
  signal tcm_readdata      : std_logic_vector(31 downto 0);
begin
  periph:entity nios2ee_peripherals.nios2ee_peripherals
    port map (
      c_clk             => clk,               -- in  std_logic                     := '0';             --             c.clk
      r_reset_n         => reset_n,           -- in  std_logic                     := '0'              --             r.reset_n
      jtag_uart_irq_irq => open,              -- out std_logic;                                        -- jtag_uart_irq.irq
      m_waitrequest     => avm_waitrequest  , -- out std_logic;                                        --             m.waitrequest
      m_readdata        => avm_readdata     , -- out std_logic_vector(31 downto 0);                    --              .readdata
      m_readdatavalid   => avm_readdatavalid, -- out std_logic;                                        --              .readdatavalid
      m_burstcount      => avm_burstcount   , -- in  std_logic_vector(0 downto 0)  := (others => '0'); --              .burstcount
      m_writedata       => avm_writedata    , -- in  std_logic_vector(31 downto 0) := (others => '0'); --              .writedata
      m_address         => avm_address      , -- in  std_logic_vector(13 downto 0) := (others => '0'); --              .address
      m_write           => avm_write        , -- in  std_logic                     := '0';             --              .write
      m_read            => avm_read         , -- in  std_logic                     := '0';             --              .read
      m_byteenable      => avm_byteenable   , -- in  std_logic_vector(3 downto 0)  := (others => '0'); --              .byteenable
      m_debugaccess     => open               -- in  std_logic                     := '0';             --              .debugaccess
    );
  avm_burstcount <= std_logic_vector(to_unsigned(1, avm_burstcount'length));

  cpu:entity work.nios2ee
   generic map (
     CPU_ADDR_WIDTH => 14,
     TCM_ADDR_WIDTH => 13,
     RESET_ADDR     => 16,
     TCM_REGION_IDX => 0
   )
   port map (
    clk               => clk,         -- in  std_logic;
    reset             => not reset_n, -- in  std_logic;
    -- tightly-coupled memory (both program and data). Read latency=1 clock
    tcm_rdaddress     => tcm_rdaddress , -- out std_logic_vector(TCM_ADDR_WIDTH-1 downto 2); -- 32-bit words
    tcm_wraddress     => tcm_wraddress , -- out std_logic_vector(TCM_ADDR_WIDTH-1 downto 2); -- 32-bit words
    tcm_write         => tcm_write     , -- out std_logic;
    tcm_byteenable    => tcm_byteenable, -- out std_logic_vector(3 downto 0);
    tcm_writedata     => tcm_writedata , -- out std_logic_vector(31 downto 0);
    tcm_readdata      => unsigned(tcm_readdata), -- in  unsigned(31 downto 0);
    -- avalon-mm master port (data only)
    avm_address       => avm_address      , -- out std_logic_vector(CPU_ADDR_WIDTH-1 downto 0); -- 8-bit bytes, a[1:0]=0
    avm_read          => avm_read         , -- out std_logic;
    avm_write         => avm_write        , -- out std_logic;
    avm_byteenable    => avm_byteenable   , -- out std_logic_vector(3 downto 0);
    avm_writedata     => avm_writedata    , -- out std_logic_vector(31 downto 0);
    avm_readdata      => unsigned(avm_readdata), -- in  unsigned(31 downto 0);
    avm_waitrequest   => avm_waitrequest  , -- in  std_logic;
    avm_readdatavalid => avm_readdatavalid  -- in  std_logic
  );

	mem:altsyncram
 	 GENERIC MAP (
		byte_size              => 8,
		numwords_a             => 2048,
		numwords_b             => 2048,
		widthad_a              => 11,
		widthad_b              => 11,
		width_a                => 32,
		width_b                => 32,
		width_byteena_a        => 4,
		address_aclr_b         => "NONE",
		address_reg_b          => "CLOCK0",
		clock_enable_input_a   => "BYPASS",
		clock_enable_input_b   => "BYPASS",
		clock_enable_output_b  => "BYPASS",
		init_file              => "mem.hex",
		lpm_type               => "altsyncram",
		operation_mode         => "DUAL_PORT",
		outdata_aclr_b         => "NONE",
		outdata_reg_b          => "UNREGISTERED",
		power_up_uninitialized => "FALSE",
		read_during_write_mode_mixed_ports => "DONT_CARE"
	)
	PORT MAP (
		address_a => tcm_wraddress,
		address_b => tcm_rdaddress,
		byteena_a => tcm_byteenable,
		clock0    => clk,
		data_a    => tcm_writedata,
		wren_a    => tcm_write,
		q_b       => tcm_readdata
	);

end architecture rtl;

