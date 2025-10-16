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

### Problemas con múltiples nodos
1. Asegurar que el código está compilado en todos los nodos
2. Verificar que las rutas de archivos son consistentes
3. Comprobar que MPI está instalado en todos los nodos

## Ejemplo de salida

```
==========================================
Benchmark MPI - Cálculo de Promedios
==========================================

>>> Compilando avg.c...
>>> Compilación exitosa

>>> Configuración del benchmark:
    - Iteraciones por prueba: 10
    - Tamaños de entrada: 1000 10000 100000 1000000
    - Nodos: 2 (server + worker1)

==========================================
ESCENARIO 1: Una sola máquina (local)
==========================================

Prueba: 1 máquina, 1 proceso
Procesos: 1 | Elementos/proceso: 10000
  Ejecución 1/10... 0.001234s
  ...
  RESULTADOS:
    Tiempo promedio: 0.001250s
    Desviación estándar: 0.000015s
    Tiempo mínimo: 0.001234s
    Tiempo máximo: 0.001289s
```

## Referencias

- Código basado en tutorial MPI: https://www.mpitutorial.com
- Documentación Open MPI: https://www.open-mpi.org/doc/
- Tutorial MPI en español: https://computing.llnl.gov/tutorials/mpi/

## Autor

Script de benchmark creado para análisis de rendimiento de MPI.
Código base: Wes Kendall (www.mpitutorial.com)
