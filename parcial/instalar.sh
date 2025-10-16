#!/bin/bash

# Script de instalación rápida para el análisis MPI

echo "=========================================="
echo "  INSTALACIÓN RÁPIDA"
echo "=========================================="
echo ""

# Verificar si pip3 está instalado
if ! command -v pip3 &> /dev/null; then
    echo "pip3 no encontrado. Instalando..."
    sudo apt update
    sudo apt install -y python3-pip
fi

echo "Instalando dependencias Python..."
pip3 install plotly numpy pandas --user

if [ $? -eq 0 ]; then
    echo "✓ Plotly instalado correctamente"
else
    echo "⚠ Error al instalar. Intenta manualmente:"
    echo "  sudo apt install python3-pip"
    echo "  pip3 install plotly numpy pandas --user"
fi

echo ""
echo "Dando permisos de ejecución..."
chmod +x medir_tiempos.sh
chmod +x generar_graficos.py

echo ""
echo "✓ Todo listo!"
echo ""
echo "Ejecuta: ./medir_tiempos.sh"
echo ""
