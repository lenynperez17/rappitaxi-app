#!/usr/bin/env python3
"""
Script para restaurar y corregir los archivos de rutas corruptos
"""

import re
import os

def fix_route_file(filepath):
    """Corrige un archivo de rutas corrupto"""
    
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Guardar backup
    backup_path = filepath + '.backup'
    if not os.path.exists(backup_path):
        with open(backup_path, 'w', encoding='utf-8') as f:
            f.write(content)
    
    lines = content.split('\n')
    fixed_lines = []
    i = 0
    
    while i < len(lines):
        line = lines[i]
        
        # Detectar patrones corruptos donde validateRequest está mal posicionado
        if 'validateRequest])' in line and 'validateRequest([' not in line:
            # Este es un cierre corrupto, necesitamos arreglarlo
            # Buscar hacia atrás para encontrar el inicio del array
            j = i - 1
            validation_lines = []
            
            # Recolectar líneas de validación hacia atrás
            while j >= 0:
                prev_line = lines[j]
                validation_lines.insert(0, prev_line.strip())
                if 'router.' in prev_line or '...adminOnly' in prev_line:
                    break
                j -= 1
            
            # Buscar hacia adelante para encontrar el handler
            k = i + 1
            handler_found = False
            handler_line = None
            extra_lines = []
            
            while k < len(lines) and k < i + 5:
                next_line = lines[k].strip()
                if next_line and not next_line.startswith(']') and not next_line.startswith(')'):
                    # Buscar si hay más validadores mal posicionados
                    if 'query(' in next_line or 'body(' in next_line or 'param(' in next_line:
                        extra_lines.append(next_line.rstrip(')]').rstrip('])'))
                        k += 1
                    elif 'Controller.' in next_line:
                        handler_found = True
                        handler_line = next_line
                        break
                    else:
                        break
                k += 1
            
            # Reconstruir la ruta correctamente
            if handler_found and j >= 0:
                # Mantener las líneas hasta el router
                for idx in range(j):
                    fixed_lines.append(lines[idx])
                
                # Construir la llamada al router correctamente
                router_line = lines[j]
                fixed_lines.append(router_line)
                
                # Agregar ...adminOnly si existe
                if '...adminOnly' in content[lines[j]:lines[i+k]]:
                    fixed_lines.append('  ...adminOnly,')
                
                # Construir el array de validadores
                validators = []
                for val_line in validation_lines:
                    val_line = val_line.strip()
                    if 'query(' in val_line or 'body(' in val_line or 'param(' in val_line:
                        # Limpiar la línea de caracteres corruptos
                        val_line = val_line.rstrip(',').rstrip(']').rstrip(')')
                        if not val_line.endswith(')'):
                            val_line += ')'
                        validators.append(val_line)
                
                # Agregar validadores extra encontrados
                for extra in extra_lines:
                    extra = extra.strip().rstrip(',').rstrip(']').rstrip(')')
                    if not extra.endswith(')'):
                        extra += ')'
                    validators.append(extra)
                
                # Escribir los validadores
                if validators:
                    fixed_lines.append('  validateRequest([')
                    for val in validators:
                        fixed_lines.append(f'    {val},')
                    fixed_lines.append('  ]),')
                
                # Agregar el handler
                fixed_lines.append(f'  {handler_line}')
                fixed_lines.append(');')
                
                # Saltar las líneas procesadas
                i = k + 1
                continue
        
        # Para líneas normales, solo agregarlas
        fixed_lines.append(line)
        i += 1
    
    # Post-procesamiento para limpiar patrones comunes de corrupción
    content = '\n'.join(fixed_lines)
    
    # Limpiar patrones corruptos específicos
    content = re.sub(r',\s*validateRequest\]\)', ']),', content)
    content = re.sub(r'validateRequest\]\)\s*([a-zA-Z]+)', r']), \1', content)
    content = re.sub(r'\]\)\s*\]\)', '])', content)
    content = re.sub(r'\)\s*\]\)\s*\],', ')]),', content)
    
    # Arreglar las declaraciones de rutas que quedaron mal
    content = re.sub(
        r"router\.(get|post|put|patch|delete)\((.*?)\n\s*\.\.\.(adminOnly|superAdminOnly),\n\s*\n\s*(query|body|param)",
        r"router.\1(\2\n  ...\3,\n  validateRequest([\n    \4",
        content,
        flags=re.MULTILINE | re.DOTALL
    )
    
    # Escribir el contenido corregido
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    
    return filepath

def main():
    """Función principal"""
    
    base_dir = '/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppRappiTaxi/backend/src'
    
    # Archivos de rutas a corregir
    route_files = [
        os.path.join(base_dir, 'admin/routes.ts'),
        os.path.join(base_dir, 'passengers/routes.ts'),
        os.path.join(base_dir, 'drivers/routes.ts'),
        os.path.join(base_dir, 'shared/routes.ts')
    ]
    
    print("🔧 Corrigiendo archivos de rutas corruptos...")
    
    for filepath in route_files:
        if os.path.exists(filepath):
            print(f"  📝 Corrigiendo {os.path.basename(os.path.dirname(filepath))}/routes.ts...")
            fix_route_file(filepath)
    
    print("\n✅ Archivos de rutas corregidos")
    
    # Ahora intentar una corrección manual más precisa para admin/routes.ts
    admin_routes = os.path.join(base_dir, 'admin/routes.ts')
    if os.path.exists(admin_routes):
        print("\n🔧 Aplicando corrección manual específica a admin/routes.ts...")
        
        with open(admin_routes, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Correcciones específicas para patrones conocidos
        fixes = [
            # Línea 64-67
            (r"query\('period'\)\.optional\(\)\.isIn\(\['today', 'week', 'month', 'quarter', 'year',\s*validateRequest\]\)\s*query\('timezone'\)\.optional\(\)\.isString\(\)\]\)",
             "validateRequest([\n    query('period').optional().isIn(['today', 'week', 'month', 'quarter', 'year']),\n    query('timezone').optional().isString()\n  ])"),
            
            # Línea 83-85
            (r"query\('severity'\)\.optional\(\)\.isIn\(\['info', 'warning', 'error', 'critical',\s*validateRequest\]\)\s*query\('resolved'\)\.optional\(\)\.isBoolean\(\)\]\)",
             "validateRequest([\n    query('severity').optional().isIn(['info', 'warning', 'error', 'critical']),\n    query('resolved').optional().isBoolean()\n  ])"),
            
            # Patrón general para validateRequest mal formateado
            (r"validateRequest\]\)",
             "]),"),
             
            # Limpiar líneas vacías de más
            (r"\n\s*\n\s*\n", "\n\n"),
        ]
        
        for pattern, replacement in fixes:
            content = re.sub(pattern, replacement, content, flags=re.MULTILINE | re.DOTALL)
        
        with open(admin_routes, 'w', encoding='utf-8') as f:
            f.write(content)
        
        print("✅ Corrección manual aplicada")

if __name__ == '__main__':
    main()