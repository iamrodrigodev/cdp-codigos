#!/bin/bash

# Script completo para medir rendimiento del programa ORIGINAL avg.c
# Mide: tiempo real, CPU, overhead de comunicación, escalabilidad

echo "======================================================"
echo "   ANÁLISIS COMPLETO DE RENDIMIENTO MPI"
echo "======================================================"
echo ""

# Compilar
echo "Compilando avg.c..."
mpicc -o avg avg.c
echo "✓ Compilado"
echo ""

# Crear archivos de resultados
echo "procesos,elem_por_proc,elem_totales,tiempo_real,tiempo_user,tiempo_sys" > resultados.csv
echo "procesos,elem_por_proc,tiempo_promedio,desv_std,min,max" > estadisticas.csv

# Configuraciones
PROCESOS=(1 2 4 8)
ELEMENTOS=(10000 100000 1000000)
REPETICIONES=10

echo "═══════════════════════════════════════════════════"
echo "CONFIGURACIÓN DE PRUEBAS"
echo "═══════════════════════════════════════════════════"
echo "Procesos a probar: ${PROCESOS[@]}"
echo "Tamaños (elem/proc): ${ELEMENTOS[@]}"
echo "Repeticiones: $REPETICIONES"
echo ""

# ============================================
# FASE 1: MEDICIÓN BÁSICA DE TIEMPOS
# ============================================
echo "═══════════════════════════════════════════════════"
echo "FASE 1: MEDICIÓN DE TIEMPOS"
echo "═══════════════════════════════════════════════════"

for np in "${PROCESOS[@]}"; do
    echo ""
    echo "▶ PROBANDO CON $np PROCESO(S)"
    echo "───────────────────────────────────────────────────"
    
    for elem in "${ELEMENTOS[@]}"; do
        total=$((elem * np))
        echo "  📊 Tamaño: $elem elem/proc ($total totales)"
        
        for i in $(seq 1 $REPETICIONES); do
            # Medir tiempo usando el comando time de bash
            TIME_OUTPUT=$( { time mpirun -np $np ./avg $elem > /tmp/output_$$.txt 2>&1; } 2>&1 )
            
            # Extraer tiempos real, user y sys
            real=$(echo "$TIME_OUTPUT" | grep real | awk '{print $2}' | sed 's/0m//;s/s//')
            user=$(echo "$TIME_OUTPUT" | grep user | awk '{print $2}' | sed 's/0m//;s/s//')
            sys=$(echo "$TIME_OUTPUT" | grep sys | awk '{print $2}' | sed 's/0m//;s/s//')
            
            # Si no se capturó bien, usar valores por defecto
            [ -z "$real" ] && real="0"
            [ -z "$user" ] && user="0"
            [ -z "$sys" ] && sys="0"
            
            echo "$np,$elem,$total,$real,$user,$sys" >> resultados.csv
            
            echo -n "."
        done
        echo " ✓"
    done
done

echo ""
echo "═══════════════════════════════════════════════════"
echo "FASE 2: ANÁLISIS ESTADÍSTICO"
echo "═══════════════════════════════════════════════════"

# ============================================
# FASE 2: CALCULAR ESTADÍSTICAS
# ============================================
python3 - << 'EOF'
import csv
import math
from collections import defaultdict

# Leer datos
datos = defaultdict(list)
tiempos_user = defaultdict(list)
tiempos_sys = defaultdict(list)

with open('resultados.csv', 'r') as f:
    reader = csv.DictReader(f)
    for row in reader:
        key = (row['procesos'], row['elem_por_proc'])
        datos[key].append(float(row['tiempo_real']))
        tiempos_user[key].append(float(row['tiempo_user']))
        tiempos_sys[key].append(float(row['tiempo_sys']))

# Función para calcular desviación estándar
def desv_std(valores):
    n = len(valores)
    if n < 2:
        return 0
    promedio = sum(valores) / n
    varianza = sum((x - promedio) ** 2 for x in valores) / (n - 1)
    return math.sqrt(varianza)

# Guardar estadísticas
with open('estadisticas.csv', 'w') as f:
    f.write('procesos,elem_por_proc,tiempo_promedio,desv_std,min,max,cv_pct,tiempo_user,tiempo_sys,overhead_sys_pct\n')
    
    for key in sorted(datos.keys()):
        tiempos = datos[key]
        user = tiempos_user[key]
        sys = tiempos_sys[key]
        
        prom = sum(tiempos) / len(tiempos)
        std = desv_std(tiempos)
        minimo = min(tiempos)
        maximo = max(tiempos)
        cv = (std / prom * 100) if prom > 0 else 0
        
        prom_user = sum(user) / len(user)
        prom_sys = sum(sys) / len(sys)
        overhead_sys = (prom_sys / prom * 100) if prom > 0 else 0
        
        f.write(f'{key[0]},{key[1]},{prom:.6f},{std:.6f},{minimo:.6f},{maximo:.6f},{cv:.2f},{prom_user:.6f},{prom_sys:.6f},{overhead_sys:.2f}\n')

print("\n" + "="*60)
print("TABLA 1: ESTADÍSTICAS DE TIEMPOS (segundos)")
print("="*60)
print(f"{'Proc':<6} {'Elem/proc':<12} {'Promedio':<10} {'Desv.Std':<10} {'Min':<8} {'Max':<8} {'CV%':<6}")
print("-"*60)

with open('estadisticas.csv', 'r') as f:
    reader = csv.DictReader(f)
    for row in reader:
        print(f"{row['procesos']:<6} {row['elem_por_proc']:<12} {float(row['tiempo_promedio']):<10.6f} "
              f"{float(row['desv_std']):<10.6f} {float(row['min']):<8.6f} {float(row['max']):<8.6f} "
              f"{float(row['cv_pct']):<6.2f}")

print("\n" + "="*60)
print("TABLA 2: OVERHEAD DE SISTEMA (% tiempo en comunicación)")
print("="*60)
print(f"{'Procesos':<10} {'Elem/proc':<12} {'T_User':<10} {'T_Sys':<10} {'Overhead%':<10}")
print("-"*60)

with open('estadisticas.csv', 'r') as f:
    reader = csv.DictReader(f)
    for row in reader:
        print(f"{row['procesos']:<10} {row['elem_por_proc']:<12} {float(row['tiempo_user']):<10.6f} "
              f"{float(row['tiempo_sys']):<10.6f} {float(row['overhead_sys_pct']):<10.2f}")
EOF

echo ""
echo "═══════════════════════════════════════════════════"
echo "FASE 3: ANÁLISIS DE ESCALABILIDAD"
echo "═══════════════════════════════════════════════════"

# ============================================
# FASE 3: SPEEDUP Y EFICIENCIA
# ============================================
python3 - << 'EOF'
import csv
from collections import defaultdict

# Leer estadísticas
datos = {}
with open('estadisticas.csv', 'r') as f:
    reader = csv.DictReader(f)
    for row in reader:
        key = (row['procesos'], row['elem_por_proc'])
        datos[key] = float(row['tiempo_promedio'])

# Calcular speedup
tiempos_base = {}
for (proc, elem), tiempo in datos.items():
    if proc == '1':
        tiempos_base[elem] = tiempo

print("\n" + "="*70)
print("TABLA 3: SPEEDUP Y EFICIENCIA")
print("="*70)

for elem in sorted(tiempos_base.keys()):
    print(f"\n▶ Tamaño: {elem} elementos por proceso")
    print("-"*70)
    print(f"{'Procesos':<10} {'Tiempo(s)':<12} {'Speedup':<12} {'Eficiencia%':<15} {'Overhead':<10}")
    print("-"*70)
    
    t_base = tiempos_base[elem]
    
    for proc in ['1', '2', '4', '8']:
        key = (proc, elem)
        if key in datos:
            t = datos[key]
            speedup = t_base / t
            eficiencia = (speedup / int(proc)) * 100
            overhead = ((t * int(proc) - t_base) / t_base) * 100
            
            print(f"{proc:<10} {t:<12.6f} {speedup:<12.2f} {eficiencia:<15.1f} {overhead:<10.1f}%")

print("\n" + "="*70)
print("INTERPRETACIÓN:")
print("="*70)
print("• Speedup: Cuántas veces más rápido vs 1 proceso")
print("• Eficiencia: Qué tan bien se aprovechan los recursos (ideal=100%)")
print("• Overhead: Tiempo extra perdido en comunicación")
EOF

echo ""
echo "═══════════════════════════════════════════════════"
echo "FASE 4: ANÁLISIS DE COMUNICACIÓN"
echo "═══════════════════════════════════════════════════"

# ============================================
# FASE 4: IMPACTO DE LA COMUNICACIÓN
# ============================================
python3 - << 'EOF'
import csv

datos = {}
with open('estadisticas.csv', 'r') as f:
    reader = csv.DictReader(f)
    for row in reader:
        key = (row['procesos'], row['elem_por_proc'])
        datos[key] = {
            'tiempo': float(row['tiempo_promedio']),
            'overhead': float(row['overhead_sys_pct'])
        }

print("\n" + "="*60)
print("TABLA 4: IMPACTO DE LA COMUNICACIÓN")
print("="*60)
print(f"{'Procesos':<10} {'Elem/proc':<12} {'Overhead Comunicación%':<25}")
print("-"*60)

for key in sorted(datos.keys()):
    proc, elem = key
    overhead = datos[key]['overhead']
    print(f"{proc:<10} {elem:<12} {overhead:<25.2f}")

print("\n" + "="*60)
print("OBSERVACIONES:")
print("="*60)

# Análisis automático
for elem in ['10000', '100000', '1000000']:
    overheads = []
    for proc in ['2', '4', '8']:
        key = (proc, elem)
        if key in datos:
            overheads.append(datos[key]['overhead'])
    
    if len(overheads) >= 2:
        if overheads[-1] > overheads[0] * 1.5:
            print(f"⚠ Con {elem} elem: El overhead aumenta significativamente con más procesos")
        elif overheads[-1] < overheads[0] * 0.8:
            print(f"✓ Con {elem} elem: El overhead mejora con más procesos")
        else:
            print(f"→ Con {elem} elem: El overhead se mantiene estable")
EOF

echo ""
echo "═══════════════════════════════════════════════════"
echo "FASE 5: GENERACIÓN DE GRÁFICOS INTERACTIVOS"
echo "═══════════════════════════════════════════════════"
echo ""

# Verificar si plotly está instalado
if python3 -c "import plotly" 2>/dev/null; then
    echo "Generando gráficos con Plotly..."
    python3 generar_graficos.py
    echo ""
    echo "✓ Gráficos HTML interactivos generados"
    echo "  Abre los archivos .html en tu navegador"
else
    echo "⚠ Plotly no está instalado"
    echo "  Para generar gráficos, instala: pip3 install plotly"
    echo "  Luego ejecuta: python3 generar_graficos.py"
fi

echo ""
echo "═══════════════════════════════════════════════════"
echo "RESUMEN FINAL"
echo "═══════════════════════════════════════════════════"
echo ""
echo "📁 Archivos generados:"
echo "   • resultados.csv - Todos los tiempos medidos"
echo "   • estadisticas.csv - Promedios y estadísticas"
echo "   • grafico*.html - Gráficos interactivos (si plotly instalado)"
echo ""
echo "📊 Gráficos disponibles:"
echo "   • grafico1_tiempos.html - Tiempo vs Procesos"
echo "   • grafico2_speedup.html - Análisis de Speedup"
echo "   • grafico3_eficiencia.html - Análisis de Eficiencia"
echo "   • grafico4_overhead.html - Overhead de Comunicación"
echo "   • grafico5_composicion.html - Cómputo vs Comunicación"
echo "   • grafico6_dashboard.html - Dashboard completo"
echo ""
echo "✓ Análisis completado"
echo ""
