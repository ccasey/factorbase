
/*
 * Chris Casey
 *
 * Generate n prime numbers with n bit prime factors 
 *
 */

#include <stdio.h>
#include <time.h>
#include <gmp.h>


main ( int argc, char **argv){
	
  int cnt=0;			/* number of factors */
  long bits;

  gmp_randstate_t rstate;	/* state var for random number generation */
  mpz_t p1,p2,c;			/* gmp big integer type */
  
  /* initialize our gmp variables */
  gmp_randinit (rstate, 0, 128);
  mpz_init (p1);
  mpz_init (p2);
  mpz_init (c);
  
  
  /* seed the random generator with the current seconds since epoch */
  gmp_randseed_ui (rstate, time(NULL)); 


  /* get our bits per factor straight */
  printf("bits per prime: %s\n\n", argv[1]);
  bits = (long) argv[1];

  /* generate random number q */
  mpz_urandomb(p1, rstate, bits); 
  
 /* set the high bit so we always get a n bit number */
  mpz_setbit(p1,(bits-1));
  
  /* get the next prime number starting with our q */
  mpz_nextprime(p1,p1);
  
  /* enlighten us */
  printf("\n%s bit prime p1: %s\n\n", bits, mpz_get_str(NULL,10,p1));
  
 /*
  * we have our first 168bit prime
  */
   
  mpz_urandomb(p2, rstate, 168);
  mpz_setbit(p2,167);
  mpz_nextprime(p2,p2);
  
  printf ("168 bit prime p2: %s\n\n", mpz_get_str(NULL,10,p2));
  
  /*
   * we have our second 168bit prime
   */


  /*
   * final big composite from p1*p2
   */

  mpz_mul(c,p1,p2);

  printf ("composite p1*p2: %s\n\n", mpz_get_str(NULL,10,c));

	
  
 exit(0);

}
