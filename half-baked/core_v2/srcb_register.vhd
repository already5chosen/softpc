library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.n2decode_definitions.all;

entity srcb_register is
 port (
  clk         : in  std_logic;
  imm16_class : in  imm16_class_t;
  imm16       : in  unsigned(15 downto 0);
  ena1        : in  boolean;
  ena1z       : in  boolean;
  d2          : in  unsigned(31 downto 0);
  ena2        : in  boolean;
  q           : out unsigned(31 downto 0)
 );
end entity srcb_register;

architecture a of srcb_register is
begin
  process (clk)
    constant sel_imm : natural := 0;
    constant sel_reg : natural := 1;
    constant sel_0   : natural := 2;
    constant sel_1   : natural := 3;
    subtype l_sel_t is natural range sel_imm to sel_0;
    subtype h_sel_t is natural range sel_imm to sel_1;
    variable l_sel : l_sel_t;
    variable h_sel : h_sel_t;
  begin
    if rising_edge(clk) then
      if ena1 then
        if ena1z then
           l_sel := sel_0;
           h_sel := sel_0;
        elsif imm16_class = IMM16_CLASS_h16 then
           l_sel := sel_0;
           h_sel := sel_imm;
        else
           l_sel := sel_imm;
           if imm16_class = IMM16_CLASS_s16 and imm16(15)='1' then
             h_sel := sel_1;
           else
             h_sel := sel_0;
           end if;
        end if;
      else
        l_sel := sel_reg;
        h_sel := sel_reg;
      end if;

      case l_sel is
        when sel_imm => q(15 downto 0) <= imm16;
        when sel_reg => q(15 downto 0) <= d2(15 downto 0);
        when sel_0   => q(15 downto 0) <= (others => '0');
      end case;

      case h_sel is
        when sel_imm => q(31 downto 16) <= imm16;
        when sel_reg => q(31 downto 16) <= d2(31 downto 16);
        when sel_0   => q(31 downto 16) <= (others => '0');
        when sel_1   => q(31 downto 16) <= (others => '1');
      end case;
    end if;
  end process;
end architecture a;
