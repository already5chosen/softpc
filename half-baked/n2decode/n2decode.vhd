library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.n2decode_definitions.all;

entity n2decode is
 port (
  op           : in  unsigned(5 downto 0);
  opx          : in  unsigned(5 downto 0);
  instr_class  : out instr_class_t;
  srcreg_class : out src_reg_class_t;
  imm_class    : out imm_class_t;
  dstreg_class : out dest_reg_class_t;
  fu_op        : out natural range 0 to 15 -- ALU, shift or memory(LSU) unit internal opcode
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

    instr_class  <= INSTR_CLASS_ALU;
    srcreg_class <= SRC_REG_CLASS_NONE;
    imm_class    <= IMM_CLASS_z16;
    dstreg_class <= DEST_REG_CLASS_NONE;
    fu_op        <= 0;

    case to_integer(op) is
      when OP_CALL =>
        instr_class  <= INSTR_CLASS_JUMP;
        imm_class    <= IMM_CLASS_26;
        dstreg_class <= DEST_REG_CLASS_CALL;

      when OP_JMPI =>
        instr_class  <= INSTR_CLASS_JUMP;
        imm_class    <= IMM_CLASS_26;

      when OP_LDBU  =>
        instr_class  <= INSTR_CLASS_MEMORY;
        srcreg_class <= SRC_REG_CLASS_A;
        imm_class    <= IMM_CLASS_s16;
        dstreg_class <= DEST_REG_CLASS_B;
        fu_op        <= MEM_OP_LDBU;

      when OP_ADDI  =>
        srcreg_class <= SRC_REG_CLASS_A;
        imm_class    <= IMM_CLASS_s16;
        dstreg_class <= DEST_REG_CLASS_B;
        fu_op        <= ALU_OP_ADD;

      when OP_STB   =>
        instr_class  <= INSTR_CLASS_MEMORY;
        srcreg_class <= SRC_REG_CLASS_AB;
        imm_class    <= IMM_CLASS_s16;
        fu_op        <= MEM_OP_STB;

      when OP_BR    =>
        instr_class  <= INSTR_CLASS_BRANCH;
        imm_class    <= IMM_CLASS_s16;
        fu_op        <= ALU_OP_TRUE;

      when OP_LDB   =>
        instr_class  <= INSTR_CLASS_MEMORY;
        srcreg_class <= SRC_REG_CLASS_A;
        imm_class    <= IMM_CLASS_s16;
        dstreg_class <= DEST_REG_CLASS_B;
        fu_op        <= MEM_OP_LDB;

      when OP_CMPGEI =>
        srcreg_class <= SRC_REG_CLASS_A;
        imm_class    <= IMM_CLASS_s16;
        dstreg_class <= DEST_REG_CLASS_B;
        fu_op        <= ALU_OP_CMPGE;

      when OP_LDHU  =>
        instr_class  <= INSTR_CLASS_MEMORY;
        srcreg_class <= SRC_REG_CLASS_A;
        imm_class    <= IMM_CLASS_s16;
        dstreg_class <= DEST_REG_CLASS_B;
        fu_op        <= MEM_OP_LDHU;

      when OP_ANDI  =>
        srcreg_class <= SRC_REG_CLASS_A;
        dstreg_class <= DEST_REG_CLASS_B;
        fu_op        <= ALU_OP_AND;

      when OP_STH   =>
        instr_class  <= INSTR_CLASS_MEMORY;
        srcreg_class <= SRC_REG_CLASS_AB;
        imm_class    <= IMM_CLASS_s16;
        fu_op        <= MEM_OP_STH;

      when OP_BGE   =>
        instr_class  <= INSTR_CLASS_BRANCH;
        srcreg_class <= SRC_REG_CLASS_AB;
        imm_class    <= IMM_CLASS_s16;
        fu_op        <= ALU_OP_CMPGE;

      when OP_LDH   =>
        instr_class  <= INSTR_CLASS_MEMORY;
        srcreg_class <= SRC_REG_CLASS_A;
        imm_class    <= IMM_CLASS_s16;
        dstreg_class <= DEST_REG_CLASS_B;
        fu_op        <= MEM_OP_LDH;

      when OP_CMPLTI  =>
        srcreg_class <= SRC_REG_CLASS_A;
        imm_class    <= IMM_CLASS_s16;
        dstreg_class <= DEST_REG_CLASS_B;
        fu_op        <= ALU_OP_CMPLT;

      when OP_INITDA  =>
        imm_class    <= IMM_CLASS_NONE;

      when OP_ORI     =>
        srcreg_class <= SRC_REG_CLASS_A;
        dstreg_class <= DEST_REG_CLASS_B;
        fu_op        <= ALU_OP_OR;

      when OP_STW     =>
        instr_class  <= INSTR_CLASS_MEMORY;
        srcreg_class <= SRC_REG_CLASS_AB;
        imm_class    <= IMM_CLASS_s16;
        fu_op        <= MEM_OP_STW;

      when OP_BLT     =>
        instr_class  <= INSTR_CLASS_BRANCH;
        srcreg_class <= SRC_REG_CLASS_AB;
        imm_class    <= IMM_CLASS_s16;
        fu_op        <= ALU_OP_CMPLT;

      when OP_LDW     =>
        instr_class  <= INSTR_CLASS_MEMORY;
        srcreg_class <= SRC_REG_CLASS_A;
        imm_class    <= IMM_CLASS_s16;
        dstreg_class <= DEST_REG_CLASS_B;
        fu_op        <= MEM_OP_LDW;

      when OP_CMPNEI  =>
        srcreg_class <= SRC_REG_CLASS_A;
        imm_class    <= IMM_CLASS_s16;
        dstreg_class <= DEST_REG_CLASS_B;
        fu_op        <= ALU_OP_CMPNE;

      when OP_FLUSHDA =>
        imm_class    <= IMM_CLASS_NONE;

      when OP_XORI    =>
        srcreg_class <= SRC_REG_CLASS_A;
        dstreg_class <= DEST_REG_CLASS_B;
        fu_op        <= ALU_OP_XOR;

      when OP_BNE     =>
        instr_class  <= INSTR_CLASS_BRANCH;
        srcreg_class <= SRC_REG_CLASS_AB;
        imm_class    <= IMM_CLASS_s16;
        fu_op        <= ALU_OP_CMPNE;

      when OP_CMPEQI  =>
        srcreg_class <= SRC_REG_CLASS_A;
        imm_class    <= IMM_CLASS_s16;
        dstreg_class <= DEST_REG_CLASS_B;
        fu_op        <= ALU_OP_CMPEQ;

      when OP_LDBUIO  =>
        instr_class  <= INSTR_CLASS_MEMORY;
        srcreg_class <= SRC_REG_CLASS_A;
        imm_class    <= IMM_CLASS_s16;
        dstreg_class <= DEST_REG_CLASS_B;
        fu_op        <= MEM_OP_LDBU;

      when OP_MULI    =>
        imm_class    <= IMM_CLASS_NONE; -- MUL not implemented

      when OP_STBIO   =>
        instr_class  <= INSTR_CLASS_MEMORY;
        srcreg_class <= SRC_REG_CLASS_AB;
        imm_class    <= IMM_CLASS_s16;
        fu_op        <= MEM_OP_STB;

      when OP_BEQ     =>
        instr_class  <= INSTR_CLASS_BRANCH;
        srcreg_class <= SRC_REG_CLASS_AB;
        imm_class    <= IMM_CLASS_s16;
        fu_op        <= ALU_OP_CMPEQ;

      when OP_LDBIO   =>
        instr_class  <= INSTR_CLASS_MEMORY;
        srcreg_class <= SRC_REG_CLASS_A;
        imm_class    <= IMM_CLASS_s16;
        dstreg_class <= DEST_REG_CLASS_B;
        fu_op        <= MEM_OP_LDB;

      when OP_CMPGEUI =>
        srcreg_class <= SRC_REG_CLASS_A;
        dstreg_class <= DEST_REG_CLASS_B;
        fu_op        <= ALU_OP_CMPGEU;

      when OP_LDHUIO  =>
        instr_class  <= INSTR_CLASS_MEMORY;
        srcreg_class <= SRC_REG_CLASS_A;
        imm_class    <= IMM_CLASS_s16;
        dstreg_class <= DEST_REG_CLASS_B;
        fu_op        <= MEM_OP_LDHU;

      when OP_ANDHI   =>
        srcreg_class <= SRC_REG_CLASS_A;
        imm_class    <= IMM_CLASS_h16;
        dstreg_class <= DEST_REG_CLASS_B;
        fu_op        <= ALU_OP_AND;

      when OP_STHIO   =>
        instr_class  <= INSTR_CLASS_MEMORY;
        srcreg_class <= SRC_REG_CLASS_AB;
        imm_class    <= IMM_CLASS_s16;
        fu_op        <= MEM_OP_STH;

      when OP_BGEU    =>
        instr_class  <= INSTR_CLASS_BRANCH;
        srcreg_class <= SRC_REG_CLASS_AB;
        imm_class    <= IMM_CLASS_s16;
        fu_op        <= ALU_OP_CMPGEU;

      when OP_LDHIO   =>
        instr_class  <= INSTR_CLASS_MEMORY;
        srcreg_class <= SRC_REG_CLASS_A;
        imm_class    <= IMM_CLASS_s16;
        dstreg_class <= DEST_REG_CLASS_B;
        fu_op        <= MEM_OP_LDH;

      when OP_CMPLTUI =>
        srcreg_class <= SRC_REG_CLASS_A;
        dstreg_class <= DEST_REG_CLASS_B;
        fu_op        <= ALU_OP_CMPLTU;

      when OP_CUSTOM  =>
        imm_class    <= IMM_CLASS_NONE; -- custom instructions not implemented

      when OP_INITD   =>
        imm_class    <= IMM_CLASS_NONE;

      when OP_ORHI    =>
        srcreg_class <= SRC_REG_CLASS_A;
        imm_class    <= IMM_CLASS_h16;
        dstreg_class <= DEST_REG_CLASS_B;
        fu_op        <= ALU_OP_OR;

      when OP_STWIO   =>
        instr_class  <= INSTR_CLASS_MEMORY;
        srcreg_class <= SRC_REG_CLASS_AB;
        imm_class    <= IMM_CLASS_s16;
        fu_op        <= MEM_OP_STW;

      when OP_BLTU    =>
        instr_class  <= INSTR_CLASS_BRANCH;
        srcreg_class <= SRC_REG_CLASS_AB;
        imm_class    <= IMM_CLASS_s16;
        fu_op        <= ALU_OP_CMPLTU;

      when OP_LDWIO   =>
        instr_class  <= INSTR_CLASS_MEMORY;
        srcreg_class <= SRC_REG_CLASS_A;
        imm_class    <= IMM_CLASS_s16;
        dstreg_class <= DEST_REG_CLASS_B;
        fu_op        <= MEM_OP_LDW;

      when OP_RDPRS   => -- implement as ADDI
        srcreg_class <= SRC_REG_CLASS_A;
        imm_class    <= IMM_CLASS_s16;
        dstreg_class <= DEST_REG_CLASS_B;
        fu_op        <= ALU_OP_ADD;

      when OP_RTYPE   =>
        imm_class    <= IMM_CLASS_NONE;

      when OP_FLUSHD  =>
        imm_class    <= IMM_CLASS_NONE;

      when OP_XORHI   =>
        srcreg_class <= SRC_REG_CLASS_A;
        imm_class    <= IMM_CLASS_h16;
        dstreg_class <= DEST_REG_CLASS_B;
        fu_op        <= ALU_OP_XOR;

      when others =>
        imm_class    <= IMM_CLASS_NONE;
    end case;

    if op=OP_RTYPE then
      case to_integer(opx) is
        when OPX_ERET   =>
          null; -- TODO

        when OPX_ROLI   =>
          instr_class  <= INSTR_CLASS_SHIFT;
          srcreg_class <= SRC_REG_CLASS_A;
          imm_class    <= IMM_CLASS_5;
          dstreg_class <= DEST_REG_CLASS_C;
          fu_op        <= SHIFTER_OP_ROL;

        when OPX_ROL    =>
          instr_class  <= INSTR_CLASS_SHIFT;
          srcreg_class <= SRC_REG_CLASS_AB;
          dstreg_class <= DEST_REG_CLASS_C;
          fu_op        <= SHIFTER_OP_ROL;

        when OPX_FLUSHP =>
          null;

        when OPX_RET    =>
          instr_class  <= INSTR_CLASS_JUMP;
          srcreg_class <= SRC_REG_CLASS_A;
          fu_op        <= ALU_OP_TRUE;

        when OPX_NOR    =>
          srcreg_class <= SRC_REG_CLASS_AB;
          dstreg_class <= DEST_REG_CLASS_C;
          fu_op        <= ALU_OP_NOR;

        when OPX_MULXUU =>
          null; -- MUL not implemented

        when OPX_CMPGE  =>
          srcreg_class <= SRC_REG_CLASS_AB;
          dstreg_class <= DEST_REG_CLASS_C;
          fu_op        <= ALU_OP_CMPGE;

        when OPX_BRET   =>
          null; -- TODO

        when OPX_ROR    =>
          instr_class  <= INSTR_CLASS_SHIFT;
          srcreg_class <= SRC_REG_CLASS_AB;
          dstreg_class <= DEST_REG_CLASS_C;
          fu_op        <= SHIFTER_OP_ROL;

        when OPX_FLUSHI =>
          null;

        when OPX_JMP    =>
          instr_class  <= INSTR_CLASS_JUMP;
          srcreg_class <= SRC_REG_CLASS_A;
          fu_op        <= ALU_OP_TRUE;

        when OPX_AND    =>
          srcreg_class <= SRC_REG_CLASS_AB;
          dstreg_class <= DEST_REG_CLASS_C;
          fu_op        <= ALU_OP_AND;

      when others =>
        null;
      end case;
    end if;

  end process;
end architecture a;
