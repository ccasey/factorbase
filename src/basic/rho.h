#include <gmp.h>
#include <stdlib.h>	/* For rand() */
#include <time.h>	/* For time() */
#include <sys/types.h>	/* For getpid() */
#include <unistd.h>	/* For getpid() */

#define DEFAULT_MAX_TRIALS	10000
#define MAX_CHECK_DELTA		128
#define MIN(x,y)		(x<y?x:y)

/* Global params */
mpz_t a;
mpz_t b;
int c;
mpz_t d;
int d_check;


/* Reset all the Rho paramaters, for use at the beginning or when
the method fails. */
void rho_param_reset() {

  mpz_set_ui(a, 2);
  mpz_set_ui(b, 2);
  mpz_set_ui(d, 1);

  /* The random part of x^2 + c */
  c = rand();

  /* The next time to check d */
  d_check=1;
}


/*
If trials is 0, do default
Put the cofactor in C
Return number of factors found.
*/
int rho_factor(mpz_t C, mpz_t N, int max_trials) {
  mpz_t a_m_b;
  mpz_t g;
  int count;
  int fac_count = 0;

  if (max_trials < 1) {
    max_trials = DEFAULT_MAX_TRIALS;
  }

  srand(time(NULL) ^ (getpid() << 16));

  mpz_set(C, N);
  mpz_init(a);
  mpz_init(b);
  mpz_init(d);
  mpz_init(a_m_b);
  mpz_init(g);

  rho_param_reset();

  for(count=0; count < max_trials; count++) {
    /* a = a^2 + c (mod N) */
    /* Note, doing it this way is actually faster then exp_mod */
    mpz_mul(a, a, a);
    mpz_add_ui(a, a, c);
    mpz_mod(a, a, C);

    /* b = b^2 + c (mod N), 2 reps */
    mpz_mul(b, b, b);
    mpz_add_ui(b, b, c);
    mpz_mod(b, b, C);

    mpz_mul(b, b, b);
    mpz_add_ui(b, b, c);
    mpz_mod(b, b, C);

    /* d = d*(a-b) (mod N) */
    mpz_sub(a_m_b, a, b);
    mpz_mul(d, d, a_m_b);
    mpz_mod(d, d, C);

    /* If it's time to check d */
    if(count >= d_check) {
      d_check += MIN(d_check, MAX_CHECK_DELTA);
      d_check = MIN(d_check, max_trials - 1);
 
      /* g = gcd(d, n) */
      mpz_gcd(g, d, C);

      /* If we've found a factor */
      if (mpz_cmp_ui(g, 1) > 0) {

        /* If g != N, we've found something interesting. */
        if(mpz_cmp(g, C) != 0) {
          printf("RHO %s c=%d rep=%d\n", mpz_get_str(NULL, 10, g), c, count);
          /* Divide out the GCD */
          mpz_tdiv_q(C, C, g);
          fac_count++;

          /* Check primality here */
          /* Presumably we've already done small trial division, so there's */
          /* no need to do that for a primality test */
          if(mpz_probab_prime_p(C, 20)) {
            break;
          }
        }
        count = -1;	/* The loop will re-start at 0 */
        rho_param_reset();
      }
    }
  }
  mpz_clear(a);
  mpz_clear(b);
  mpz_clear(d);
  mpz_clear(g);
  mpz_clear(a_m_b);
  return(fac_count);
}
