#include <gmp.h>
#include "trial.h"
#include "rho.h"

mpz_t N;

main(int argc, char* argv[]) {
  int tot_fac=0;
  int rho_loop;

  if(argc < 2) {
     printf("Usage: %s <N>\n", argv[0]);
     exit(-1);
  }

  mpz_init_set_str(N, argv[1], 10);

  tot_fac=trial_factor(N, N);

  /* If the remainder is larger than the largest prime */
  if(mpz_cmp_ui(N, small_prime[SMALL_PRIMES]) > 0) {
    if(mpz_probab_prime_p(N, 20) == 0) {
      tot_fac=rho_factor(N,N,0);
    }
  }
}
