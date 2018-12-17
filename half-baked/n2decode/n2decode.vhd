library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity n2decode is
 port (
  op       : in  unsigned(5 downto 0);
  opx      : in  unsigned(5 downto 0);
  a_is_src : out boolean; -- true = instruction field A is a name of the source register
  b_is_src : out boolean; -- true = instruction field B is a name of the source register
  a_is_dst : out boolean; -- true = instruction field A is a name of the destination register
  b_is_dst : out boolean; -- true = instruction field B is a name of the destination register
  c_is_dst : out boolean; -- true = instruction field C is a name of the destination register
  is_imm26 : out boolean; -- true = J-type instruction with IMM26
  is_imm16 : out boolean; -- true = I-type instruction with IMM16
  is_imm5  : out boolean; -- true = R-type instruction with IMM5
  is_cti   : out boolean; -- true = control transfer instruction
  is_call  : out boolean; -- true = call instruction - implicit destination register r31
  is_alu   : out boolean; -- true = ALU instruction
  is_shift : out boolean; -- true = Shift/Rotate instruction
  is_lsu   : out boolean; -- true = Load/Store instruction
  fu_op    : out natural range 0 to 15 -- ALU, shift or memory(LSU) unit internal opcode
 );
end entity n2decode;

use work.nios2_opcodes.all;
use work.alu_opcodes.all;
use work.shifter_opcodes.all;
use work.memory_opcodes.all;

architecture a of n2decode is
begin
  process(all)
  begin

    a_is_src <= false;
    b_is_src <= false;
    a_is_dst <= false;
    b_is_dst <= false;
    c_is_dst <= false;
    is_imm26 <= false;
    is_imm16 <= true;
    is_imm5  <= false;
    is_cti   <= false;
    is_call  <= false;
    is_alu   <= false;
    is_shift <= false;
    is_lsu   <= false;
    fu_op    <= 0;

    case to_integer(op) is
      when OP_CALL =>
        is_imm16 <= false;
        is_imm26 <= true;
        is_cti   <= true;
        is_call  <= true;
        fu_op    <= ALU_OP_TRUE;

      when OP_JMPI =>
        is_imm16 <= false;
        is_imm26 <= true;
        is_cti   <= true;
        fu_op    <= ALU_OP_TRUE;

      when OP_RTYPE =>
        is_imm16 <= false;

      when OP_LDBU  =>
        is_lsu   <= true;
        a_is_src <= true;
        b_is_dst <= true;
        fu_op    <= MEM_OP_LDBU;

      when OP_ADDI  =>
        is_alu   <= true;
        a_is_src <= true;
        b_is_dst <= true;
        fu_op    <= ALU_OP_ADD;

      when OP_STB   =>
        is_lsu   <= true;
        a_is_src <= true;
        b_is_src <= true;
        fu_op    <= MEM_OP_STB;

      when OP_BR    =>
        is_cti   <= true;
        fu_op    <= ALU_OP_TRUE;

      when OP_LDB   =>
        is_lsu   <= true;
        a_is_src <= true;
        b_is_dst <= true;
        fu_op    <= MEM_OP_LDB;

      when OP_CMPGE =>
        is_alu   <= true;
        a_is_src <= true;
        b_is_dst <= true;
        fu_op    <= ALU_OP_CMPGE;

      when OP_LDHU  =>
        is_lsu   <= true;
        a_is_src <= true;
        b_is_dst <= true;
        fu_op    <= MEM_OP_LDHU;

      when OP_ANDI  =>
        is_alu   <= true;
        a_is_src <= true;
        b_is_dst <= true;
        fu_op    <= ALU_OP_AND;

      when OP_STH   =>
        is_lsu   <= true;
        a_is_src <= true;
        b_is_src <= true;
        fu_op    <= MEM_OP_STH;

      when OP_BGE   =>
        is_cti   <= true;
        a_is_src <= true;
        b_is_src <= true;
        fu_op    <= ALU_OP_CMPGE;

      when OP_LDH   =>
        is_lsu   <= true;
        a_is_src <= true;
        b_is_dst <= true;
        fu_op    <= MEM_OP_LDH;

      when others => null;
    end case;

  end process;
end architecture a;
