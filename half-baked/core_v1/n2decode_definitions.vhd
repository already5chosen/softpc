package n2decode_definitions is

  -- instruction classes
  constant INSTR_CLASS_ALU      : integer := 0; -- arithmetic/logic/comparison
  constant INSTR_CLASS_SHIFT    : integer := 1; -- shift/rotate
  constant INSTR_CLASS_BRANCH   : integer := 2; -- PC-relative branches
  constant INSTR_CLASS_JUMP     : integer := 3; -- absolute and indirect jumps, calls, returns
  constant INSTR_CLASS_MEMORY   : integer := 5; -- load/store
  constant INSTR_CLASS_COPY     : integer := 7; -- src=>dst, mostly special instructions
  subtype instr_class_t is natural range 0 to 7;

  -- source register classes
  constant SRC_REG_CLASS_NONE   : integer := 0; -- no source registers
  constant SRC_REG_CLASS_NEXTPC : integer := 1; -- PC+4
  constant SRC_REG_CLASS_A      : integer := 2; -- r[A] and stores
  constant SRC_REG_CLASS_AB     : integer := 3; -- r[A] and r[B], except for stores
  subtype src_reg_class_t is natural range 0 to 3;

  -- destination register classes
  constant DEST_REG_CLASS_NONE  : integer := 0; -- no destination register
  constant DEST_REG_CLASS_CALL  : integer := 1; -- ra==r31
  constant DEST_REG_CLASS_B     : integer := 2; -- r[B]
  constant DEST_REG_CLASS_C     : integer := 3; -- r[C]
  subtype dest_reg_class_t is natural range 0 to 3;

  -- immediate operand classes
  type imm16_class_t is (
    IMM16_CLASS_s16,   -- sign-extended IMM16
    IMM16_CLASS_z16,   -- zero-extended IMM16
    IMM16_CLASS_h16    -- IMM16 shifted by 16 to the left
  );

end package n2decode_definitions;
