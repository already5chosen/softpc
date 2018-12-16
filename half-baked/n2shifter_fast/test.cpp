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
        printf("%08x ror %2d => %08x != %8x\n", a, b, res, ref);
        return 1;
      }

      res = shift(a, b, 1, 0, 0);
      ref = a >> b;
      if (ref != res) {
        printf("%08x srl %2d => %08x != %8x\n", a, b, res, ref);
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
        printf("%08x rol %2d => %08x != %8x\n", a, b, res, ref);
        return 1;
      }

      res = shift(a, b, 1, 1, 0);
      ref = a << b;
      if (ref != res) {
        printf("%08x sll %2d => %08x != %8x\n", a, b, res, ref);
        return 1;
      }
    }
  }

  // printf("%d %lld\n", nIter, acc);
  return 0;
}

static uint32_t shift(
  uint32_t a,
  unsigned b,
  int      op_shift, // 0 - rotate,      1 - shift
  int      op_left,  // 0 - shift right, 1 - shift left
  int      op_arith) // 0 - arithmetic,  1 - logical (applicable when op_shift=1 and op_left=0)
{
  unsigned rshift = op_left ? -b % 32 : b;
  int eff_op_left  = b==0 ? 0 : op_left;
  int eff_op_arith = (a>>31)==0 ? 0 : op_arith;
  for (int k = 0; k < 5; ++k) {
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
  return a;
}