library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.n2decode_definitions.all;

entity n2decode is
 port (
  clk          : in  std_logic;
  start        : in  boolean;
  instruction  : in  unsigned(31 downto 0);
  -- decode results are available on the next clock after start
  r_type       : buffer boolean;
  instr_class  : out instr_class_t;
  srcreg_class : out src_reg_class_t;
  dstreg_class : out dest_reg_class_t;
  imm16_class  : out imm16_class_t;
  fu_op        : out natural range 0 to 15  -- ALU, shift or memory(LSU) unit internal opcode
 );
end entity n2decode;

use work.nios2_opcodes.all;
use work.alu_opcodes.all;
use work.shifter_opcodes.all;
use work.memory_opcodes.all;

architecture a of n2decode is
  -- instruction fields
  alias op    : unsigned(5  downto 0) is instruction( 5 downto  0);
  -- alias imm16 : unsigned(15 downto 0) is instruction(21 downto  6); -- I-type
  -- alias b     : unsigned(4  downto 0) is instruction(26 downto 22); -- I-type and R-type
  -- alias a     : unsigned(4  downto 0) is instruction(31 downto 27); -- I-type and R-type
  -- alias imm5  : unsigned(4  downto 0) is instruction(10 downto  6); -- R-type
  alias opx   : unsigned(5  downto 0) is instruction(16 downto 11); -- R-type
  -- alias c     : unsigned(4  downto 0) is instruction(21 downto 17); -- R-type
  -- alias imm26 : unsigned(25 downto 0) is instruction(31 downto  6); -- J-type
  
  signal op_reg : unsigned(5  downto 0);
begin

  process (clk)
  begin
    if rising_edge(clk) then
      if start then
        op_reg <= op;
        r_type <= false;
        if op=OP_RTYPE then
          r_type <= true;
          op_reg <= opx;
        end if;
      end if;
    end if;
  end process;

  process(all)
  begin

    instr_class  <= INSTR_CLASS_ALU;
    srcreg_class <= SRC_REG_CLASS_NONE;
    imm16_class  <= IMM16_CLASS_z16;
    dstreg_class <= DEST_REG_CLASS_NONE;
    fu_op        <= 0;

    if not r_type then 
      case to_integer(op_reg) is
        when OP_CALL =>
          instr_class  <= INSTR_CLASS_JUMP;
          dstreg_class <= DEST_REG_CLASS_CALL;

        when OP_JMPI =>
          instr_class  <= INSTR_CLASS_JUMP;

        when OP_LDBU  =>
          instr_class  <= INSTR_CLASS_MEMORY;
          srcreg_class <= SRC_REG_CLASS_A;
          imm16_class  <= IMM16_CLASS_s16;
          dstreg_class <= DEST_REG_CLASS_B;
          fu_op        <= MEM_OP_LDBU;

        when OP_ADDI  =>
          srcreg_class <= SRC_REG_CLASS_A;
          imm16_class  <= IMM16_CLASS_s16;
          dstreg_class <= DEST_REG_CLASS_B;
          fu_op        <= ALU_OP_ADD;

        when OP_STB   =>
          instr_class  <= INSTR_CLASS_MEMORY;
          srcreg_class <= SRC_REG_CLASS_A;
          imm16_class  <= IMM16_CLASS_s16;
          fu_op        <= MEM_OP_STB;

        when OP_BR    =>
          instr_class  <= INSTR_CLASS_BRANCH;
          imm16_class  <= IMM16_CLASS_s16;
          fu_op        <= ALU_OP_TRUE;

        when OP_LDB   =>
          instr_class  <= INSTR_CLASS_MEMORY;
          srcreg_class <= SRC_REG_CLASS_A;
          imm16_class  <= IMM16_CLASS_s16;
          dstreg_class <= DEST_REG_CLASS_B;
          fu_op        <= MEM_OP_LDB;

        when OP_CMPGEI =>
          srcreg_class <= SRC_REG_CLASS_A;
          imm16_class  <= IMM16_CLASS_s16;
          dstreg_class <= DEST_REG_CLASS_B;
          fu_op        <= ALU_OP_CMPGE;

        when OP_LDHU  =>
          instr_class  <= INSTR_CLASS_MEMORY;
          srcreg_class <= SRC_REG_CLASS_A;
          imm16_class  <= IMM16_CLASS_s16;
          dstreg_class <= DEST_REG_CLASS_B;
          fu_op        <= MEM_OP_LDHU;

        when OP_ANDI  =>
          srcreg_class <= SRC_REG_CLASS_A;
          dstreg_class <= DEST_REG_CLASS_B;
          fu_op        <= ALU_OP_AND;

        when OP_STH   =>
          instr_class  <= INSTR_CLASS_MEMORY;
          srcreg_class <= SRC_REG_CLASS_A;
          imm16_class  <= IMM16_CLASS_s16;
          fu_op        <= MEM_OP_STH;

        when OP_BGE   =>
          instr_class  <= INSTR_CLASS_BRANCH;
          srcreg_class <= SRC_REG_CLASS_AB;
          imm16_class  <= IMM16_CLASS_s16;
          fu_op        <= ALU_OP_CMPGE;

        when OP_LDH   =>
          instr_class  <= INSTR_CLASS_MEMORY;
          srcreg_class <= SRC_REG_CLASS_A;
          imm16_class  <= IMM16_CLASS_s16;
          dstreg_class <= DEST_REG_CLASS_B;
          fu_op        <= MEM_OP_LDH;

        when OP_CMPLTI  =>
          srcreg_class <= SRC_REG_CLASS_A;
          imm16_class  <= IMM16_CLASS_s16;
          dstreg_class <= DEST_REG_CLASS_B;
          fu_op        <= ALU_OP_CMPLT;

        when OP_INITDA  =>
          null;

        when OP_ORI     =>
          srcreg_class <= SRC_REG_CLASS_A;
          dstreg_class <= DEST_REG_CLASS_B;
          fu_op        <= ALU_OP_OR;

        when OP_STW     =>
          instr_class  <= INSTR_CLASS_MEMORY;
          srcreg_class <= SRC_REG_CLASS_A;
          imm16_class  <= IMM16_CLASS_s16;
          fu_op        <= MEM_OP_STW;

        when OP_BLT     =>
          instr_class  <= INSTR_CLASS_BRANCH;
          srcreg_class <= SRC_REG_CLASS_AB;
          imm16_class  <= IMM16_CLASS_s16;
          fu_op        <= ALU_OP_CMPLT;

        when OP_LDW     =>
          instr_class  <= INSTR_CLASS_MEMORY;
          srcreg_class <= SRC_REG_CLASS_A;
          imm16_class  <= IMM16_CLASS_s16;
          dstreg_class <= DEST_REG_CLASS_B;
          fu_op        <= MEM_OP_LDW;

        when OP_CMPNEI  =>
          srcreg_class <= SRC_REG_CLASS_A;
          imm16_class  <= IMM16_CLASS_s16;
          dstreg_class <= DEST_REG_CLASS_B;
          fu_op        <= ALU_OP_CMPNE;

        when OP_FLUSHDA =>
          null;

        when OP_XORI    =>
          srcreg_class <= SRC_REG_CLASS_A;
          dstreg_class <= DEST_REG_CLASS_B;
          fu_op        <= ALU_OP_XOR;

        when OP_BNE     =>
          instr_class  <= INSTR_CLASS_BRANCH;
          srcreg_class <= SRC_REG_CLASS_AB;
          imm16_class  <= IMM16_CLASS_s16;
          fu_op        <= ALU_OP_CMPNE;

        when OP_CMPEQI  =>
          srcreg_class <= SRC_REG_CLASS_A;
          imm16_class  <= IMM16_CLASS_s16;
          dstreg_class <= DEST_REG_CLASS_B;
          fu_op        <= ALU_OP_CMPEQ;

        when OP_LDBUIO  =>
          instr_class  <= INSTR_CLASS_MEMORY;
          srcreg_class <= SRC_REG_CLASS_A;
          imm16_class  <= IMM16_CLASS_s16;
          dstreg_class <= DEST_REG_CLASS_B;
          fu_op        <= MEM_OP_LDBU;

        when OP_MULI    =>
          null; -- MUL not implemented

        when OP_STBIO   =>
          instr_class  <= INSTR_CLASS_MEMORY;
          srcreg_class <= SRC_REG_CLASS_A;
          imm16_class  <= IMM16_CLASS_s16;
          fu_op        <= MEM_OP_STB;

        when OP_BEQ     =>
          instr_class  <= INSTR_CLASS_BRANCH;
          srcreg_class <= SRC_REG_CLASS_AB;
          imm16_class  <= IMM16_CLASS_s16;
          fu_op        <= ALU_OP_CMPEQ;

        when OP_LDBIO   =>
          instr_class  <= INSTR_CLASS_MEMORY;
          srcreg_class <= SRC_REG_CLASS_A;
          imm16_class  <= IMM16_CLASS_s16;
          dstreg_class <= DEST_REG_CLASS_B;
          fu_op        <= MEM_OP_LDB;

        when OP_CMPGEUI =>
          srcreg_class <= SRC_REG_CLASS_A;
          dstreg_class <= DEST_REG_CLASS_B;
          fu_op        <= ALU_OP_CMPGEU;

        when OP_LDHUIO  =>
          instr_class  <= INSTR_CLASS_MEMORY;
          srcreg_class <= SRC_REG_CLASS_A;
          imm16_class  <= IMM16_CLASS_s16;
          dstreg_class <= DEST_REG_CLASS_B;
          fu_op        <= MEM_OP_LDHU;

        when OP_ANDHI   =>
          srcreg_class <= SRC_REG_CLASS_A;
          imm16_class  <= IMM16_CLASS_h16;
          dstreg_class <= DEST_REG_CLASS_B;
          fu_op        <= ALU_OP_AND;

        when OP_STHIO   =>
          instr_class  <= INSTR_CLASS_MEMORY;
          srcreg_class <= SRC_REG_CLASS_A;
          imm16_class  <= IMM16_CLASS_s16;
          fu_op        <= MEM_OP_STH;

        when OP_BGEU    =>
          instr_class  <= INSTR_CLASS_BRANCH;
          srcreg_class <= SRC_REG_CLASS_AB;
          imm16_class  <= IMM16_CLASS_s16;
          fu_op        <= ALU_OP_CMPGEU;

        when OP_LDHIO   =>
          instr_class  <= INSTR_CLASS_MEMORY;
          srcreg_class <= SRC_REG_CLASS_A;
          imm16_class  <= IMM16_CLASS_s16;
          dstreg_class <= DEST_REG_CLASS_B;
          fu_op        <= MEM_OP_LDH;

        when OP_CMPLTUI =>
          srcreg_class <= SRC_REG_CLASS_A;
          dstreg_class <= DEST_REG_CLASS_B;
          fu_op        <= ALU_OP_CMPLTU;

        when OP_CUSTOM  =>
          null; -- custom instructions not implemented

        when OP_INITD   =>
          null;

        when OP_ORHI    =>
          srcreg_class <= SRC_REG_CLASS_A;
          imm16_class  <= IMM16_CLASS_h16;
          dstreg_class <= DEST_REG_CLASS_B;
          fu_op        <= ALU_OP_OR;

        when OP_STWIO   =>
          instr_class  <= INSTR_CLASS_MEMORY;
          srcreg_class <= SRC_REG_CLASS_A;
          imm16_class  <= IMM16_CLASS_s16;
          fu_op        <= MEM_OP_STW;

        when OP_BLTU    =>
          instr_class  <= INSTR_CLASS_BRANCH;
          srcreg_class <= SRC_REG_CLASS_AB;
          imm16_class  <= IMM16_CLASS_s16;
          fu_op        <= ALU_OP_CMPLTU;

        when OP_LDWIO   =>
          instr_class  <= INSTR_CLASS_MEMORY;
          srcreg_class <= SRC_REG_CLASS_A;
          imm16_class  <= IMM16_CLASS_s16;
          dstreg_class <= DEST_REG_CLASS_B;
          fu_op        <= MEM_OP_LDW;

        when OP_RDPRS   => -- implement as ADDI, TODO
          srcreg_class <= SRC_REG_CLASS_A;
          imm16_class  <= IMM16_CLASS_s16;
          dstreg_class <= DEST_REG_CLASS_B;
          fu_op        <= ALU_OP_ADD;

        when OP_RTYPE   =>
          null;

        when OP_FLUSHD  =>
          null;

        when OP_XORHI   =>
          srcreg_class <= SRC_REG_CLASS_A;
          imm16_class  <= IMM16_CLASS_h16;
          dstreg_class <= DEST_REG_CLASS_B;
          fu_op        <= ALU_OP_XOR;

        when others =>
          null;
      end case;
      
    else -- R-TYPE
    
      case to_integer(op_reg) is
        when OPX_ERET   =>
          null; -- TODO

        when OPX_ROLI   =>
          instr_class  <= INSTR_CLASS_SHIFT;
          srcreg_class <= SRC_REG_CLASS_A;
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

        when OPX_CMPLT  =>
          srcreg_class <= SRC_REG_CLASS_AB;
          dstreg_class <= DEST_REG_CLASS_C;
          fu_op        <= ALU_OP_CMPLT;

        when OPX_SLLI   =>
          instr_class  <= INSTR_CLASS_SHIFT;
          srcreg_class <= SRC_REG_CLASS_A;
          dstreg_class <= DEST_REG_CLASS_C;
          fu_op        <= SHIFTER_OP_SLL;

        when OPX_SLL    =>
          instr_class  <= INSTR_CLASS_SHIFT;
          srcreg_class <= SRC_REG_CLASS_AB;
          dstreg_class <= DEST_REG_CLASS_C;
          fu_op        <= SHIFTER_OP_SLL;

        when OPX_WRPRS  =>
          null; -- TODO

        when OPX_OR     =>
          srcreg_class <= SRC_REG_CLASS_AB;
          dstreg_class <= DEST_REG_CLASS_C;
          fu_op        <= ALU_OP_OR;

        when OPX_MULXSU =>
          null; -- MUL not implemented

        when OPX_CMPNE  =>
          srcreg_class <= SRC_REG_CLASS_AB;
          dstreg_class <= DEST_REG_CLASS_C;
          fu_op        <= ALU_OP_CMPNE;

        when OPX_SRLI   =>
          instr_class  <= INSTR_CLASS_SHIFT;
          srcreg_class <= SRC_REG_CLASS_A;
          dstreg_class <= DEST_REG_CLASS_C;
          fu_op        <= SHIFTER_OP_SRL;

        when OPX_SRL    =>
          instr_class  <= INSTR_CLASS_SHIFT;
          srcreg_class <= SRC_REG_CLASS_AB;
          dstreg_class <= DEST_REG_CLASS_C;
          fu_op        <= SHIFTER_OP_SRL;

        when OPX_NEXTPC =>
          instr_class  <= INSTR_CLASS_COPY;
          srcreg_class <= SRC_REG_CLASS_NEXTPC;
          dstreg_class <= DEST_REG_CLASS_C;

        when OPX_CALLR  =>
          instr_class  <= INSTR_CLASS_JUMP;
          srcreg_class <= SRC_REG_CLASS_A;
          dstreg_class <= DEST_REG_CLASS_CALL;

        when OPX_XOR    =>
          srcreg_class <= SRC_REG_CLASS_AB;
          dstreg_class <= DEST_REG_CLASS_C;
          fu_op        <= ALU_OP_XOR;

        when OPX_MULXSS =>
          null; -- MUL not implemented

        when OPX_CMPEQ  =>
          srcreg_class <= SRC_REG_CLASS_AB;
          dstreg_class <= DEST_REG_CLASS_C;
          fu_op        <= ALU_OP_CMPEQ;

        when OPX_DIVU   =>
          null; -- DIV not implemented

        when OPX_DIV    =>
          null; -- DIV not implemented

        when OPX_RDCTL  =>
          null; -- TODO

        when OPX_MUL    =>
          null; -- MUL not implemented

        when OPX_CMPGEU =>
          srcreg_class <= SRC_REG_CLASS_AB;
          dstreg_class <= DEST_REG_CLASS_C;
          fu_op        <= ALU_OP_CMPGEU;

        when OPX_INITI  =>
          null;

        when OPX_TRAP   =>
          null; -- TODO

        when OPX_WRCTL  =>
          null; -- TODO

        when OPX_CMPLTU =>
          srcreg_class <= SRC_REG_CLASS_AB;
          dstreg_class <= DEST_REG_CLASS_C;
          fu_op        <= ALU_OP_CMPLTU;

        when OPX_ADD    =>
          srcreg_class <= SRC_REG_CLASS_AB;
          dstreg_class <= DEST_REG_CLASS_C;
          fu_op        <= ALU_OP_ADD;

        when OPX_BREAK  =>
          null; -- TODO

        when OPX_SYNC   =>
          null;

        when OPX_SUB    =>
          srcreg_class <= SRC_REG_CLASS_AB;
          dstreg_class <= DEST_REG_CLASS_C;
          fu_op        <= ALU_OP_SUB;

        when OPX_SRAI   =>
          instr_class  <= INSTR_CLASS_SHIFT;
          srcreg_class <= SRC_REG_CLASS_A;
          dstreg_class <= DEST_REG_CLASS_C;
          fu_op        <= SHIFTER_OP_SRA;

        when OPX_SRA    =>
          instr_class  <= INSTR_CLASS_SHIFT;
          srcreg_class <= SRC_REG_CLASS_AB;
          dstreg_class <= DEST_REG_CLASS_C;
          fu_op        <= SHIFTER_OP_SRA;

        when others =>
          null;
      end case;
    end if;

  end process;

end architecture a;
