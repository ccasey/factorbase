#include <stdio.h>
#include <gmp.h>
#include "choose.h"

/*
Calculates the total number of entries.
Example for n=2
  Choose_0,0-
  Choose_0,0+
  Choose_1,0-
  Choose_1,0+
  Choose_2,0-
  Choose_2,0+
  Choose_2,1-
  Choose_2,1+
So the function would return 8
*/
int tot_choose(int n) {
  int ret;
  /*
  The function to determine this is:
    If n is odd : (n^2+3)/2 + 2*n 
    If n is even: (n^2+4)/2 + 2*n 
  So we build the first term depending on the parity of n
  */

  if(n&1) {
    ret=3;
  } else {
    ret=4;
  }

  ret = (n*n + ret)/2 + 2*n;
  return(ret);
}


/* Gives the number of entries in a range. */
int tot_choose_range(int x, int y) {
  return(tot_choose(y) - tot_choose(x-1));
}


main(int argc, char* argv[]) {
  int x;
  int x_min;
  int x_max;
  int y;

  mpz_t c;

  if ((argc < 2) || (argc > 3)) {
    fprintf(stderr, "Usage: %s <start_row> [end_row]\n", argv[0]);
    exit(0);
  }

  mpz_init(c);

  x_min = atoi(argv[1]);
  if (argc > 2) {
    x_max = atoi(argv[2]);
  } else {
    x_max = x_min;
  }

  fprintf(stderr, "Printing %d total entries\n",
    tot_choose_range(x_min, x_max));
  for(x = x_min; x <= x_max; x++) {
    for(y=0; y<= x/2; y++) {
      mpz_choose(c,x,y);

      mpz_sub_ui(c, c, 1);
      printf("Choose_%d,%d-\t%s\n", x, y, mpz_get_str(NULL, 10, c));

      mpz_add_ui(c, c, 2);
      printf("Choose_%d,%d+\t%s\n", x, y, mpz_get_str(NULL, 10, c));
    }
  }
}
