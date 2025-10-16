# Benchmark MPI - Cálculo de Promedios

Este benchmark mide el rendimiento de comunicación y procesamiento usando MPI (Message Passing Interface) para calcular promedios de arreglos distribuidos.

## Requisitos previos

### Instalación de dependencias en Linux

```bash
# Para distribuciones basadas en Debian/Ubuntu
sudo apt-get update
sudo apt-get install -y build-essential openmpi-bin openmpi-common libopenmpi-dev bc

# Para distribuciones basadas en Red Hat/CentOS/Fedora
sudo yum install -y gcc make openmpi openmpi-devel bc
# O con dnf
sudo dnf install -y gcc make openmpi openmpi-devel bc

# Para Arch Linux
sudo pacman -S gcc make openmpi bc
```

### Verificar instalación

```bash
# Verificar que MPI está instalado correctamente
mpicc --version
mpirun --version
```

## Estructura de archivos

```
parcial/
├── avg.c              # Código fuente MPI
├── lista_nodos        # Archivo de configuración de nodos
├── run_benchmarks.sh  # Script de ejecución del benchmark
└── README.md          # Este archivo
```

## Configuración

### 1. Configuración de nodos (para ejecución distribuida)

Edita el archivo `lista_nodos` para especificar los nodos disponibles:

```
server  slots=4
worker1 slots=4
```

- `server`: nombre del nodo principal
- `worker1`: nombre del nodo secundario
- `slots`: número de procesos que puede ejecutar cada nodo

### 2. Configuración SSH (para ejecución distribuida)

Para ejecutar en múltiples máquinas, necesitas configurar SSH sin contraseña:

```bash
# Generar clave SSH (si no existe)
ssh-keygen -t rsa -b 4096

# Copiar clave al nodo remoto
ssh-copy-id usuario@worker1

# Verificar conexión
ssh usuario@worker1 "hostname"
```

### 3. Configurar archivo /etc/hosts (opcional)

Agrega las direcciones IP de los nodos:

```bash
sudo nano /etc/hosts
```

Añade:
```
192.168.1.10    server
192.168.1.11    worker1
```

## Ejecución

### Ejecución local (una sola máquina)

```bash
# Dar permisos de ejecución al script
chmod +x run_benchmarks.sh

# Ejecutar el benchmark
./run_benchmarks.sh
```

**Nota importante:** Todo lo que se imprime en pantalla durante la ejecución del benchmark se guarda automáticamente en un archivo de texto llamado `resultados_benchmark_YYYYMMDD_HHMMSS.txt`. Esto incluye:
- Cada iteración de cada prueba
- Todos los tiempos medidos
- Tablas de análisis comparativo
- Speedup, eficiencia y overhead

El archivo se crea en el mismo directorio donde ejecutas el script.

### Ejecución manual paso a paso

Si prefieres ejecutar manualmente:

```bash
# 1. Compilar el código
mpicc -o avg avg.c -lm

# 2. Ejecutar con 1 proceso
mpirun -np 1 ./avg 10000

# 3. Ejecutar con 4 procesos
mpirun -np 4 ./avg 10000

# 4. Ejecutar en múltiples nodos
mpirun --hostfile lista_nodos -np 8 ./avg 10000
```

### Personalizar parámetros del benchmark

Edita `run_benchmarks.sh` para modificar:

```bash
NUM_ITERACIONES=10  # Número de ejecuciones para promediar
TAMANIOS=(1000 10000 100000 1000000)  # Elementos por proceso
```

## Interpretación de resultados

El script genera estadísticas detalladas:

### 1. Tiempo de ejecución
- **Promedio**: tiempo medio de ejecución
- **Desviación estándar**: variabilidad de los tiempos
- **Min/Max**: tiempos extremos observados

### 2. Speedup
```
Speedup = T(1 proceso) / T(N procesos)
```
- Speedup ideal = N (escalamiento lineal)
- Valores menores indican overhead de comunicación

### 3. Eficiencia
```
Eficiencia = (Speedup / N procesos) × 100%
```
- 100% = utilización perfecta de recursos
- Valores bajos indican contención o overhead

### 4. Overhead de comunicación
```
Overhead = T_distribuido - T_local
```
- Positivo: la red añade latencia
- Negativo: posible beneficio de caché/distribución

## Escenarios de prueba

### Escenario 1: Una sola máquina (local)
- 1 proceso
- 2 procesos
- 4 procesos

### Escenario 2: Múltiples máquinas (distribuido)
- 2 procesos (1 por nodo)
- 4 procesos (2 por nodo)
- 8 procesos (4 por nodo)

## Solución de problemas

### Error: "mpicc: command not found"
```bash
# Instalar MPI
sudo apt-get install openmpi-bin libopenmpi-dev
```

### Error: "Permission denied" al ejecutar el script
```bash
chmod +x run_benchmarks.sh
```

### Error: "Unable to connect to remote host"
- Verificar conectividad: `ping worker1`
- Verificar SSH: `ssh usuario@worker1`
- Revisar configuración de firewall

### Error: "bc: command not found"
```bash
sudo apt-get install bc
```

### Problemas de formato decimal (coma vs punto)
Si ves errores como:
```
printf: .256711: invalid number
```

Esto ocurre cuando tu sistema usa coma (,) como separador decimal (configuración española). El script ya incluye `export LC_NUMERIC=C` al inicio para forzar punto decimal.

Si el problema persiste, ejecuta manualmente:
```bash
export LC_ALL=C
./run_benchmarks.sh
```

### Programa se traba en pruebas distribuidas
Si el benchmark se congela en "Prueba: 2 máquinas, 8 procesos":

1. **Ejecutable no está en nodos remotos**: Copia manualmente el ejecutable
   ```bash
   scp avg usuario@worker1:$(pwd)/
   ```

2. **Firewall bloqueando puertos MPI**: Desactiva temporalmente el firewall
   ```bash
   sudo ufw disable
   ```

3. **Ruta de trabajo diferente**: Asegúrate de ejecutar desde el mismo directorio en todos los nodos
   ```bash
   ssh worker1 "cd $(pwd) && ls avg"
   ```

### Problemas con múltiples nodos
1. Asegurar que el código está compilado en todos los nodos
2. Verificar que las rutas de archivos son consistentes
3. Comprobar que MPI está instalado en todos los nodos
4. El ejecutable `avg` debe existir en la misma ruta en todos los nodos

## Resultados del Benchmark

### Archivo de salida

Cuando ejecutas el benchmark, se genera un archivo con formato: `resultados_benchmark_YYYYMMDD_HHMMSS.txt`

Por ejemplo: `resultados_benchmark_20251016_174750.txt`

Este archivo contiene toda la información de la ejecución del benchmark.

### Ejemplo de salida e interpretación

```
==========================================
Benchmark MPI - Cálculo de Promedios
==========================================

>>> Compilando avg.c...
>>> Compilación exitosa

>>> Configuración del benchmark:
    - Iteraciones por prueba: 5
    - Tamaños de entrada: 1000 10000 100000 1000000
    - Nodos: 2 (server + worker1)
    - Guardando salida en: resultados_benchmark_20251016_174750.txt

==========================================
ESCENARIO 1: Una sola máquina (local)
==========================================

----------------------------------------
Prueba: 1 máquina, 1 proceso
Procesos: 1 | Elementos/proceso: 1000
----------------------------------------
  Ejecución 1/5... 0.002345s
  Ejecución 2/5... 0.002301s
  Ejecución 3/5... 0.002389s
  Ejecución 4/5... 0.002298s
  Ejecución 5/5... 0.002312s

  RESULTADOS:
    Tiempo promedio: 0.002329s
    Desviación estándar: 0.000035s
    Tiempo mínimo: 0.002298s
    Tiempo máximo: 0.002389s

----------------------------------------
Prueba: 1 máquina, 2 procesos
Procesos: 2 | Elementos/proceso: 1000
----------------------------------------
  Ejecución 1/5... 0.003156s
  Ejecución 2/5... 0.003201s
  ...

==========================================
ESCENARIO 2: Múltiples máquinas (2 nodos)
==========================================

----------------------------------------
Prueba: 2 máquinas, 2 procesos (1 por nodo)
Procesos: 2 | Elementos/proceso: 1000
----------------------------------------
  Ejecución 1/5... 0.256711s
  Ejecución 2/5... 0.244382s
  ...

==========================================
ANÁLISIS COMPARATIVO DE RESULTADOS
==========================================

==========================================
TAMAÑO: 1000000 elementos por proceso
==========================================

--- ESCALABILIDAD LOCAL ---
Configuración                 Tiempo(s)    Speedup    Eficiencia
----------------------------------------------------------------
1 proceso                      0.260000      1.000     100.00%
2 procesos                     0.265000      0.981      49.05%
4 procesos                     0.295000      0.881      22.03%

--- ESCALABILIDAD DISTRIBUIDA (2 nodos) ---
Configuración                 Tiempo(s)    Speedup    Eficiencia
----------------------------------------------------------------
2 proc (1 por nodo)            1.528000      0.170       8.50%
4 proc (2 por nodo)            1.832000      0.142       3.55%
8 proc (4 por nodo)            2.450000      0.106       1.33%

--- OVERHEAD DE COMUNICACIÓN (LOCAL vs DISTRIBUIDO) ---
Procesos    T_Local(s)  T_Distrib(s)  Overhead(s)  Overhead(%)
----------------------------------------------------------------
2            0.265000      1.528000      1.263000      476.60%
4            0.295000      1.832000      1.537000      521.02%
```

### Interpretación de resultados

#### 1. Tiempos de ejecución
- **Tiempo promedio**: Media aritmética de las 5 ejecuciones
- **Desviación estándar**: Indica la variabilidad de los tiempos (valores bajos = resultados consistentes)
- **Min/Max**: Límites inferior y superior de los tiempos observados

#### 2. Speedup
```
Speedup = Tiempo(1 proceso) / Tiempo(N procesos)
```
- **Ideal**: Speedup = N (escalamiento lineal perfecto)
- **Ejemplo**: Con 2 procesos, Speedup ideal = 2.0
- **Si Speedup < 1**: El paralelismo está ralentizando la ejecución

#### 3. Eficiencia
```
Eficiencia = (Speedup / N procesos) × 100%
```
- **Ideal**: 100% (uso perfecto de recursos)
- **> 50%**: Paralelización efectiva
- **< 50%**: Overhead de comunicación demasiado alto

#### 4. Overhead de comunicación
```
Overhead = Tiempo_Distribuido - Tiempo_Local
```
- **Positivo grande**: La red añade mucha latencia
- **Ejemplo**: 476.60% significa que la versión distribuida es 4.76x más lenta debido a la comunicación de red

### Conclusiones del ejemplo

Para este benchmark con datasets pequeños a medianos:

1. **No hay beneficio de paralelización local**: Con más procesos, el tiempo aumenta (Speedup < 1)
2. **La distribución de red es muy costosa**: Overhead de 400-500%
3. **Problema computacionalmente simple**: El overhead de MPI supera el beneficio del paralelismo
4. **Recomendación**: Para este tipo de cálculo, usar 1 proceso es más eficiente

Para obtener beneficios de MPI se necesitarían:
- Datasets mucho más grandes (ej. 100+ millones de elementos)
- Operaciones más complejas computacionalmente
- Red de baja latencia (InfiniBand, 10Gbps+)
```

## Referencias

- Código basado en tutorial MPI: https://www.mpitutorial.com
- Documentación Open MPI: https://www.open-mpi.org/doc/
- Tutorial MPI en español: https://computing.llnl.gov/tutorials/mpi/

## Autor

Script de benchmark creado para análisis de rendimiento de MPI.
Código base: Wes Kendall (www.mpitutorial.com)
