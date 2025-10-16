#!/bin/bash

# Script para medir rendimiento MPI en MÚLTIPLES NODOS
# Compara: 1 nodo vs 2 nodos

echo "======================================================"
echo "   ANÁLISIS MPI: 1 NODO vs 2 NODOS"
echo "======================================================"
echo ""

# Verificar que existe lista_nodos
if [ ! -f "lista_nodos" ]; then
    echo "⚠ ERROR: No se encontró 'lista_nodos'"
    echo ""
    echo "Crea un archivo llamado 'lista_nodos' con el formato:"
    echo ""
    echo "  ip_vm1 slots=4"
    echo "  ip_vm2 slots=4"
    echo ""
    echo "Ejemplo:"
    echo "  192.168.1.10 slots=4"
    echo "  192.168.1.11 slots=4"
    echo ""
    exit 1
fi

echo "✓ Lista de nodos encontrada:"
cat lista_nodos
echo ""

# Verificar que avg.c está compilado
if [ ! -f "avg" ]; then
    echo "Compilando avg.c..."
    mpicc -o avg avg.c
fi

echo "✓ Programa compilado"
echo ""

# Crear archivos de resultados
echo "configuracion,procesos,elem_por_proc,elem_totales,tiempo_real,tiempo_user,tiempo_sys" > resultados_multinodo.csv

ELEMENTOS=(10000 100000 1000000)
REPETICIONES=10

echo "═══════════════════════════════════════════════════"
echo "FASE 1: PRUEBAS EN 1 NODO (LOCAL)"
echo "═══════════════════════════════════════════════════"
echo ""

for elem in "${ELEMENTOS[@]}"; do
    for np in 1 2 4; do
        total=$((elem * np))
        echo "  📊 $np procesos, $elem elem/proc ($total totales)"
        
        for i in $(seq 1 $REPETICIONES); do
            TIME_OUTPUT=$( { time mpirun -np $np ./avg $elem > /tmp/output_$$.txt 2>&1; } 2>&1 )
            
            real=$(echo "$TIME_OUTPUT" | grep real | awk '{print $2}' | sed 's/0m//;s/s//')
            user=$(echo "$TIME_OUTPUT" | grep user | awk '{print $2}' | sed 's/0m//;s/s//')
            sys=$(echo "$TIME_OUTPUT" | grep sys | awk '{print $2}' | sed 's/0m//;s/s//')
            
            [ -z "$real" ] && real="0"
            [ -z "$user" ] && user="0"
            [ -z "$sys" ] && sys="0"
            
            echo "1_nodo,$np,$elem,$total,$real,$user,$sys" >> resultados_multinodo.csv
            echo -n "."
        done
        echo " ✓"
    done
done

echo ""
echo "═══════════════════════════════════════════════════"
echo "FASE 2: PRUEBAS EN 2 NODOS (DISTRIBUIDO)"
echo "═══════════════════════════════════════════════════"
echo ""

# Verificar conectividad SSH
echo "Verificando conectividad con nodos..."
NODOS=$(grep -v '^#' hostfile | awk '{print $1}')
for nodo in $NODOS; do
    if ssh -o ConnectTimeout=2 -o BatchMode=yes $nodo "echo 'test'" 2>/dev/null; then
        echo "  ✓ Conexión OK con $nodo"
    else
        echo "  ✗ ERROR: No se puede conectar con $nodo"
        echo "    Configura SSH sin contraseña: ssh-copy-id usuario@$nodo"
        exit 1
    fi
done
echo ""

for elem in "${ELEMENTOS[@]}"; do
    for np in 2 4 8; do
        total=$((elem * np))
        echo "  📊 $np procesos distribuidos, $elem elem/proc ($total totales)"
        
        for i in $(seq 1 $REPETICIONES); do
            TIME_OUTPUT=$( { time mpirun --hostfile hostfile -np $np ./avg $elem > /tmp/output_$$.txt 2>&1; } 2>&1 )
            
            real=$(echo "$TIME_OUTPUT" | grep real | awk '{print $2}' | sed 's/0m//;s/s//')
            user=$(echo "$TIME_OUTPUT" | grep user | awk '{print $2}' | sed 's/0m//;s/s//')
            sys=$(echo "$TIME_OUTPUT" | grep sys | awk '{print $2}' | sed 's/0m//;s/s//')
            
            [ -z "$real" ] && real="0"
            [ -z "$user" ] && user="0"
            [ -z "$sys" ] && sys="0"
            
            echo "2_nodos,$np,$elem,$total,$real,$user,$sys" >> resultados_multinodo.csv
            echo -n "."
        done
        echo " ✓"
    done
done

echo ""
echo "═══════════════════════════════════════════════════"
echo "ANÁLISIS COMPARATIVO"
echo "═══════════════════════════════════════════════════"

python3 - << 'EOF'
import csv
from collections import defaultdict
import math

# Leer datos
datos = defaultdict(lambda: defaultdict(list))

with open('resultados_multinodo.csv', 'r') as f:
    reader = csv.DictReader(f)
    for row in reader:
        config = row['configuracion']
        key = (row['procesos'], row['elem_por_proc'])
        datos[config][key].append(float(row['tiempo_real']))

# Calcular promedios
def promedio(lista):
    return sum(lista) / len(lista) if lista else 0

def desv_std(lista):
    if len(lista) < 2:
        return 0
    prom = promedio(lista)
    varianza = sum((x - prom) ** 2 for x in lista) / (len(lista) - 1)
    return math.sqrt(varianza)

print("\n" + "="*80)
print("COMPARACIÓN: 1 NODO vs 2 NODOS")
print("="*80)
print(f"{'Procesos':<10} {'Elem/proc':<12} {'1 Nodo (s)':<15} {'2 Nodos (s)':<15} {'Diferencia':<15}")
print("-"*80)

for elem in sorted(set(k[1] for config in datos.values() for k in config.keys())):
    print(f"\n▶ Tamaño: {elem} elementos por proceso")
    print("-"*80)
    
    for proc in sorted(set(k[0] for config in datos.values() for k in config.keys())):
        key = (proc, elem)
        
        t_1nodo = promedio(datos['1_nodo'].get(key, []))
        t_2nodos = promedio(datos['2_nodos'].get(key, []))
        
        if t_1nodo > 0 and t_2nodos > 0:
            dif = ((t_2nodos - t_1nodo) / t_1nodo) * 100
            simbolo = "⬆" if dif > 0 else "⬇"
            
            print(f"{proc:<10} {elem:<12} {t_1nodo:<15.6f} {t_2nodos:<15.6f} {simbolo} {abs(dif):<13.2f}%")
        elif t_1nodo > 0:
            print(f"{proc:<10} {elem:<12} {t_1nodo:<15.6f} {'N/A':<15} {'N/A':<15}")
        elif t_2nodos > 0:
            print(f"{proc:<10} {elem:<12} {'N/A':<15} {t_2nodos:<15.6f} {'N/A':<15}")

print("\n" + "="*80)
print("ANÁLISIS DE OVERHEAD DE RED")
print("="*80)

# Calcular overhead promedio
overhead_total = []
for elem in sorted(set(k[1] for config in datos.values() for k in config.keys())):
    for proc in sorted(set(k[0] for config in datos.values() for k in config.keys())):
        key = (proc, elem)
        t_1nodo = promedio(datos['1_nodo'].get(key, []))
        t_2nodos = promedio(datos['2_nodos'].get(key, []))
        
        if t_1nodo > 0 and t_2nodos > 0 and int(proc) >= 2:
            overhead = ((t_2nodos - t_1nodo) / t_1nodo) * 100
            overhead_total.append(overhead)

if overhead_total:
    overhead_prom = promedio(overhead_total)
    print(f"\nOverhead promedio de comunicación entre nodos: {overhead_prom:.2f}%")
    
    if overhead_prom > 20:
        print("⚠ ALTO: La red es un cuello de botella significativo")
    elif overhead_prom > 10:
        print("⚡ MODERADO: Hay overhead de red notable")
    else:
        print("✓ BAJO: La red no es un problema importante")

print("\n" + "="*80)
print("CONCLUSIONES")
print("="*80)

# Analizar cuando conviene usar 2 nodos
print("\n¿Cuándo conviene usar 2 nodos?")
for elem in sorted(set(k[1] for config in datos.values() for k in config.keys())):
    mejor_config = None
    mejor_tiempo = float('inf')
    
    for config in ['1_nodo', '2_nodos']:
        for proc in ['4', '8']:
            key = (proc, elem)
            t = promedio(datos[config].get(key, []))
            if t > 0 and t < mejor_tiempo:
                mejor_tiempo = t
                mejor_config = f"{config} con {proc} procesos"
    
    if mejor_config:
        print(f"  • Con {elem} elem/proc: {mejor_config} ({mejor_tiempo:.6f}s)")

EOF

echo ""
echo "═══════════════════════════════════════════════════"
echo "RESUMEN"
echo "═══════════════════════════════════════════════════"
echo ""
echo "📁 Resultados guardados en: resultados_multinodo.csv"
echo ""
echo "📊 Para generar gráficos comparativos:"
echo "   python3 generar_graficos_multinodo.py"
echo ""
