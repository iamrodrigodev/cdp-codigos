# ANÁLISIS DE RENDIMIENTO MPI - INSTRUCCIONES

## 🚀 INSTALACIÓN RÁPIDA

### Opción 1: Script automático
```bash
chmod +x instalar.sh
./instalar.sh
```

### Opción 2: Manual (si falla el script)
```bash
# 1. Instalar dependencias del sistema
sudo apt update
sudo apt install -y python3-pip python3-venv

# 2. Crear y activar entorno virtual
python3 -m venv venv
source venv/bin/activate  # En Linux/Mac
# venv\Scripts\activate   # En Windows

# 3. Instalar librerías Python en el entorno virtual
pip install plotly numpy pandas

# 4. Dar permisos de ejecución
chmod +x medir_tiempos.sh
chmod +x generar_graficos.py
```

**Nota:** Recuerda activar el entorno virtual cada vez que vayas a ejecutar los scripts:
```bash
source venv/bin/activate
```

## 📊 EJECUTAR ANÁLISIS

```bash
# Asegúrate de tener el entorno virtual activado
source venv/bin/activate  # En Linux/Mac
# venv\Scripts\activate   # En Windows

# Ejecutar el análisis
./medir_tiempos.sh
```

Este script hará:
- ✅ Compilar avg.c
- ✅ Ejecutar 10 veces cada configuración
- ✅ Medir tiempos (1, 2, 4, 8 procesos)
- ✅ Calcular estadísticas, speedup, eficiencia
- ✅ Generar 6 gráficos HTML interactivos

## 📈 ARCHIVOS GENERADOS

**CSV (datos):**
- `resultados.csv` - Todas las mediciones
- `estadisticas.csv` - Promedios y análisis

**HTML (gráficos interactivos):**
- `grafico1_tiempos.html` - Tiempo vs Procesos
- `grafico2_speedup.html` - Speedup
- `grafico3_eficiencia.html` - Eficiencia
- `grafico4_overhead.html` - Overhead comunicación
- `grafico5_composicion.html` - Cómputo vs Comunicación
- `grafico6_dashboard.html` - Dashboard completo

## 🖥️ USO CON MÚLTIPLES VMs

### 1. Preparar ambas VMs

En cada VM:
```bash
sudo apt install openmpi-bin openmpi-common libopenmpi-dev
```

### 2. Configurar SSH sin contraseña

En VM1:
```bash
ssh-keygen -t rsa -N ""
ssh-copy-id usuario@ip_vm2
```

En VM2:
```bash
ssh-keygen -t rsa -N ""
ssh-copy-id usuario@ip_vm1
```

### 3. Crear hostfile

```bash
nano hostfile
```

Contenido (ajusta las IPs):
```
192.168.1.10 slots=2
192.168.1.11 slots=2
```

### 4. Copiar archivos a ambas VMs

Copia `avg.c` y el ejecutable compilado a la MISMA ruta en ambas VMs.

### 5. Ejecutar desde una VM

```bash
# Compilar
mpicc -o avg avg.c

# Ejecutar con 4 procesos (2 en cada VM)
mpirun --hostfile hostfile -np 4 ./avg 1000000

# Medir tiempos
for i in {1..10}; do
  /usr/bin/time -f "%e" mpirun --hostfile hostfile -np 4 ./avg 1000000 2>&1 | grep -E '^[0-9]'
done
```

## 🔍 ANÁLISIS RECOMENDADO

### Comparar:
1. **1 VM con 4 procesos** vs **2 VMs con 2 procesos c/u**
2. **Diferentes tamaños de datos** (10K, 100K, 1M elementos)
3. **Overhead de red** entre VMs

### Métricas clave:
- **Speedup** = T(1 proceso) / T(N procesos)
- **Eficiencia** = Speedup / N × 100%
- **Overhead** = Tiempo en comunicación / Tiempo total

### Preguntas para el reporte:
1. ¿Cómo afecta el número de procesos al tiempo total?
2. ¿Cuál es el overhead de comunicación?
3. ¿Es mejor usar 1 VM o 2 VMs? ¿Por qué?
4. ¿Con qué tamaño de datos vale la pena paralelizar?

## 🐛 SOLUCIÓN DE PROBLEMAS

### Error: "pip3: orden no encontrada"
```bash
sudo apt install python3-pip
```

### Error: "mpirun: comando no encontrado"
```bash
sudo apt install openmpi-bin
```

### Error: "Permission denied" al ejecutar
```bash
chmod +x *.sh *.py
```

### Error: SSH pide contraseña
```bash
ssh-copy-id usuario@ip_otra_vm
```

## 📧 ARCHIVOS INCLUIDOS

- `avg.c` - Código original MPI
- `medir_tiempos.sh` - Script principal de análisis
- `generar_graficos.py` - Generador de gráficos Plotly
- `instalar.sh` - Instalador de dependencias
- `README.md` - Este archivo

## ✅ CHECKLIST

- [ ] MPI instalado (`openmpi-bin`)
- [ ] Python3, pip3 y python3-venv instalados
- [ ] Entorno virtual creado (`python3 -m venv venv`)
- [ ] Entorno virtual activado (`source venv/bin/activate`)
- [ ] Librerías Python instaladas (plotly, numpy, pandas)
- [ ] Código compilado
- [ ] Permisos de ejecución dados
- [ ] Ejecutar `./medir_tiempos.sh`
- [ ] Abrir archivos HTML en navegador
- [ ] Analizar resultados
