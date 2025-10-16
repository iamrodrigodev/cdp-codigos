#!/usr/bin/env python3
"""
Gráficos comparativos: 1 Nodo vs 2 Nodos
"""

import csv
import plotly.graph_objects as go
from plotly.subplots import make_subplots
import numpy as np
from collections import defaultdict

print("Generando gráficos comparativos 1 Nodo vs 2 Nodos...")

# Leer datos
datos = defaultdict(lambda: defaultdict(list))

with open('resultados_multinodo.csv', 'r') as f:
    reader = csv.DictReader(f)
    for row in reader:
        config = row['configuracion']
        key = (int(row['procesos']), int(row['elem_por_proc']))
        datos[config][key].append(float(row['tiempo_real']))

# Calcular promedios
promedios = defaultdict(dict)
for config in datos:
    for key in datos[config]:
        promedios[config][key] = np.mean(datos[config][key])

elementos_unicos = sorted(set(k[1] for config in promedios.values() for k in config.keys()))
procesos_unicos = sorted(set(k[0] for config in promedios.values() for k in config.keys()))

# ============================================
# GRÁFICO 1: COMPARACIÓN DIRECTA 1 NODO vs 2 NODOS
# ============================================
fig1 = make_subplots(
    rows=1, cols=len(elementos_unicos),
    subplot_titles=[f'{elem:,} elem/proc' for elem in elementos_unicos]
)

for idx, elem in enumerate(elementos_unicos, 1):
    # 1 Nodo
    procs_1nodo = []
    tiempos_1nodo = []
    for proc in procesos_unicos:
        if (proc, elem) in promedios['1_nodo']:
            procs_1nodo.append(proc)
            tiempos_1nodo.append(promedios['1_nodo'][(proc, elem)])
    
    fig1.add_trace(go.Bar(
        name='1 Nodo' if idx == 1 else '',
        x=procs_1nodo,
        y=tiempos_1nodo,
        marker_color='lightblue',
        showlegend=(idx == 1),
        legendgroup='1nodo',
        hovertemplate='<b>1 Nodo</b><br>Procesos: %{x}<br>Tiempo: %{y:.6f}s<extra></extra>'
    ), row=1, col=idx)
    
    # 2 Nodos
    procs_2nodos = []
    tiempos_2nodos = []
    for proc in procesos_unicos:
        if (proc, elem) in promedios['2_nodos']:
            procs_2nodos.append(proc)
            tiempos_2nodos.append(promedios['2_nodos'][(proc, elem)])
    
    fig1.add_trace(go.Bar(
        name='2 Nodos' if idx == 1 else '',
        x=procs_2nodos,
        y=tiempos_2nodos,
        marker_color='salmon',
        showlegend=(idx == 1),
        legendgroup='2nodos',
        hovertemplate='<b>2 Nodos</b><br>Procesos: %{x}<br>Tiempo: %{y:.6f}s<extra></extra>'
    ), row=1, col=idx)
    
    fig1.update_xaxes(title_text="Procesos", row=1, col=idx)
    fig1.update_yaxes(title_text="Tiempo (s)" if idx == 1 else "", row=1, col=idx)

fig1.update_layout(
    title='<b>Comparación: 1 Nodo vs 2 Nodos</b>',
    template='plotly_white',
    height=500,
    width=1400,
    barmode='group'
)

fig1.write_html('comparacion_1vs2_nodos.html')
print("✓ comparacion_1vs2_nodos.html")

# ============================================
# GRÁFICO 2: OVERHEAD DE RED
# ============================================
fig2 = go.Figure()

for elem in elementos_unicos:
    procesos = []
    overheads = []
    
    for proc in procesos_unicos:
        if (proc, elem) in promedios['1_nodo'] and (proc, elem) in promedios['2_nodos']:
            t_1nodo = promedios['1_nodo'][(proc, elem)]
            t_2nodos = promedios['2_nodos'][(proc, elem)]
            overhead = ((t_2nodos - t_1nodo) / t_1nodo) * 100
            
            procesos.append(proc)
            overheads.append(overhead)
    
    fig2.add_trace(go.Scatter(
        x=procesos,
        y=overheads,
        mode='lines+markers',
        name=f'{elem:,} elem/proc',
        line=dict(width=3),
        marker=dict(size=10),
        hovertemplate='<b>Procesos:</b> %{x}<br><b>Overhead:</b> %{y:.2f}%<extra></extra>'
    ))

fig2.update_layout(
    title='<b>Overhead de Comunicación entre Nodos</b>',
    xaxis_title='<b>Número de Procesos</b>',
    yaxis_title='<b>Overhead (%)</b>',
    template='plotly_white',
    hovermode='closest',
    width=1200,
    height=700
)

fig2.add_hline(y=0, line_dash="dash", line_color="black", 
               annotation_text="Sin overhead", annotation_position="right")

fig2.write_html('overhead_red.html')
print("✓ overhead_red.html")

# ============================================
# GRÁFICO 3: SPEEDUP COMPARATIVO
# ============================================
fig3 = make_subplots(
    rows=1, cols=2,
    subplot_titles=('Speedup - 1 Nodo', 'Speedup - 2 Nodos')
)

# Speedup ideal
max_proc = max(procesos_unicos)
fig3.add_trace(go.Scatter(
    x=[1, max_proc],
    y=[1, max_proc],
    mode='lines',
    name='Ideal',
    line=dict(dash='dash', color='black', width=2),
    showlegend=True,
    legendgroup='ideal'
), row=1, col=1)

fig3.add_trace(go.Scatter(
    x=[1, max_proc],
    y=[1, max_proc],
    mode='lines',
    name='Ideal',
    line=dict(dash='dash', color='black', width=2),
    showlegend=False,
    legendgroup='ideal'
), row=1, col=2)

# Speedup 1 Nodo
for elem in elementos_unicos:
    tiempo_base = None
    for proc in procesos_unicos:
        if (proc, elem) in promedios['1_nodo']:
            tiempo_base = promedios['1_nodo'][(proc, elem)]
            break
    
    if tiempo_base:
        procs = []
        speedups = []
        for proc in procesos_unicos:
            if (proc, elem) in promedios['1_nodo']:
                procs.append(proc)
                speedups.append(tiempo_base / promedios['1_nodo'][(proc, elem)])
        
        fig3.add_trace(go.Scatter(
            x=procs,
            y=speedups,
            mode='lines+markers',
            name=f'{elem:,}',
            legendgroup=f'elem{elem}',
            showlegend=True
        ), row=1, col=1)

# Speedup 2 Nodos
for elem in elementos_unicos:
    tiempo_base = None
    for proc in procesos_unicos:
        if (proc, elem) in promedios['2_nodos']:
            tiempo_base = promedios['2_nodos'][(proc, elem)]
            break
    
    if tiempo_base:
        procs = []
        speedups = []
        for proc in procesos_unicos:
            if (proc, elem) in promedios['2_nodos']:
                procs.append(proc)
                speedups.append(tiempo_base / promedios['2_nodos'][(proc, elem)])
        
        fig3.add_trace(go.Scatter(
            x=procs,
            y=speedups,
            mode='lines+markers',
            name=f'{elem:,}',
            legendgroup=f'elem{elem}',
            showlegend=False
        ), row=1, col=2)

fig3.update_xaxes(title_text="Procesos", row=1, col=1)
fig3.update_xaxes(title_text="Procesos", row=1, col=2)
fig3.update_yaxes(title_text="Speedup", row=1, col=1)
fig3.update_yaxes(title_text="Speedup", row=1, col=2)

fig3.update_layout(
    title='<b>Speedup: 1 Nodo vs 2 Nodos</b>',
    template='plotly_white',
    height=600,
    width=1400
)

fig3.write_html('speedup_comparativo.html')
print("✓ speedup_comparativo.html")

# ============================================
# GRÁFICO 4: EFICIENCIA COMPARATIVA
# ============================================
fig4 = go.Figure()

for config in ['1_nodo', '2_nodos']:
    for elem in elementos_unicos:
        tiempo_base = None
        for proc in procesos_unicos:
            if (proc, elem) in promedios[config]:
                tiempo_base = promedios[config][(proc, elem)]
                break
        
        if tiempo_base:
            procs = []
            eficiencias = []
            for proc in procesos_unicos:
                if (proc, elem) in promedios[config]:
                    speedup = tiempo_base / promedios[config][(proc, elem)]
                    eficiencia = (speedup / proc) * 100
                    procs.append(proc)
                    eficiencias.append(eficiencia)
            
            linestyle = 'solid' if config == '1_nodo' else 'dash'
            fig4.add_trace(go.Scatter(
                x=procs,
                y=eficiencias,
                mode='lines+markers',
                name=f'{elem:,} - {config.replace("_", " ").title()}',
                line=dict(width=2, dash=linestyle),
                marker=dict(size=8)
            ))

fig4.add_hline(y=100, line_dash="dash", line_color="black",
               annotation_text="100% Eficiencia", annotation_position="right")

fig4.update_layout(
    title='<b>Eficiencia: 1 Nodo vs 2 Nodos</b>',
    xaxis_title='<b>Número de Procesos</b>',
    yaxis_title='<b>Eficiencia (%)</b>',
    template='plotly_white',
    hovermode='closest',
    width=1200,
    height=700,
    yaxis=dict(range=[0, 110])
)

fig4.write_html('eficiencia_comparativa.html')
print("✓ eficiencia_comparativa.html")

print("\n" + "="*60)
print("✓ GRÁFICOS COMPARATIVOS GENERADOS")
print("="*60)
print("\nArchivos HTML creados:")
print("  1. comparacion_1vs2_nodos.html - Comparación directa")
print("  2. overhead_red.html - Overhead de red")
print("  3. speedup_comparativo.html - Speedup en ambas configuraciones")
print("  4. eficiencia_comparativa.html - Eficiencia comparada")
print("\n¡Abre los archivos en tu navegador!")
print("="*60)
