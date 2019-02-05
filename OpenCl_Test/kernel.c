#include <CL/cl.h>

void SAXPY (double** output, const double* ff)
{ 
    const int x = 0;
    const int y = 1;
    output [x][y] = x * y;
}
