#!/usr/bin/env python3
"""
Script para generar gráficos interactivos del análisis de rendimiento MPI
Usa Plotly para gráficos HTML interactivos
"""

import csv
import plotly.graph_objects as go
from plotly.subplots import make_subplots
import numpy as np
from collections import defaultdict

print("Generando gráficos interactivos con Plotly...")

# Leer datos
datos_completos = defaultdict(list)
tiempos_user = defaultdict(list)
tiempos_sys = defaultdict(list)

with open('resultados.csv', 'r') as f:
    reader = csv.DictReader(f)
    for row in reader:
        key = (int(row['procesos']), int(row['elem_por_proc']))
        datos_completos[key].append(float(row['tiempo_real']))
        tiempos_user[key].append(float(row['tiempo_user']))
        tiempos_sys[key].append(float(row['tiempo_sys']))

# Calcular promedios
datos = {}
for key in datos_completos:
    datos[key] = {
        'tiempo': np.mean(datos_completos[key]),
        'std': np.std(datos_completos[key]),
        'user': np.mean(tiempos_user[key]),
        'sys': np.mean(tiempos_sys[key])
    }

# Obtener valores únicos
procesos_unicos = sorted(set(k[0] for k in datos.keys()))
elementos_unicos = sorted(set(k[1] for k in datos.keys()))

colores = ['#1f77b4', '#ff7f0e', '#2ca02c', '#d62728', '#9467bd', '#8c564b']

# ============================================
# GRÁFICO 1: TIEMPO TOTAL VS NÚMERO DE PROCESOS
# ============================================
fig1 = go.Figure()

for idx, elem in enumerate(elementos_unicos):
    procesos = []
    tiempos = []
    stds = []
    
    for proc in procesos_unicos:
        if (proc, elem) in datos:
            procesos.append(proc)
            tiempos.append(datos[(proc, elem)]['tiempo'])
            stds.append(datos[(proc, elem)]['std'])
    
    fig1.add_trace(go.Scatter(
        x=procesos,
        y=tiempos,
        mode='lines+markers',
        name=f'{elem:,} elem/proc',
        line=dict(width=3),
        marker=dict(size=10),
        error_y=dict(type='data', array=stds, visible=True),
        hovertemplate='<b>Procesos:</b> %{x}<br><b>Tiempo:</b> %{y:.6f}s<extra></extra>'
    ))

fig1.update_layout(
    title='<b>Tiempo de Ejecución vs Número de Procesos</b>',
    xaxis_title='<b>Número de Procesos</b>',
    yaxis_title='<b>Tiempo Total (segundos)</b>',
    hovermode='closest',
    template='plotly_white',
    font=dict(size=12),
    legend=dict(x=0.7, y=0.95),
    width=1200,
    height=700
)

fig1.write_html('grafico1_tiempos.html')
print("✓ grafico1_tiempos.html")

# ============================================
# GRÁFICO 2: SPEEDUP
# ============================================
fig2 = go.Figure()

# Línea ideal
max_proc = max(procesos_unicos)
fig2.add_trace(go.Scatter(
    x=[1, max_proc],
    y=[1, max_proc],
    mode='lines',
    name='Speedup Ideal',
    line=dict(dash='dash', width=2, color='black'),
    hovertemplate='<b>Ideal:</b> %{y:.2f}x<extra></extra>'
))

for idx, elem in enumerate(elementos_unicos):
    # Encontrar tiempo base (1 proceso)
    tiempo_base = None
    for proc in procesos_unicos:
        if (proc, elem) in datos:
            tiempo_base = datos[(proc, elem)]['tiempo']
            break
    
    if tiempo_base:
        procesos = []
        speedups = []
        
        for proc in procesos_unicos:
            if (proc, elem) in datos:
                procesos.append(proc)
                speedup = tiempo_base / datos[(proc, elem)]['tiempo']
                speedups.append(speedup)
        
        fig2.add_trace(go.Scatter(
            x=procesos,
            y=speedups,
            mode='lines+markers',
            name=f'{elem:,} elem/proc',
            line=dict(width=3),
            marker=dict(size=12, symbol='square'),
            hovertemplate='<b>Procesos:</b> %{x}<br><b>Speedup:</b> %{y:.2f}x<extra></extra>'
        ))

fig2.update_layout(
    title='<b>Speedup vs Número de Procesos</b>',
    xaxis_title='<b>Número de Procesos</b>',
    yaxis_title='<b>Speedup</b>',
    hovermode='closest',
    template='plotly_white',
    font=dict(size=12),
    legend=dict(x=0.05, y=0.95),
    width=1200,
    height=700
)

fig2.write_html('grafico2_speedup.html')
print("✓ grafico2_speedup.html")

# ============================================
# GRÁFICO 3: EFICIENCIA
# ============================================
fig3 = go.Figure()

# Línea de 100% eficiencia
fig3.add_trace(go.Scatter(
    x=[min(procesos_unicos), max(procesos_unicos)],
    y=[100, 100],
    mode='lines',
    name='Eficiencia Ideal (100%)',
    line=dict(dash='dash', width=2, color='black'),
    hovertemplate='<b>Ideal:</b> 100%<extra></extra>'
))

for idx, elem in enumerate(elementos_unicos):
    tiempo_base = None
    for proc in procesos_unicos:
        if (proc, elem) in datos:
            tiempo_base = datos[(proc, elem)]['tiempo']
            break
    
    if tiempo_base:
        procesos = []
        eficiencias = []
        
        for proc in procesos_unicos:
            if (proc, elem) in datos:
                procesos.append(proc)
                speedup = tiempo_base / datos[(proc, elem)]['tiempo']
                eficiencia = (speedup / proc) * 100
                eficiencias.append(eficiencia)
        
        fig3.add_trace(go.Scatter(
            x=procesos,
            y=eficiencias,
            mode='lines+markers',
            name=f'{elem:,} elem/proc',
            line=dict(width=3),
            marker=dict(size=12, symbol='triangle-up'),
            hovertemplate='<b>Procesos:</b> %{x}<br><b>Eficiencia:</b> %{y:.1f}%<extra></extra>'
        ))

fig3.update_layout(
    title='<b>Eficiencia vs Número de Procesos</b>',
    xaxis_title='<b>Número de Procesos</b>',
    yaxis_title='<b>Eficiencia (%)</b>',
    hovermode='closest',
    template='plotly_white',
    font=dict(size=12),
    legend=dict(x=0.7, y=0.95),
    yaxis=dict(range=[0, 110]),
    width=1200,
    height=700
)

fig3.write_html('grafico3_eficiencia.html')
print("✓ grafico3_eficiencia.html")

# ============================================
# GRÁFICO 4: OVERHEAD DE COMUNICACIÓN
# ============================================
fig4 = go.Figure()

for idx, elem in enumerate(elementos_unicos):
    procesos = []
    overheads = []
    
    for proc in procesos_unicos:
        if (proc, elem) in datos:
            procesos.append(proc)
            tiempo_total = datos[(proc, elem)]['tiempo']
            tiempo_sys = datos[(proc, elem)]['sys']
            overhead = (tiempo_sys / tiempo_total) * 100
            overheads.append(overhead)
    
    fig4.add_trace(go.Scatter(
        x=procesos,
        y=overheads,
        mode='lines+markers',
        name=f'{elem:,} elem/proc',
        line=dict(width=3),
        marker=dict(size=12, symbol='diamond'),
        hovertemplate='<b>Procesos:</b> %{x}<br><b>Overhead:</b> %{y:.2f}%<extra></extra>'
    ))

fig4.update_layout(
    title='<b>Overhead de Comunicación vs Número de Procesos</b>',
    xaxis_title='<b>Número de Procesos</b>',
    yaxis_title='<b>Overhead de Comunicación (%)</b>',
    hovermode='closest',
    template='plotly_white',
    font=dict(size=12),
    legend=dict(x=0.05, y=0.95),
    width=1200,
    height=700
)

fig4.write_html('grafico4_overhead.html')
print("✓ grafico4_overhead.html")

# ============================================
# GRÁFICO 5: COMPOSICIÓN DE TIEMPOS (BARRAS APILADAS)
# ============================================
fig5 = go.Figure()

# Para cada tamaño de elementos
for elem in elementos_unicos:
    procesos = []
    tiempos_comp = []
    tiempos_comm = []
    
    for proc in procesos_unicos:
        if (proc, elem) in datos:
            procesos.append(f"{proc}p")
            t_user = datos[(proc, elem)]['user']
            t_sys = datos[(proc, elem)]['sys']
            tiempos_comp.append(t_user)
            tiempos_comm.append(t_sys)
    
    # Crear subplots para cada tamaño
    trace_comp = go.Bar(
        name=f'Cómputo ({elem:,})',
        x=procesos,
        y=tiempos_comp,
        marker_color='lightblue',
        hovertemplate='<b>Cómputo:</b> %{y:.6f}s<extra></extra>'
    )
    
    trace_comm = go.Bar(
        name=f'Comunicación ({elem:,})',
        x=procesos,
        y=tiempos_comm,
        marker_color='salmon',
        hovertemplate='<b>Comunicación:</b> %{y:.6f}s<extra></extra>'
    )
    
    fig5.add_trace(trace_comp)
    fig5.add_trace(trace_comm)

fig5.update_layout(
    title='<b>Composición de Tiempos: Cómputo vs Comunicación</b>',
    xaxis_title='<b>Procesos</b>',
    yaxis_title='<b>Tiempo (segundos)</b>',
    barmode='stack',
    hovermode='closest',
    template='plotly_white',
    font=dict(size=12),
    width=1200,
    height=700
)

fig5.write_html('grafico5_composicion.html')
print("✓ grafico5_composicion.html")

# ============================================
# GRÁFICO 6: DASHBOARD COMPLETO (4 subplots)
# ============================================
fig6 = make_subplots(
    rows=2, cols=2,
    subplot_titles=('Tiempo Total', 'Speedup', 'Eficiencia', 'Overhead Comunicación'),
    specs=[[{"secondary_y": False}, {"secondary_y": False}],
           [{"secondary_y": False}, {"secondary_y": False}]]
)

# Subplot 1: Tiempo Total
for idx, elem in enumerate(elementos_unicos):
    procesos = []
    tiempos = []
    
    for proc in procesos_unicos:
        if (proc, elem) in datos:
            procesos.append(proc)
            tiempos.append(datos[(proc, elem)]['tiempo'])
    
    fig6.add_trace(go.Scatter(
        x=procesos, y=tiempos,
        mode='lines+markers',
        name=f'{elem:,}',
        line=dict(width=2),
        marker=dict(size=8),
        legendgroup=f'group{idx}',
        showlegend=True
    ), row=1, col=1)

# Subplot 2: Speedup
for idx, elem in enumerate(elementos_unicos):
    tiempo_base = None
    for proc in procesos_unicos:
        if (proc, elem) in datos:
            tiempo_base = datos[(proc, elem)]['tiempo']
            break
    
    if tiempo_base:
        procesos = []
        speedups = []
        
        for proc in procesos_unicos:
            if (proc, elem) in datos:
                procesos.append(proc)
                speedup = tiempo_base / datos[(proc, elem)]['tiempo']
                speedups.append(speedup)
        
        fig6.add_trace(go.Scatter(
            x=procesos, y=speedups,
            mode='lines+markers',
            name=f'{elem:,}',
            line=dict(width=2),
            marker=dict(size=8),
            legendgroup=f'group{idx}',
            showlegend=False
        ), row=1, col=2)

# Subplot 3: Eficiencia
for idx, elem in enumerate(elementos_unicos):
    tiempo_base = None
    for proc in procesos_unicos:
        if (proc, elem) in datos:
            tiempo_base = datos[(proc, elem)]['tiempo']
            break
    
    if tiempo_base:
        procesos = []
        eficiencias = []
        
        for proc in procesos_unicos:
            if (proc, elem) in datos:
                procesos.append(proc)
                speedup = tiempo_base / datos[(proc, elem)]['tiempo']
                eficiencia = (speedup / proc) * 100
                eficiencias.append(eficiencia)
        
        fig6.add_trace(go.Scatter(
            x=procesos, y=eficiencias,
            mode='lines+markers',
            name=f'{elem:,}',
            line=dict(width=2),
            marker=dict(size=8),
            legendgroup=f'group{idx}',
            showlegend=False
        ), row=2, col=1)

# Subplot 4: Overhead
for idx, elem in enumerate(elementos_unicos):
    procesos = []
    overheads = []
    
    for proc in procesos_unicos:
        if (proc, elem) in datos:
            procesos.append(proc)
            tiempo_total = datos[(proc, elem)]['tiempo']
            tiempo_sys = datos[(proc, elem)]['sys']
            overhead = (tiempo_sys / tiempo_total) * 100
            overheads.append(overhead)
    
    fig6.add_trace(go.Scatter(
        x=procesos, y=overheads,
        mode='lines+markers',
        name=f'{elem:,}',
        line=dict(width=2),
        marker=dict(size=8),
        legendgroup=f'group{idx}',
        showlegend=False
    ), row=2, col=2)

fig6.update_xaxes(title_text="Procesos", row=1, col=1)
fig6.update_xaxes(title_text="Procesos", row=1, col=2)
fig6.update_xaxes(title_text="Procesos", row=2, col=1)
fig6.update_xaxes(title_text="Procesos", row=2, col=2)

fig6.update_yaxes(title_text="Tiempo (s)", row=1, col=1)
fig6.update_yaxes(title_text="Speedup", row=1, col=2)
fig6.update_yaxes(title_text="Eficiencia (%)", row=2, col=1)
fig6.update_yaxes(title_text="Overhead (%)", row=2, col=2)

fig6.update_layout(
    title_text="<b>Dashboard Completo de Rendimiento MPI</b>",
    template='plotly_white',
    height=900,
    width=1400,
    font=dict(size=11)
)

fig6.write_html('grafico6_dashboard.html')
print("✓ grafico6_dashboard.html")

print("\n" + "="*60)
print("✓ GRÁFICOS GENERADOS EXITOSAMENTE")
print("="*60)
print("\nArchivos HTML interactivos creados:")
print("  1. grafico1_tiempos.html - Tiempo vs Procesos")
print("  2. grafico2_speedup.html - Análisis de Speedup")
print("  3. grafico3_eficiencia.html - Análisis de Eficiencia")
print("  4. grafico4_overhead.html - Overhead de Comunicación")
print("  5. grafico5_composicion.html - Cómputo vs Comunicación")
print("  6. grafico6_dashboard.html - Dashboard completo")
print("\nAbre cualquier archivo .html en tu navegador para ver gráficos interactivos!")
print("="*60)
