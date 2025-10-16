// Versión modificada con medición de tiempos de comunicación y procesamiento
// Basado en código original de Wes Kendall - www.mpitutorial.com

#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <mpi.h>
#include <assert.h>

float *create_rand_nums(int num_elements) {
  float *rand_nums = (float *)malloc(sizeof(float) * num_elements);
  assert(rand_nums != NULL);
  for (int i = 0; i < num_elements; i++) {
    rand_nums[i] = (rand() / (float)RAND_MAX);
  }
  return rand_nums;
}

float compute_avg(float *array, int num_elements) {
  float sum = 0.f;
  for (int i = 0; i < num_elements; i++) {
    sum += array[i];
  }
  return sum / num_elements;
}

int main(int argc, char** argv) {
  if (argc != 2) {
    fprintf(stderr, "Uso: %s <elementos_por_proceso>\n", argv[0]);
    exit(1);
  }

  int num_elements_per_proc = atoi(argv[1]);
  srand(time(NULL));

  MPI_Init(NULL, NULL);

  int world_rank, world_size;
  MPI_Comm_rank(MPI_COMM_WORLD, &world_rank);
  MPI_Comm_size(MPI_COMM_WORLD, &world_size);

  // VARIABLES DE TIEMPO
  double t_total_start, t_total_end;
  double t_scatter_start, t_scatter_end;
  double t_compute_start, t_compute_end;
  double t_gather_start, t_gather_end;
  
  t_total_start = MPI_Wtime();

  // Crear datos en proceso 0
  float *rand_nums = NULL;
  if (world_rank == 0) {
    rand_nums = create_rand_nums(num_elements_per_proc * world_size);
  }

  float *sub_rand_nums = (float *)malloc(sizeof(float) * num_elements_per_proc);
  assert(sub_rand_nums != NULL);

  // === SCATTER (COMUNICACIÓN) ===
  t_scatter_start = MPI_Wtime();
  MPI_Scatter(rand_nums, num_elements_per_proc, MPI_FLOAT, 
              sub_rand_nums, num_elements_per_proc, MPI_FLOAT, 
              0, MPI_COMM_WORLD);
  t_scatter_end = MPI_Wtime();

  // === CÓMPUTO (PROCESAMIENTO) ===
  t_compute_start = MPI_Wtime();
  float sub_avg = compute_avg(sub_rand_nums, num_elements_per_proc);
  t_compute_end = MPI_Wtime();

  // === GATHER (COMUNICACIÓN) ===
  float *sub_avgs = NULL;
  if (world_rank == 0) {
    sub_avgs = (float *)malloc(sizeof(float) * world_size);
    assert(sub_avgs != NULL);
  }
  
  t_gather_start = MPI_Wtime();
  MPI_Gather(&sub_avg, 1, MPI_FLOAT, sub_avgs, 1, MPI_FLOAT, 
             0, MPI_COMM_WORLD);
  t_gather_end = MPI_Wtime();

  t_total_end = MPI_Wtime();

  // RESULTADOS (solo proceso 0)
  if (world_rank == 0) {
    float avg = compute_avg(sub_avgs, world_size);
    
    double t_scatter = t_scatter_end - t_scatter_start;
    double t_compute = t_compute_end - t_compute_start;
    double t_gather = t_gather_end - t_gather_start;
    double t_total = t_total_end - t_total_start;
    double t_comm = t_scatter + t_gather;
    
    printf("\n========== RESULTADOS ==========\n");
    printf("Procesos: %d\n", world_size);
    printf("Elementos/proceso: %d\n", num_elements_per_proc);
    printf("Total elementos: %d\n", num_elements_per_proc * world_size);
    printf("Promedio: %.6f\n", avg);
    
    printf("\n========== TIEMPOS ==========\n");
    printf("T_Scatter:   %.6f seg\n", t_scatter);
    printf("T_Compute:   %.6f seg\n", t_compute);
    printf("T_Gather:    %.6f seg\n", t_gather);
    printf("T_Comunicación: %.6f seg (%.2f%%)\n", 
           t_comm, (t_comm/t_total)*100);
    printf("T_Total:     %.6f seg\n", t_total);
    printf("\n");
    
    // Guardar en CSV
    FILE *fp = fopen("tiempos.csv", "a");
    if (fp) {
      fprintf(fp, "%d,%d,%d,%.6f,%.6f,%.6f,%.6f,%.6f\n",
              world_size, num_elements_per_proc, 
              num_elements_per_proc * world_size,
              t_scatter, t_compute, t_gather, t_comm, t_total);
      fclose(fp);
    }
  }

  // Limpieza
  if (world_rank == 0) {
    free(rand_nums);
    free(sub_avgs);
  }
  free(sub_rand_nums);

  MPI_Finalize();
  return 0;
}