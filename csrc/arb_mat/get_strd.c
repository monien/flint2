#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include <flint/flint.h>
#include <flint/arb.h>
#include <flint/arb_mat.h>

#include "../arb_mat.h"

char*
arb_mat_get_strd(const arb_mat_t mat, slong digits)
{
   char * buffer = NULL;
   size_t buffer_size = 0;

   FILE * out = open_memstream(&buffer, &buffer_size);

   arb_mat_fprintd(out, mat, digits);

   fclose(out);

   return buffer;
}
