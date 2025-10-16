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
  int i;
  for (i = 0; i < num_elements; i++) {
    rand_nums[i] = (rand() / (float)RAND_MAX);
  }
  return rand_nums;
}

float compute_avg(float *array, int num_elements) {
  float sum = 0.f;
  int i;
  for (i = 0; i < num_elements; i++) {
    sum += array[i];
  }
  return sum / num_elements;
}

int main(int argc, char** argv) {
  if (argc != 2) {
    fprintf(stderr, "Uso: avg_timed num_elements_per_proc\n");
    exit(1);
  }

  int num_elements_per_proc = atoi(argv[1]);
  srand(time(NULL));

  MPI_Init(NULL, NULL);

  int world_rank;
  MPI_Comm_rank(MPI_COMM_WORLD, &world_rank);
  int world_size;
  MPI_Comm_size(MPI_COMM_WORLD, &world_size);

  // Variables para medición de tiempo
  double start_total, end_total;
  double start_comm1, end_comm1, time_scatter;
  double start_comp, end_comp, time_computation;
  double start_comm2, end_comm2, time_gather;
  
  // Inicio del tiempo total
  start_total = MPI_Wtime();

  // Crear datos aleatorios en el proceso raíz
  float *rand_nums = NULL;
  if (world_rank == 0) {
    rand_nums = create_rand_nums(num_elements_per_proc * world_size);
  }

  float *sub_rand_nums = (float *)malloc(sizeof(float) * num_elements_per_proc);
  assert(sub_rand_nums != NULL);

  // ====== MEDICIÓN: Tiempo de Scatter (Comunicación 1) ======
  start_comm1 = MPI_Wtime();
  MPI_Scatter(rand_nums, num_elements_per_proc, MPI_FLOAT, sub_rand_nums,
              num_elements_per_proc, MPI_FLOAT, 0, MPI_COMM_WORLD);
  end_comm1 = MPI_Wtime();
  time_scatter = end_comm1 - start_comm1;

  // ====== MEDICIÓN: Tiempo de Cómputo ======
  start_comp = MPI_Wtime();
  float sub_avg = compute_avg(sub_rand_nums, num_elements_per_proc);
  end_comp = MPI_Wtime();
  time_computation = end_comp - start_comp;

  // ====== MEDICIÓN: Tiempo de Gather (Comunicación 2) ======
  float *sub_avgs = NULL;
  if (world_rank == 0) {
    sub_avgs = (float *)malloc(sizeof(float) * world_size);
    assert(sub_avgs != NULL);
  }
  
  start_comm2 = MPI_Wtime();
  MPI_Gather(&sub_avg, 1, MPI_FLOAT, sub_avgs, 1, MPI_FLOAT, 0, MPI_COMM_WORLD);
  end_comm2 = MPI_Wtime();
  time_gather = end_comm2 - start_comm2;

  // Cálculo final y fin del tiempo total
  if (world_rank == 0) {
    float avg = compute_avg(sub_avgs, world_size);
    end_total = MPI_Wtime();
    
    // Resultados
    printf("==== RESULTADOS DEL CÁLCULO ====\n");
    printf("Promedio calculado: %f\n", avg);
    
    float original_data_avg = compute_avg(rand_nums, num_elements_per_proc * world_size);
    printf("Promedio verificación: %f\n\n", original_data_avg);
    
    // Tiempos
    printf("==== MEDICIÓN DE TIEMPOS ====\n");
    printf("Procesos MPI: %d\n", world_size);
    printf("Elementos por proceso: %d\n", num_elements_per_proc);
    printf("Elementos totales: %d\n\n", num_elements_per_proc * world_size);
    
    printf("Tiempo Scatter (comunicación): %.6f segundos\n", time_scatter);
    printf("Tiempo Cómputo (procesamiento): %.6f segundos\n", time_computation);
    printf("Tiempo Gather (comunicación): %.6f segundos\n", time_gather);
    printf("Tiempo Total Comunicación: %.6f segundos\n", time_scatter + time_gather);
    printf("Tiempo Total: %.6f segundos\n\n", end_total - start_total);
    
    printf("Porcentaje Comunicación: %.2f%%\n", 
           ((time_scatter + time_gather) / (end_total - start_total)) * 100);
    printf("Porcentaje Procesamiento: %.2f%%\n", 
           (time_computation / (end_total - start_total)) * 100);
    
    // Salida CSV para análisis posterior
    FILE *fp = fopen("resultados_tiempos.csv", "a");
    if (fp != NULL) {
      fprintf(fp, "%d,%d,%d,%.6f,%.6f,%.6f,%.6f\n",
              world_size, num_elements_per_proc, 
              num_elements_per_proc * world_size,
              time_scatter, time_computation, time_gather,
              end_total - start_total);
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