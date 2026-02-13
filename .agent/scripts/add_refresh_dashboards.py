#!/usr/bin/env python3
"""
Script para adicionar _refreshDashboard() após TODAS as navegações nos dashboards.
"""

import re
import os

def add_refresh_to_navigations(file_path):
    """Adiciona await e _refreshDashboard() após Navigator.push"""
    
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Padrão: onTap: () { Navigator.push(...); }
    # Substituir por: onTap: () async { await Navigator.push(...); _refreshDashboard(); }
    
    # Pattern 1: onTap: () { Navigator.push
    pattern1 = r'(onTap:\s*\(\)\s*\{)\s*(Navigator\.push)'
    replacement1 = r'\1 async {\n                  await \2'
    
    content = re.sub(pattern1, replacement1, content)
    
    # Pattern 2: Adicionar _refreshDashboard(); antes do }); que fecha o onTap
    # Procurar por padrões como:
    #   ),
    # );
    # },
    
    pattern2 = r'(\s+\),\s+\);\s+)(\},)'
    replacement2 = r'\1_refreshDashboard();\n                \2'
    
    content = re.sub(pattern2, replacement2, content)
    
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"✅ Processado: {file_path}")

# Processar os dashboards
dashboards = [
    r'c:\Users\Danillo\.gemini\antigravity\scratch\spartan_app\lib\screens\student\student_dashboard.dart',
    r'c:\Users\Danillo\.gemini\antigravity\scratch\spartan_app\lib\screens\nutritionist\nutritionist_dashboard.dart',
    r'c:\Users\Danillo\.gemini\antigravity\scratch\spartan_app\lib\screens\trainer\trainer_dashboard.dart',
]

for dashboard in dashboards:
    if os.path.exists(dashboard):
        add_refresh_to_navigations(dashboard)
    else:
        print(f"❌ Arquivo não encontrado: {dashboard}")

print("\n✅ Script concluído!")
