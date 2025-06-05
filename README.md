# AWS S3 Sync - Sincronización Multi-Configuración

Sistema automatizado para sincronizar múltiples carpetas diarias con diferentes buckets de AWS S3.

## 🚀 Instalación Rápida

1. **Instalar prerrequisitos**:
   ```powershell
   .\src\install-requirements.ps1
   ```

2. **Configurar AWS CLI**:
   ```bash
   aws configure
   # O configurar múltiples profiles:
   aws configure --profile empresa
   ```

3. **Configurar sincronización**:
   - Copia `sync-config.yaml.example` a `sync-config.yaml`
   - Edita con tus rutas, buckets y profiles

4. **Ejecutar**:
   ```powershell
   .\sync-main.ps1
   ```

## ⚙️ Configuración

Edita el archivo `sync-config.yaml`:

```yaml
# Configuración global
global:
  log_retention_months: 12

# Configuraciones de sincronización
sync_configurations:
  - name: "Mi Backup"
    description: "Backup diario de documentos"
    enabled: true
    local_base_path: "C:\\MisCarpetas"
    bucket_name: "mi-bucket-s3"
    aws_profile: "default"  # Profile de AWS a usar
    s3_path_structure: "{year}/{month}/{day}"
    date_folder_format: "yyyy-MM-dd"
    sync_options:
      - "--exclude=*.tmp"
```

### Parámetros principales:
- **`local_base_path`**: Carpeta donde están tus carpetas diarias (ej: `C:\Documentos`)
- **`bucket_name`**: Nombre del bucket S3 (sin `s3://`)
- **`aws_profile`**: Profile de AWS a usar (`"default"` o nombre específico)
- **`s3_path_structure`**: Cómo organizar en S3. Usa `{year}`, `{month}`, `{day}`
- **`date_folder_format`**: Formato de tus carpetas de fecha local
- **`sync_options`**: Opciones adicionales de AWS CLI (excluir archivos, etc.)

## 🔄 Uso

```powershell
# Sincronizar día anterior (por defecto)
.\sync-main.ps1

# Sincronizar fecha específica
.\sync-main.ps1 -TargetDate (Get-Date "2024-12-15")
```

## ⏰ Programación Automática

Para ejecutar automáticamente cada día:

1. Abrir **Programador de Tareas de Windows**
2. Crear nueva tarea básica
3. Configurar:
   - **Programa**: `powershell.exe`
   - **Argumentos**: `-File "C:\ruta\completa\sync-main.ps1"`
   - **Directorio**: `C:\ruta\completa\`

## 📁 Estructura de Archivos

```
├── sync-main.ps1          # Script principal
├── sync-config.yaml       # Tu configuración
├── sync-config.yaml.example # Ejemplos de configuración
├── src/                   # Código del sistema
│   ├── config.ps1         #   Manejo de configuración
│   ├── utils.ps1          #   Utilidades y AWS S3
│   ├── logging.ps1        #   Sistema de logging
│   ├── state-manager.ps1  #   Manejo de estado
│   └── sync-service.ps1   #   Servicios de sincronización
├── log/                   # Logs automáticos
└── state.json             # Estado de sincronizaciones
```

## 📋 Logs y Estado

- **Logs**: `log/sync_YYYY-MM.log` (un archivo por mes)
- **Estado**: `state.json` (historial de ejecuciones)
- **Rotación**: Los logs se limpian automáticamente

## ❓ Problemas Comunes

**Error de ejecución de scripts**:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**AWS CLI no encontrado**:
Instalar desde: https://aws.amazon.com/cli/

---

📖 **Documentación detallada**: Ver `src/README.md` 