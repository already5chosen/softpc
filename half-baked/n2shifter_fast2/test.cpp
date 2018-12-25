#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <random>
#include <functional> // for std::bind

static uint32_t shift(
  uint32_t a,
  unsigned b,
  int      op_shift, // 0 - rotate,      1 - shift
  int      op_left,  // 0 - shift right, 1 - shift left
  int      op_arith);// 0 - arithmetic,  1 - logical (applicable when op_shift=1 and op_left=0)

static uint32_t bit_shift(
  uint32_t   a,
  unsigned   b,
  int        op_shift, // 0 - rotate,      1 - shift
  int        op_left,  // 0 - shift right, 1 - shift left
  int        op_arith, // 0 - arithmetic,  1 - logical (applicable when op_shift=1 and op_left=0)
  unsigned&  by_rshift,
  unsigned&  by_b_lsbits,
  int&       by_op_left);

static uint32_t byte_shift(
  uint32_t a,
  unsigned rshift,
  unsigned b_lsbits, // 0 - bit shift count==0, 1 - bit shift count!=0
  int      op_align, // 0 - shift/rotate, 1 - align bytes, 2 - align 16-bit half-word
  int      op_shift, // 0 - rotate,       1 - shift
  int      op_left,  // 0 - shift right,  1 - shift left (applicable when op_align=0)
  int      op_arith);// 0 - arithmetic,   1 - logical    (applicable when op_align>0 or op_shift=1 and op_left=0)

int main(int argz, char** argv)
{
  int nIter = 1;
  if (argz > 1)
  {
    int val = strtol(argv[1], 0, 0);
    if (val > 1)
      nIter = val;
  }

  std::mt19937_64 rndGen;
  std::uniform_int_distribution<uint32_t> rndDistr(0, uint32_t(-1));
  auto rndFunc = std::bind ( rndDistr, rndGen );

  for (int i = 0; i < nIter; ++i) {
    uint32_t a = rndFunc();
    for (unsigned b = 0; b < 32; ++b) {
      uint32_t res, ref;

      res = shift(a, b, 0, 0, 0);
      ref = (a >> (b%32)) | (a << ((32-b)%32));
      if (ref != res) {
        printf("%08x ror %2d => %08x != %08x\n", a, b, res, ref);
        return 1;
      }

      res = shift(a, b, 1, 0, 0);
      ref = a >> b;
      if (ref != res) {
        printf("%08x srl %2d => %08x != %08x\n", a, b, res, ref);
        return 1;
      }

      res = shift(a, b, 1, 0, 1);
      ref = (int32_t)a >> b;
      if (ref != res) {
        printf("%08x sra %2d => %08x != %8x\n", a, b, res, ref);
        return 1;
      }

      res = shift(a, b, 0, 1, 0);
      ref = (a << (b%32)) | (a >> ((32-b)%32));
      if (ref != res) {
        printf("%08x rol %2d => %08x != %08x\n", a, b, res, ref);
        return 1;
      }

      res = shift(a, b, 1, 1, 0);
      ref = a << b;
      if (ref != res) {
        printf("%08x sll %2d => %08x != %08x\n", a, b, res, ref);
        return 1;
      }
    }
    union {
      uint32_t u32;
      uint16_t u16[2];
      int16_t  s16[2];
      uint8_t  u8[4];
      int8_t   s8[4];
    } un;
    un.u32 = a;
    for (unsigned b = 0; b < 4; ++b) {
      uint32_t res, ref;

      res = byte_shift(a, b, 0, 3, 0, 0, 0);
      ref = un.u8[b];
      if (ref != res) {
        printf("%08x u8a %d => %08x != %08x\n", a, b, res, ref);
        return 1;
      }

      res = byte_shift(a, b, 0, 3, 0, 0, 1);
      ref = (int32_t)un.s8[b];
      if (ref != res) {
        printf("%08x s8a %d => %08x != %08x\n", a, b, res, ref);
        return 1;
      }
    }
    for (unsigned b = 0; b < 2; ++b) {
      uint32_t res, ref;

      res = byte_shift(a, b*2, 0, 2, 0, 0, 0);
      ref = un.u16[b];
      if (ref != res) {
        printf("%08x u16a %d => %08x != %08x\n", a, b, res, ref);
        return 1;
      }

      res = byte_shift(a, b*2, 0, 2, 0, 0, 1);
      ref = (int32_t)un.s16[b];
      if (ref != res) {
        printf("%08x s16a %d => %08x != %08x\n", a, b, res, ref);
        return 1;
      }
    }
  }

  // printf("%d %lld\n", nIter, acc);
  return 0;
}

static uint32_t byte_shift(
  uint32_t a,
  unsigned rshift,
  unsigned b_lsbits, // 0 - bit shift count==0, 1 - bit shift count!=0
  int      op_align, // 0 - shift/rotate, 3 - align bytes, 2 - align 16-bit half-word
  int      op_shift, // 0 - rotate,       1 - shift
  int      op_left,  // 0 - shift right,  1 - shift left (applicable when op_align=0)
  int      op_arith) // 0 - arithmetic,   1 - logical    (applicable when op_align>0 or op_shift=1 and op_left=0)
{
  unsigned b = (-rshift - b_lsbits) % 4;
  int eff_op_arith = 0;
  if (op_arith) {
    eff_op_arith = (a>>31) & 1;
    if (op_align == 3) {
      if (rshift==0)
        eff_op_arith = (a>>7) & 1;
      else if (rshift==1)
        eff_op_arith = (a>>15) & 1;
      else if (rshift==2)
        eff_op_arith = (a>>23) & 1;
    } else if (op_align == 2) {
      if (rshift==0)
        eff_op_arith = (a>>15) & 1;
    }
  }
  for (int k = 0; k < 2; ++k) {
    const unsigned pow2 = 8 << k;
    const unsigned ones_pow2 = (1u << pow2) - 1;
    uint32_t r = a;
    if ((rshift >> k) & 1) {
      // for bi in 0 to DATA_WIDTH-1 loop
        // trellis(k)(bi) := trellis(k+1)(((2**k)+bi) mod DATA_WIDTH);
      // end loop;
      r = (a >> pow2) | (a << (32-pow2));
      if (op_shift) {
        if (op_left==0) {
          // trellis(k)(DATA_WIDTH-1 downto DATA_WIDTH-(2**k)) := (others => '0');
          r &= ~(ones_pow2 << (32-pow2));
          if (eff_op_arith) {
            // trellis(k)(DATA_WIDTH-1 downto DATA_WIDTH-(2**k)) := (others => '1');
            r |= (ones_pow2 << (32-pow2));
          }
        }
      }
    }
    if (op_shift && op_left && ((b>>k) & 1)) {
      // trellis(k+1)(DATA_WIDTH-1-(2**k) downto DATA_WIDTH-(2**(k+1))) := (others => '0');
      r &= ~(ones_pow2 << (32-pow2*2));
    }
    if ((op_align >> k) & 1) {
      // for kk in 1 to 2**(B_WIDTH-1-k) loop
      for (int kk = 0; kk < 32; kk += pow2*2) {
        // trellis(k+1)((2**k)*(2*kk)-1 downto (2**k)*(2*kk-1)) := (others => '0');
        r &= ~(ones_pow2 << (kk+pow2));
        if (eff_op_arith) {
          // trellis(k+1)((2**k)*(2*kk)-1 downto (2**k)*(2*kk-1)) := (others => '1');
          r |= (ones_pow2 << (kk+pow2));
        }
      }
    }
    a = r;
  }
  return a;
}

static uint32_t bit_shift(
  uint32_t   a,
  unsigned   b,
  int        op_shift, // 0 - rotate,      1 - shift
  int        op_left,  // 0 - shift right, 1 - shift left
  int        op_arith, // 0 - arithmetic,  1 - logical (applicable when op_shift=1 and op_left=0)
  unsigned&  by_rshift,
  unsigned&  by_b_lsbits,
  int&       by_op_left)
{
  unsigned rshift = op_left ? -b % 32 : b;
  int eff_op_left  = b==0 ? 0 : op_left;
  int eff_op_arith = (a>>31)==0 ? 0 : op_arith;
  for (int k = 0; k < 3; ++k) {
    const unsigned pow2 = 1 << k;
    const unsigned ones_pow2 = (1u << pow2) - 1;
    uint32_t r = a;
    if ((rshift >> k) & 1) {
      // for bi in 0 to DATA_WIDTH-1 loop
        // trellis(k)(bi) := trellis(k+1)(((2**k)+bi) mod DATA_WIDTH);
      // end loop;
      r = (a >> pow2) | (a << (32-pow2));
      if (op_shift) {
        if (eff_op_left==0) {
          // trellis(k)(DATA_WIDTH-1 downto DATA_WIDTH-(2**k)) := (others => '0');
          r &= ~(ones_pow2 << (32-pow2));
          if (eff_op_arith) {
            // trellis(k)(DATA_WIDTH-1 downto DATA_WIDTH-(2**k)) := (others => '1');
            r |= (ones_pow2 << (32-pow2));
          }
        }
      }
    }
    if (op_shift && eff_op_left && ((b>>k) & 1)) {
      // trellis(k+1)(DATA_WIDTH-1-(2**k) downto DATA_WIDTH-(2**(k+1))) := (others => '0');
      r &= ~(ones_pow2 << (32-pow2*2));
    }
    a = r;
  }
  by_rshift   = rshift / 8;
  by_b_lsbits = (b % 8) != 0;
  by_op_left  = eff_op_left;
  return a;
}

static uint32_t shift(
  uint32_t a,
  unsigned b,
  int      op_shift, // 0 - rotate,      1 - shift
  int      op_left,  // 0 - shift right, 1 - shift left
  int      op_arith) // 0 - arithmetic,  1 - logical (applicable when op_shift=1 and op_left=0)
{
  unsigned by_rshift;
  unsigned by_b_lsbits;
  int      by_op_left;
  a = bit_shift(a, b, op_shift, op_left, op_arith, by_rshift, by_b_lsbits, by_op_left);
  return byte_shift(a, by_rshift, by_b_lsbits, 0, op_shift, by_op_left, op_arith);
}
