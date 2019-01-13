package n2decode_definitions is

  -- instruction classes
  type jump_class_t is (
    JUMP_CLASS_DIRECT,   -- direct jump and call
    JUMP_CLASS_INDIRECT, -- indirect jumps, calls, returns
    JUMP_CLASS_OTHERS    -- non-jumps
  );
  -- constant JUMP_CLASS_DIRECT   : natural := 0;
  -- constant JUMP_CLASS_INDIRECT : natural := 1;
  -- constant JUMP_CLASS_OTHERS   : natural := 2;
  -- subtype jump_class_t is natural range JUMP_CLASS_DIRECT to JUMP_CLASS_OTHERS;

  type instr_class_t is ( -- for JUMP_CLASS_OTHERS
    INSTR_CLASS_ALU   , -- arithmetic/logic/comparison
    INSTR_CLASS_SHIFT , -- shift/rotate
    INSTR_CLASS_BRANCH, -- PC-relative branches
    INSTR_CLASS_MEMORY  -- load/store
  );
  -- constant INSTR_CLASS_ALU    : natural := 0;
  -- constant INSTR_CLASS_BRANCH : natural := 1;
  -- constant INSTR_CLASS_SHIFT  : natural := 2;
  -- constant INSTR_CLASS_MEMORY : natural := 3;
  -- subtype instr_class_t is natural range INSTR_CLASS_ALU to INSTR_CLASS_MEMORY;

  -- immediate operand classes
  type imm16_class_t is (
    IMM16_CLASS_s16,   -- sign-extended IMM16
    IMM16_CLASS_z16,   -- zero-extended IMM16
    IMM16_CLASS_h16    -- IMM16 shifted by 16 to the left
  );

end package n2decode_definitions;
