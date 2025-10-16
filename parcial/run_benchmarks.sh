#!/bin/bash

# Forzar configuración regional para usar punto decimal
export LC_NUMERIC=C
export LC_ALL=C

# Script para medir tiempos de comunicación y procesamiento con MPI
# Ejecutar en el nodo principal (server)
# Configuración: 2 nodos (server + worker1)

echo "=========================================="
echo "Benchmark MPI - Cálculo de Promedios"
echo "=========================================="
echo ""

# Compilar el código
echo ">>> Compilando avg.c..."
mpicc -o avg avg.c -lm
if [ $? -ne 0 ]; then
    echo "ERROR: Falló la compilación"
    exit 1
fi
echo ">>> Compilación exitosa"
echo ""

# Configuraciones de prueba
NUM_ITERACIONES=5  # Número de ejecuciones para promediar
TAMANIOS=(1000 10000 100000 1000000)  # Elementos por proceso

echo ">>> Configuración del benchmark:"
echo "    - Iteraciones por prueba: $NUM_ITERACIONES"
echo "    - Tamaños de entrada: ${TAMANIOS[@]}"
echo "    - Nodos: 2 (server + worker1)"
echo ""

# Arrays para almacenar resultados
declare -A resultados_promedio
declare -A resultados_desviacion

# Función para ejecutar pruebas
ejecutar_prueba() {
    local num_procesos=$1
    local elementos=$2
    local hostfile=$3
    local descripcion=$4
    local clave=$5

    echo "----------------------------------------"
    echo "Prueba: $descripcion"
    echo "Procesos: $num_procesos | Elementos/proceso: $elementos"
    echo "----------------------------------------"

    local suma_tiempos=0
    local tiempos=()

    for i in $(seq 1 $NUM_ITERACIONES); do
        echo -n "  Ejecución $i/$NUM_ITERACIONES... "

        # Medir tiempo de ejecución
        inicio=$(date +%s.%N)

        if [ -n "$hostfile" ]; then
            mpirun -np $num_procesos --hostfile $hostfile ./avg $elementos > /dev/null 2>&1
        else
            mpirun -np $num_procesos ./avg $elementos > /dev/null 2>&1
        fi

        fin=$(date +%s.%N)

        # Calcular tiempo transcurrido
        tiempo=$(echo "$fin - $inicio" | bc)
        tiempos+=($tiempo)
        suma_tiempos=$(echo "$suma_tiempos + $tiempo" | bc)

        echo "${tiempo}s"
    done

    # Calcular promedio
    promedio=$(echo "scale=6; $suma_tiempos / $NUM_ITERACIONES" | bc)

    # Calcular desviación estándar
    suma_cuadrados=0
    for t in "${tiempos[@]}"; do
        diff=$(echo "$t - $promedio" | bc)
        cuadrado=$(echo "$diff * $diff" | bc)
        suma_cuadrados=$(echo "$suma_cuadrados + $cuadrado" | bc)
    done
    desviacion=$(echo "scale=6; sqrt($suma_cuadrados / $NUM_ITERACIONES)" | bc)

    # Guardar resultados
    resultados_promedio[$clave]=$promedio
    resultados_desviacion[$clave]=$desviacion

    echo ""
    echo "  RESULTADOS:"
    echo "    Tiempo promedio: ${promedio}s"
    echo "    Desviación estándar: ${desviacion}s"

    # Encontrar mínimo y máximo
    min=${tiempos[0]}
    max=${tiempos[0]}
    for t in "${tiempos[@]}"; do
        if (( $(echo "$t < $min" | bc -l) )); then
            min=$t
        fi
        if (( $(echo "$t > $max" | bc -l) )); then
            max=$t
        fi
    done
    echo "    Tiempo mínimo: ${min}s"
    echo "    Tiempo máximo: ${max}s"
    echo ""
}

# ==========================================
# PRUEBAS CON 1 MÁQUINA VIRTUAL (local)
# ==========================================
echo "=========================================="
echo "ESCENARIO 1: Una sola máquina (local)"
echo "=========================================="
echo ""

for tamanio in "${TAMANIOS[@]}"; do
    # Prueba con 1 proceso
    ejecutar_prueba 1 $tamanio "" "1 máquina, 1 proceso" "local_1p_${tamanio}"

    # Prueba con 2 procesos
    ejecutar_prueba 2 $tamanio "" "1 máquina, 2 procesos" "local_2p_${tamanio}"

    # Prueba con 4 procesos
    ejecutar_prueba 4 $tamanio "" "1 máquina, 4 procesos" "local_4p_${tamanio}"
done

# ==========================================
# PRUEBAS CON MÚLTIPLES MÁQUINAS VIRTUALES
# ==========================================
echo "=========================================="
echo "ESCENARIO 2: Múltiples máquinas (2 nodos)"
echo "=========================================="
echo ""

# Verificar que existe el archivo de hosts
if [ ! -f "lista_nodos" ]; then
    echo "ADVERTENCIA: No se encontró lista_nodos, saltando pruebas distribuidas"
else
    for tamanio in "${TAMANIOS[@]}"; do
        # Prueba con 2 procesos distribuidos
        ejecutar_prueba 2 $tamanio "lista_nodos" "2 máquinas, 2 procesos (1 por nodo)" "dist_2p_${tamanio}"

        # Prueba con 4 procesos distribuidos
        ejecutar_prueba 4 $tamanio "lista_nodos" "2 máquinas, 4 procesos (2 por nodo)" "dist_4p_${tamanio}"

        # Prueba con 8 procesos distribuidos
        ejecutar_prueba 8 $tamanio "lista_nodos" "2 máquinas, 8 procesos (4 por nodo)" "dist_8p_${tamanio}"
    done
fi

# ==========================================
# ANÁLISIS COMPARATIVO CON ESTADÍSTICAS
# ==========================================
echo "=========================================="
echo "ANÁLISIS COMPARATIVO DE RESULTADOS"
echo "=========================================="
echo ""

for tamanio in "${TAMANIOS[@]}"; do
    echo "=========================================="
    echo "TAMAÑO: $tamanio elementos por proceso"
    echo "=========================================="
    echo ""

    # Baseline (1 proceso local)
    t_baseline=${resultados_promedio[local_1p_${tamanio}]}

    echo "--- ESCALABILIDAD LOCAL ---"
    echo "Configuración                 Tiempo(s)    Speedup    Eficiencia"
    echo "----------------------------------------------------------------"

    # 1 proceso local
    printf "%-28s %9.6f %10s %11s\n" "1 proceso" "$t_baseline" "1.000" "100.00%"

    # 2 procesos local
    t_2p=${resultados_promedio[local_2p_${tamanio}]}
    if [ -n "$t_2p" ]; then
        speedup=$(echo "scale=3; $t_baseline / $t_2p" | bc)
        eficiencia=$(echo "scale=2; 100 * $speedup / 2" | bc)
        printf "%-28s %9.6f %10.3f %10.2f%%\n" "2 procesos" "$t_2p" "$speedup" "$eficiencia"
    fi

    # 4 procesos local
    t_4p=${resultados_promedio[local_4p_${tamanio}]}
    if [ -n "$t_4p" ]; then
        speedup=$(echo "scale=3; $t_baseline / $t_4p" | bc)
        eficiencia=$(echo "scale=2; 100 * $speedup / 4" | bc)
        printf "%-28s %9.6f %10.3f %10.2f%%\n" "4 procesos" "$t_4p" "$speedup" "$eficiencia"
    fi

    echo ""
    echo "--- ESCALABILIDAD DISTRIBUIDA (2 nodos) ---"
    echo "Configuración                 Tiempo(s)    Speedup    Eficiencia"
    echo "----------------------------------------------------------------"

    # 2 procesos distribuidos
    t_2p_dist=${resultados_promedio[dist_2p_${tamanio}]}
    if [ -n "$t_2p_dist" ]; then
        speedup=$(echo "scale=3; $t_baseline / $t_2p_dist" | bc)
        eficiencia=$(echo "scale=2; 100 * $speedup / 2" | bc)
        printf "%-28s %9.6f %10.3f %10.2f%%\n" "2 proc (1 por nodo)" "$t_2p_dist" "$speedup" "$eficiencia"
    fi

    # 4 procesos distribuidos
    t_4p_dist=${resultados_promedio[dist_4p_${tamanio}]}
    if [ -n "$t_4p_dist" ]; then
        speedup=$(echo "scale=3; $t_baseline / $t_4p_dist" | bc)
        eficiencia=$(echo "scale=2; 100 * $speedup / 4" | bc)
        printf "%-28s %9.6f %10.3f %10.2f%%\n" "4 proc (2 por nodo)" "$t_4p_dist" "$speedup" "$eficiencia"
    fi

    # 8 procesos distribuidos
    t_8p_dist=${resultados_promedio[dist_8p_${tamanio}]}
    if [ -n "$t_8p_dist" ]; then
        speedup=$(echo "scale=3; $t_baseline / $t_8p_dist" | bc)
        eficiencia=$(echo "scale=2; 100 * $speedup / 8" | bc)
        printf "%-28s %9.6f %10.3f %10.2f%%\n" "8 proc (4 por nodo)" "$t_8p_dist" "$speedup" "$eficiencia"
    fi

    echo ""
    echo "--- OVERHEAD DE COMUNICACIÓN (LOCAL vs DISTRIBUIDO) ---"
    echo "Procesos    T_Local(s)  T_Distrib(s)  Overhead(s)  Overhead(%)"
    echo "----------------------------------------------------------------"

    # Comparación 2 procesos
    if [ -n "$t_2p" ] && [ -n "$t_2p_dist" ]; then
        overhead=$(echo "scale=6; $t_2p_dist - $t_2p" | bc)
        overhead_pct=$(echo "scale=2; 100 * ($t_2p_dist - $t_2p) / $t_2p" | bc)
        printf "%-11s %10.6f %13.6f %12.6f %11.2f%%\n" "2" "$t_2p" "$t_2p_dist" "$overhead" "$overhead_pct"
    fi

    # Comparación 4 procesos
    if [ -n "$t_4p" ] && [ -n "$t_4p_dist" ]; then
        overhead=$(echo "scale=6; $t_4p_dist - $t_4p" | bc)
        overhead_pct=$(echo "scale=2; 100 * ($t_4p_dist - $t_4p) / $t_4p" | bc)
        printf "%-11s %10.6f %13.6f %12.6f %11.2f%%\n" "4" "$t_4p" "$t_4p_dist" "$overhead" "$overhead_pct"
    fi

    echo ""
done

echo "=========================================="
echo "RESUMEN DE OBSERVACIONES"
echo "=========================================="
echo ""
echo "MÉTRICAS CALCULADAS:"
echo "  - Speedup = T(1 proceso) / T(N procesos)"
echo "  - Eficiencia = Speedup / N procesos * 100%"
echo "  - Overhead comunicación = T_distribuido - T_local"
echo ""
echo "INTERPRETACIÓN:"
echo "  - Speedup ideal = N (lineal con número de procesos)"
echo "  - Eficiencia ideal = 100%"
echo "  - Overhead positivo = comunicación de red ralentiza"
echo "  - Overhead negativo = posible beneficio de distribución"
echo ""

echo "=========================================="
echo "Benchmark completado"
echo "=========================================="
