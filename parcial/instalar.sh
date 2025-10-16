#!/bin/bash

# Script de instalación rápida para el análisis MPI

echo "=========================================="
echo "  INSTALACIÓN RÁPIDA"
echo "=========================================="
echo ""

echo "Instalando dependencias Python..."
pip3 install plotly numpy pandas --quiet

if [ $? -eq 0 ]; then
    echo "✓ Plotly instalado correctamente"
else
    echo "⚠ Error al instalar. Intenta manualmente:"
    echo "  pip3 install plotly numpy pandas"
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
