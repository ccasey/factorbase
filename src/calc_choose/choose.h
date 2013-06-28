#include <gmp.h>

void mpz_choose(mpz_t rop, int x, int y) {
  int i;

  if(y > x/2) {
    y = x-y;
  }

  if ((x < y) || (x < 0) || (y < 0)) {
    mpz_set_ui(rop, 0);
    return;
  }

  mpz_set_ui(rop,1);

  for(i = (x-y+1); i <= x; i++) {
    mpz_mul_ui(rop, rop, i);
  }

  for(i=2; i <= y; i++) {
    mpz_tdiv_q_ui(rop, rop, i);
  }
}
