#!/usr/bin/env python3
"""
Script para corregir TODOS los archivos de rutas del backend
"""

import os
import re
from pathlib import Path

# Ruta del backend
BACKEND_PATH = Path("/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppRappiTaxi/backend")

def fix_routes_file(file_path):
    """Corregir archivo de rutas completamente"""
    
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 1. Eliminar validateRequest importado si existe
    content = re.sub(r"import \{ validateRequest \} from '@shared/middleware/validation';", "", content)
    
    # 2. Si no existe la función validateRequest, agregarla
    if 'const validateRequest =' not in content:
        validate_func = """
// Middleware de validación para express-validator
const validateRequest = (req: Request, res: Response, next: NextFunction): void => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    res.status(400).json({
      success: false,
      error: {
        code: 'VALIDATION_ERROR',
        message: 'Datos de entrada inválidos',
        details: errors.array()
      }
    });
    return;
  }
  next();
};
"""
        # Insertar después de los imports
        content = re.sub(r"(const router = Router\(\);)", validate_func + "\n\\1", content)
    
    # 3. Importar validationResult si no está
    if 'validationResult' not in content:
        content = re.sub(
            r"import \{ body, param, query \} from 'express-validator';",
            "import { body, param, query, validationResult } from 'express-validator';",
            content
        )
    
    # 4. Importar Request, Response, NextFunction si no están
    if 'Request, Response' not in content:
        content = re.sub(
            r"(import \{ Router \} from 'express';)",
            "\\1\nimport { Request, Response, NextFunction } from 'express';",
            content
        )
    
    # 5. Corregir authorize con string a array
    content = re.sub(r"authorize\('([^']+)'\)", r"authorize(['\1'])", content)
    
    # 6. Eliminar comas solitarias
    content = re.sub(r"^\s*,\s*$", "", content, flags=re.MULTILINE)
    
    # 7. Corregir validateRequest([...]) con solo los validators antes
    # Buscar validateRequest([...])
    def fix_validate_with_array(match):
        validators = match.group(1)
        # Quitar los corchetes y poner validateRequest al final
        validators_clean = validators.strip()
        if validators_clean:
            return f"{validators_clean},\n  validateRequest"
        return "validateRequest"
    
    content = re.sub(
        r"validateRequest\(\[(.*?)\]\)",
        fix_validate_with_array,
        content,
        flags=re.DOTALL
    )
    
    # 8. Arreglar líneas incompletas con corchetes abiertos
    content = re.sub(r"\.isIn\(\[([^]]+),$", r".isIn([\1])", content, flags=re.MULTILINE)
    content = re.sub(r"\.isIn\(\[([^]]+)\s*,$", r".isIn([\1])", content, flags=re.MULTILINE)
    
    # 9. Eliminar validateRequest duplicados
    content = re.sub(r"(validateRequest,\s*)+validateRequest", "validateRequest", content)
    
    # 10. Guardar archivo corregido
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"✅ Corregido: {file_path.name}")

def main():
    """Función principal"""
    print("🚀 Corrigiendo archivos de rutas...")
    
    # Archivos a corregir
    routes_files = [
        BACKEND_PATH / "src/admin/routes.ts",
        BACKEND_PATH / "src/passengers/routes.ts",
        BACKEND_PATH / "src/drivers/routes.ts",
        BACKEND_PATH / "src/rides/routes.ts",
        BACKEND_PATH / "src/payments/routes.ts",
        BACKEND_PATH / "src/notifications/routes.ts",
        BACKEND_PATH / "src/auth/routes.ts"
    ]
    
    for file_path in routes_files:
        if file_path.exists():
            fix_routes_file(file_path)
    
    print("\n✅ Corrección de rutas completada")

if __name__ == "__main__":
    main()