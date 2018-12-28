package n2decode_definitions is

  -- instruction classes
  type instr_class_t is (
    INSTR_CLASS_ALU   , -- arithmetic/logic/comparison
    INSTR_CLASS_SHIFT , -- shift/rotate
    INSTR_CLASS_BRANCH, -- PC-relative branches
    INSTR_CLASS_JUMP  , -- absolute and indirect jumps, calls, returns
    INSTR_CLASS_MEMORY  -- load/store
  );

  -- source register classes
  type src_reg_class_t is (
    SRC_REG_CLASS_NONE, -- no source registers
    SRC_REG_CLASS_A,    -- r[A] and stores
    SRC_REG_CLASS_AB    -- r[A] and r[B], except for stores
  );

  -- immediate operand classes
  type imm16_class_t is (
    IMM16_CLASS_s16,   -- sign-extended IMM16
    IMM16_CLASS_z16,   -- zero-extended IMM16
    IMM16_CLASS_h16    -- IMM16 shifted by 16 to the left
  );

end package n2decode_definitions;
