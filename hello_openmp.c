#include <omp.h>
#include <stdio.h>
#include <stdlib.h>
 
int main(int argc, char* argv[])
{
    // Inicio paralelo
    #pragma omp parallel
    {
        printf("Hola mundo... soy el thread = %d de %d\n", omp_get_thread_num(), omp_get_num_threads());
    }
    // Fin paralelo
}