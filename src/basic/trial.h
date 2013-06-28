#include <gmp.h>
#include "small_primes.h"

int trial_factor(mpz_t C, mpz_t N) {
  int fac_count=0;
  mpz_t r;
  unsigned pcount;

  mpz_set(C, N);
  mpz_init(r);

  for(pcount=0; pcount < SMALL_PRIMES; pcount++) {
    while (mpz_mod_ui(r, C, small_prime[pcount]) == 0) {
      /* Don't report if we've just found the number itself */
      if(mpz_cmp_ui(C, small_prime[pcount]) == 0) {
        break;
      }
      printf("TRIAL %d\n", small_prime[pcount]);
      mpz_tdiv_q_ui(C, C, small_prime[pcount]);
      fac_count++;
    }
  }
  mpz_clear(r);
  return(fac_count);
}
