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
  fu_op    : out natural range 0 to 15 -- ALU or shift unit internal opcode
 );
end entity n2decode;

use work.nios2_opcodes.all;

architecture a of n2decode is
begin
  process(all)
    variable aIsSrc  : boolean; -- true = instruction field A is a name of the source register
    variable bIsSrc  : boolean; -- true = instruction field B is a name of the source register
    variable aIsDst  : boolean; -- true = instruction field A is a name of the destination register
    variable bIsDst  : boolean; -- true = instruction field B is a name of the destination register
    variable cIsDst  : boolean; -- true = instruction field C is a name of the destination register
    variable isImm26 : boolean; -- true = J-type instruction with IMM26
    variable isImm16 : boolean; -- true = I-type instruction with IMM16
    variable isImm5  : boolean; -- true = R-type instruction with IMM5
    variable isCti   : boolean; -- true = control transfer instruction
    variable isCall  : boolean; -- true = call instruction - implicit destination register r31
    variable isAlu   : boolean; -- true = ALU instruction
    variable isShift : boolean; -- true = Shift/Rotate instruction
    variable fuOp    : natural range 0 to 15; -- ALU or shift unit internal opcode
  begin

    aIsSrc  := false;
    bIsSrc  := false;
    aIsDst  := false;
    bIsDst  := false;
    cIsDst  := false;
    isImm26 := false;
    isImm16 := true;
    isImm5  := false;
    isCti   := false;
    isCall  := false;
    isAlu   := false;
    isShift := false;
    fuOp    := 0;

    case to_integer(op) is
      when OP_CALL =>
        isImm16 := false;
        isImm26 := true;
        isCti   := true;
        isCall  := true;

      when OP_JMPI =>
        isImm16 := false;
        isImm26 := true;
        isCti   := true;

      when OP_RTYPE =>
        isImm16 := false;

      when others => null;
    end case;

    a_is_src <= aIsSrc ;
    b_is_src <= bIsSrc ;
    a_is_dst <= aIsDst ;
    b_is_dst <= bIsDst ;
    c_is_dst <= cIsDst ;
    is_imm26 <= isImm26;
    is_imm16 <= isImm16;
    is_imm5  <= isImm5 ;
    is_cti   <= isCti  ;
    is_call  <= isCall ;
    is_alu   <= isAlu  ;
    is_shift <= isShift;
    fu_op    <= fuOp   ;

  end process;
end architecture a;
