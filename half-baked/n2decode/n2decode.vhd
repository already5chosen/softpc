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
  is_immh  : out boolean; -- true = I-type ALU instruction with IMM16 specifying upper half of the data
  is_imm5  : out boolean; -- true = R-type instruction with IMM5
  is_cti   : out boolean; -- true = control transfer instruction
  is_cti_a : out boolean; -- true = control transfer instruction with absolute target (as opposed to PC+4+sIMM16)
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
    is_immh  <= false;
    is_imm5  <= false;
    is_cti   <= false;
    is_cti_a <= false;
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
        is_cti_a <= true;
        is_call  <= true;
        fu_op    <= ALU_OP_TRUE;

      when OP_JMPI =>
        is_imm16 <= false;
        is_imm26 <= true;
        is_cti   <= true;
        is_cti_a <= true;
        fu_op    <= ALU_OP_TRUE;

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

      when OP_CMPLTI  =>
        is_alu   <= true;
        a_is_src <= true;
        b_is_dst <= true;
        fu_op    <= ALU_OP_CMPLT;

      when OP_INITDA  =>
        is_imm16 <= false;

      when OP_ORI     =>
        is_alu   <= true;
        a_is_src <= true;
        b_is_dst <= true;
        fu_op    <= ALU_OP_OR;

      when OP_STW     =>
        is_lsu   <= true;
        a_is_src <= true;
        b_is_src <= true;
        fu_op    <= MEM_OP_STW;

      when OP_BLT     =>
        is_cti   <= true;
        a_is_src <= true;
        b_is_src <= true;
        fu_op    <= ALU_OP_CMPLT;

      when OP_LDW     =>
        is_lsu   <= true;
        a_is_src <= true;
        b_is_dst <= true;
        fu_op    <= MEM_OP_LDW;

      when OP_CMPNEI  =>
        is_alu   <= true;
        a_is_src <= true;
        b_is_dst <= true;
        fu_op    <= ALU_OP_CMPNE;

      when OP_FLUSHDA =>
        is_imm16 <= false;

      when OP_XORI    =>
        is_alu   <= true;
        a_is_src <= true;
        b_is_dst <= true;
        fu_op    <= ALU_OP_XOR;

      when OP_BNE     =>
        is_cti   <= true;
        a_is_src <= true;
        b_is_src <= true;
        fu_op    <= ALU_OP_CMPNE;

      when OP_CMPEQI  =>
        is_alu   <= true;
        a_is_src <= true;
        b_is_dst <= true;
        fu_op    <= ALU_OP_CMPEQ;

      when OP_LDBUIO  =>
        is_lsu   <= true;
        a_is_src <= true;
        b_is_dst <= true;
        fu_op    <= MEM_OP_LDBU;

      when OP_MULI    =>
        is_imm16 <= false; -- MUL not implemented

      when OP_STBIO   =>
        is_lsu   <= true;
        a_is_src <= true;
        b_is_src <= true;
        fu_op    <= MEM_OP_STB;

      when OP_BEQ     =>
        is_cti   <= true;
        a_is_src <= true;
        b_is_src <= true;
        fu_op    <= ALU_OP_CMPEQ;

      when OP_LDBIO   =>
        is_lsu   <= true;
        a_is_src <= true;
        b_is_dst <= true;
        fu_op    <= MEM_OP_LDB;

      when OP_CMPGEUI =>
        is_alu   <= true;
        a_is_src <= true;
        b_is_dst <= true;
        fu_op    <= ALU_OP_CMPGEU;

      when OP_LDHUIO  =>
        is_lsu   <= true;
        a_is_src <= true;
        b_is_dst <= true;
        fu_op    <= MEM_OP_LDHU;

      when OP_ANDHI   =>
        is_alu   <= true;
        a_is_src <= true;
        b_is_dst <= true;
        is_immh  <= true;
        fu_op    <= ALU_OP_AND;

      when OP_STHIO   =>
        is_lsu   <= true;
        a_is_src <= true;
        b_is_src <= true;
        fu_op    <= MEM_OP_STH;

      when OP_BGEU    =>
        is_cti   <= true;
        a_is_src <= true;
        b_is_src <= true;
        fu_op    <= ALU_OP_CMPGEU;

      when OP_LDHIO   =>
        is_lsu   <= true;
        a_is_src <= true;
        b_is_dst <= true;
        fu_op    <= MEM_OP_LDH;

      when OP_CMPLTUI =>
        is_alu   <= true;
        a_is_src <= true;
        b_is_dst <= true;
        fu_op    <= ALU_OP_CMPLTU;

      when OP_CUSTOM  =>
        is_imm16 <= false; -- custom instructions not implemented

      when OP_INITD   =>
        is_imm16 <= false;

      when OP_ORHI    =>
        is_alu   <= true;
        a_is_src <= true;
        b_is_dst <= true;
        is_immh  <= true;
        fu_op    <= ALU_OP_OR;

      when OP_STWIO   =>
        is_lsu   <= true;
        a_is_src <= true;
        b_is_src <= true;
        fu_op    <= MEM_OP_STW;

      when OP_BLTU    =>
        is_cti   <= true;
        a_is_src <= true;
        b_is_src <= true;
        fu_op    <= ALU_OP_CMPLTU;

      when OP_LDWIO   =>
        is_lsu   <= true;
        a_is_src <= true;
        b_is_dst <= true;
        fu_op    <= MEM_OP_LDW;

      when OP_RDPRS   => -- implement as ADDI
        is_alu   <= true;
        a_is_src <= true;
        b_is_dst <= true;
        fu_op    <= ALU_OP_ADD;

      when OP_RTYPE   =>
        is_imm16 <= false;

      when OP_FLUSHD  =>
        is_imm16 <= false;

      when OP_XORHI   =>
        is_alu   <= true;
        a_is_src <= true;
        b_is_dst <= true;
        is_immh  <= true;
        fu_op    <= ALU_OP_XOR;

      when others =>
        is_imm16 <= false;
    end case;

    if op=OP_RTYPE then
      case to_integer(opx) is
        when OPX_ERET   =>
          null; -- TODO

        when OPX_ROLI   =>
          is_shift <= true;
          a_is_src <= true;
          c_is_dst <= true;
          is_imm5  <= true;
          fu_op    <= SHIFTER_OP_ROL;

        when OPX_ROL    =>
          is_shift <= true;
          a_is_src <= true;
          b_is_src <= true;
          c_is_dst <= true;
          fu_op    <= SHIFTER_OP_ROL;

        when OPX_FLUSHP =>
          null;

        when OPX_RET    =>
          is_cti   <= true;
          is_cti_a <= true;
          a_is_src <= true;
          fu_op    <= ALU_OP_TRUE;

        when OPX_NOR    =>
          is_alu   <= true;
          a_is_src <= true;
          b_is_src <= true;
          c_is_dst <= true;
          fu_op    <= ALU_OP_NOR;

        when OPX_MULXUU =>
          null; -- MUL not implemented

        when OPX_CMPGE  =>
          is_alu   <= true;
          a_is_src <= true;
          b_is_src <= true;
          c_is_dst <= true;
          fu_op    <= ALU_OP_CMPGE;

        when OPX_BRET   =>
          null; -- TODO

        when OPX_ROR    =>
          is_shift <= true;
          a_is_src <= true;
          b_is_src <= true;
          c_is_dst <= true;
          fu_op    <= SHIFTER_OP_ROL;

        when OPX_FLUSHI =>
          null;

        when OPX_JMP    =>
          is_cti   <= true;
          is_cti_a <= true;
          a_is_src <= true;
          fu_op    <= ALU_OP_TRUE;

        when OPX_AND    =>
          is_alu   <= true;
          a_is_src <= true;
          b_is_src <= true;
          c_is_dst <= true;
          fu_op    <= ALU_OP_AND;

      when others =>
        null;
      end case;
    end if;

  end process;
end architecture a;
