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
  r_type       : out boolean;
  jump_class   : out jump_class_t;
  instr_class  : out instr_class_t;
  is_br        : out boolean;  -- unconditional branch
  is_srcreg_b  : out boolean;  -- true when r[B] is source for ALU, Branch or shift operation, but not for stores
  writeback_ex : out boolean;  -- true when destination register is updated with result of PH_execute stage
  is_call      : out boolean;  -- active for call instructions on the next clock after start
  is_next_pc   : out boolean;  -- active for nextpc instruction on the next clock after start
  imm16_class  : out imm16_class_t;
  shifter_op   : out natural range 0 to 7;  -- shift/rotate unit internal opcode
  mem_op       : out natural range 0 to 15; -- memory(LSU) unit internal opcode
  alu_op       : out natural range 0 to 15  -- ALU unit internal opcode
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
  alias b     : unsigned(4  downto 0) is instruction(26 downto 22); -- I-type and R-type
  -- alias a     : unsigned(4  downto 0) is instruction(31 downto 27); -- I-type and R-type
  -- alias imm5  : unsigned(4  downto 0) is instruction(10 downto  6); -- R-type
  alias opx   : unsigned(5  downto 0) is instruction(16 downto 11); -- R-type
  -- alias c     : unsigned(4  downto 0) is instruction(21 downto 17); -- R-type
  -- alias imm26 : unsigned(25 downto 0) is instruction(31 downto  6); -- J-type

  signal op_reg   : unsigned(5  downto 0);
begin

  process (clk)
  begin
    if rising_edge(clk) then
      is_call  <= false;
      is_next_pc <= false;

      if start then
        op_reg <= op;
        r_type <= false;
        is_call <= op=OP_CALL;
        case to_integer(op) is
          when OP_CALL => jump_class <= JUMP_CLASS_DIRECT;
          when OP_JMPI => jump_class <= JUMP_CLASS_DIRECT;
          when others  => jump_class <= JUMP_CLASS_OTHERS;
        end case;
        if op=OP_RTYPE then
          r_type <= true;
          op_reg <= opx;
          is_call <= opx=OPX_CALLR;
          is_next_pc <= opx=OPX_NEXTPC;
          case to_integer(opx) is
            when OPX_RET   => jump_class <= JUMP_CLASS_INDIRECT;
            when OPX_JMP   => jump_class <= JUMP_CLASS_INDIRECT;
            when OPX_CALLR => jump_class <= JUMP_CLASS_INDIRECT;
            when others => null;
          end case;
        end if;
      end if;
    end if;
  end process;

  process(all)
  begin

    -- jump_class   <= JUMP_CLASS_OTHERS;
    instr_class  <= INSTR_CLASS_ALU;
    imm16_class  <= IMM16_CLASS_s16;
    writeback_ex <= false;
    alu_op       <= ALU_OP_ADD;
    is_br        <= false;

    if not r_type then
      is_srcreg_b <= (op_reg mod 4) = 2; -- branches and nops
      case to_integer(op_reg) is
        when OP_CALL =>
          -- jump_class   <= JUMP_CLASS_DIRECT;
          null;

        when OP_JMPI =>
          -- jump_class   <= JUMP_CLASS_DIRECT;
          null;

        when OP_LDBU  =>
          instr_class  <= INSTR_CLASS_MEMORY;
          alu_op       <= ALU_OP_ADD;

        when OP_ADDI  =>
          writeback_ex <= true;
          alu_op       <= ALU_OP_ADD;

        when OP_STB   =>
          instr_class  <= INSTR_CLASS_MEMORY;
          alu_op       <= ALU_OP_ADD;

        when OP_BR    =>
          instr_class  <= INSTR_CLASS_BRANCH;
          is_br        <= true;

        when OP_LDB   =>
          instr_class  <= INSTR_CLASS_MEMORY;
          alu_op       <= ALU_OP_ADD;

        when OP_CMPGEI =>
          writeback_ex <= true;
          alu_op       <= ALU_OP_CMPGE;

        when OP_LDHU  =>
          instr_class  <= INSTR_CLASS_MEMORY;
          alu_op       <= ALU_OP_ADD;

        when OP_ANDI  =>
          imm16_class  <= IMM16_CLASS_z16;
          writeback_ex <= true;
          alu_op       <= ALU_OP_AND;

        when OP_STH   =>
          instr_class  <= INSTR_CLASS_MEMORY;
          alu_op       <= ALU_OP_ADD;

        when OP_BGE   =>
          instr_class  <= INSTR_CLASS_BRANCH;
          alu_op       <= ALU_OP_CMPGE;

        when OP_LDH   =>
          instr_class  <= INSTR_CLASS_MEMORY;
          alu_op       <= ALU_OP_ADD;

        when OP_CMPLTI  =>
          writeback_ex <= true;
          alu_op       <= ALU_OP_CMPLT;

        when OP_INITDA  =>
          null;

        when OP_ORI     =>
          imm16_class  <= IMM16_CLASS_z16;
          writeback_ex <= true;
          alu_op       <= ALU_OP_OR;

        when OP_STW     =>
          instr_class  <= INSTR_CLASS_MEMORY;
          alu_op       <= ALU_OP_ADD;

        when OP_BLT     =>
          instr_class  <= INSTR_CLASS_BRANCH;
          alu_op       <= ALU_OP_CMPLT;

        when OP_LDW     =>
          instr_class  <= INSTR_CLASS_MEMORY;
          alu_op       <= ALU_OP_ADD;

        when OP_CMPNEI  =>
          writeback_ex <= true;
          alu_op       <= ALU_OP_CMPNE;

        when OP_FLUSHDA =>
          null;

        when OP_XORI    =>
          imm16_class  <= IMM16_CLASS_z16;
          writeback_ex <= true;
          alu_op       <= ALU_OP_XOR;

        when OP_BNE     =>
          instr_class  <= INSTR_CLASS_BRANCH;
          alu_op       <= ALU_OP_CMPNE;

        when OP_CMPEQI  =>
          writeback_ex <= true;
          alu_op       <= ALU_OP_CMPEQ;

        when OP_LDBUIO  =>
          instr_class  <= INSTR_CLASS_MEMORY;
          alu_op       <= ALU_OP_ADD;

        when OP_MULI    =>
          null; -- MUL not implemented

        when OP_STBIO   =>
          instr_class  <= INSTR_CLASS_MEMORY;
          alu_op       <= ALU_OP_ADD;

        when OP_BEQ     =>
          instr_class  <= INSTR_CLASS_BRANCH;
          alu_op       <= ALU_OP_CMPEQ;

        when OP_LDBIO   =>
          instr_class  <= INSTR_CLASS_MEMORY;
          alu_op       <= ALU_OP_ADD;

        when OP_CMPGEUI =>
          imm16_class  <= IMM16_CLASS_z16;
          writeback_ex <= true;
          alu_op       <= ALU_OP_CMPGEU;

        when OP_LDHUIO  =>
          instr_class  <= INSTR_CLASS_MEMORY;
          alu_op       <= ALU_OP_ADD;

        when OP_ANDHI   =>
          imm16_class  <= IMM16_CLASS_h16;
          writeback_ex <= true;
          alu_op       <= ALU_OP_AND;

        when OP_STHIO   =>
          instr_class  <= INSTR_CLASS_MEMORY;
          alu_op       <= ALU_OP_ADD;

        when OP_BGEU    =>
          instr_class  <= INSTR_CLASS_BRANCH;
          alu_op       <= ALU_OP_CMPGEU;

        when OP_LDHIO   =>
          instr_class  <= INSTR_CLASS_MEMORY;
          alu_op       <= ALU_OP_ADD;

        when OP_CMPLTUI =>
          imm16_class  <= IMM16_CLASS_z16;
          writeback_ex <= true;
          alu_op       <= ALU_OP_CMPLTU;

        when OP_CUSTOM  =>
          null; -- custom instructions not implemented

        when OP_INITD   =>
          null;

        when OP_ORHI    =>
          imm16_class  <= IMM16_CLASS_h16;
          writeback_ex <= true;
          alu_op       <= ALU_OP_OR;

        when OP_STWIO   =>
          instr_class  <= INSTR_CLASS_MEMORY;
          alu_op       <= ALU_OP_ADD;

        when OP_BLTU    =>
          instr_class  <= INSTR_CLASS_BRANCH;
          alu_op       <= ALU_OP_CMPLTU;

        when OP_LDWIO   =>
          instr_class  <= INSTR_CLASS_MEMORY;
          alu_op       <= ALU_OP_ADD;

        when OP_RDPRS   =>
          null; -- not implemented

        when OP_RTYPE   =>
          null;

        when OP_FLUSHD  =>
          null;

        when OP_XORHI   =>
          imm16_class  <= IMM16_CLASS_h16;
          writeback_ex <= true;
          alu_op       <= ALU_OP_XOR;

        when others =>
          null;
      end case;

    else -- R-TYPE

      is_srcreg_b <= (op_reg mod 8) /= 2; -- everything except shifts/rotates by immediate
      case to_integer(op_reg) is
        when OPX_ERET   =>
          null; -- TODO

        when OPX_ROLI   =>
          instr_class  <= INSTR_CLASS_SHIFT;
          writeback_ex <= true;

        when OPX_ROL    =>
          instr_class  <= INSTR_CLASS_SHIFT;
          writeback_ex <= true;

        when OPX_FLUSHP =>
          null;

        when OPX_RET    =>
          -- jump_class   <= JUMP_CLASS_INDIRECT;
          null;

        when OPX_NOR    =>
          writeback_ex <= true;
          alu_op       <= ALU_OP_NOR;

        when OPX_MULXUU =>
          null; -- MUL not implemented

        when OPX_CMPGE  =>
          writeback_ex <= true;
          alu_op       <= ALU_OP_CMPGE;

        when OPX_BRET   =>
          null; -- TODO

        when OPX_ROR    =>
          instr_class  <= INSTR_CLASS_SHIFT;
          writeback_ex <= true;

        when OPX_FLUSHI =>
          null;

        when OPX_JMP    =>
          -- jump_class   <= JUMP_CLASS_INDIRECT;
          null;

        when OPX_AND    =>
          writeback_ex <= true;
          alu_op       <= ALU_OP_AND;

        when OPX_CMPLT  =>
          writeback_ex <= true;
          alu_op       <= ALU_OP_CMPLT;

        when OPX_SLLI   =>
          instr_class  <= INSTR_CLASS_SHIFT;
          writeback_ex <= true;

        when OPX_SLL    =>
          instr_class  <= INSTR_CLASS_SHIFT;
          writeback_ex <= true;

        when OPX_WRPRS  =>
          null; -- TODO

        when OPX_OR     =>
          writeback_ex <= true;
          alu_op       <= ALU_OP_OR;

        when OPX_MULXSU =>
          null; -- MUL not implemented

        when OPX_CMPNE  =>
          writeback_ex <= true;
          alu_op       <= ALU_OP_CMPNE;

        when OPX_SRLI   =>
          instr_class  <= INSTR_CLASS_SHIFT;
          writeback_ex <= true;

        when OPX_SRL    =>
          instr_class  <= INSTR_CLASS_SHIFT;
          writeback_ex <= true;

        when OPX_NEXTPC =>
          null;

        when OPX_CALLR  =>
          -- jump_class   <= JUMP_CLASS_INDIRECT;
          null;

        when OPX_XOR    =>
          writeback_ex <= true;
          alu_op       <= ALU_OP_XOR;

        when OPX_MULXSS =>
          null; -- MUL not implemented

        when OPX_CMPEQ  =>
          writeback_ex <= true;
          alu_op       <= ALU_OP_CMPEQ;

        when OPX_DIVU   =>
          null; -- DIV not implemented

        when OPX_DIV    =>
          null; -- DIV not implemented

        when OPX_RDCTL  =>
          null; -- TODO

        when OPX_MUL    =>
          null; -- MUL not implemented

        when OPX_CMPGEU =>
          writeback_ex <= true;
          alu_op       <= ALU_OP_CMPGEU;

        when OPX_INITI  =>
          null;

        when OPX_TRAP   =>
          null; -- TODO

        when OPX_WRCTL  =>
          null; -- TODO

        when OPX_CMPLTU =>
          writeback_ex <= true;
          alu_op       <= ALU_OP_CMPLTU;

        when OPX_ADD    =>
          writeback_ex <= true;
          alu_op       <= ALU_OP_ADD;

        when OPX_BREAK  =>
          null; -- TODO

        when OPX_SYNC   =>
          null;

        when OPX_SUB    =>
          writeback_ex <= true;
          alu_op       <= ALU_OP_SUB;

        when OPX_SRAI   =>
          instr_class  <= INSTR_CLASS_SHIFT;
          writeback_ex <= true;

        when OPX_SRA    =>
          instr_class  <= INSTR_CLASS_SHIFT;
          writeback_ex <= true;

        when others =>
          null;
      end case;
    end if;

    case to_integer(op_reg)/8 is
      when OPX_ROL/8  => shifter_op <= SHIFTER_OP_ROL;
      when OPX_ROR/8  => shifter_op <= SHIFTER_OP_ROR;
      when OPX_SLL/8  => shifter_op <= SHIFTER_OP_SLL;
      when OPX_SRL/8  => shifter_op <= SHIFTER_OP_SRL;
      when OPX_SRA/8  => shifter_op <= SHIFTER_OP_SRA;
      when others     => shifter_op <= SHIFTER_OP_SRA;
    end case;

    case to_integer(op_reg)/2 is
      when OP_LDBU/2   => mem_op <= MEM_OP_LDBU;
      when OP_STB/2    => mem_op <= MEM_OP_STB;
      when OP_LDB/2    => mem_op <= MEM_OP_LDB;
      when OP_LDHU/2   => mem_op <= MEM_OP_LDHU;
      when OP_STH/2    => mem_op <= MEM_OP_STH;
      when OP_LDH/2    => mem_op <= MEM_OP_LDH;
      when OP_STW/2    => mem_op <= MEM_OP_STW;
      when OP_LDW/2    => mem_op <= MEM_OP_LDW;
      when OP_LDBUIO/2 => mem_op <= MEM_OP_LDBU;
      when OP_STBIO/2  => mem_op <= MEM_OP_STB;
      when OP_LDBIO/2  => mem_op <= MEM_OP_LDB;
      when OP_LDHUIO/2 => mem_op <= MEM_OP_LDHU;
      when OP_STHIO/2  => mem_op <= MEM_OP_STH;
      when OP_LDHIO/2  => mem_op <= MEM_OP_LDH;
      when OP_STWIO/2  => mem_op <= MEM_OP_STW;
      when OP_LDWIO/2  => mem_op <= MEM_OP_LDW;
      when others      => mem_op <= MEM_OP_LDW;
    end case;

  end process;

end architecture a;
