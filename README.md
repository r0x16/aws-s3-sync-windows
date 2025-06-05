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
- **`bucket_name`**: Nombre del bucket S3 (sin `s3://`) - **Se crea automáticamente si no existe**
- **`aws_profile`**: Profile de AWS a usar (`"default"` o nombre específico)
- **`aws_region`**: Región AWS donde crear el bucket (opcional, se detecta automáticamente)
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

## ☁️ Creación Automática de Buckets S3

**¡Nueva funcionalidad!** El sistema ahora verifica automáticamente si los buckets S3 existen y los crea si es necesario.

### Características:
- **Verificación automática**: Antes de cada sincronización, se verifica si el bucket existe
- **Creación inteligente**: Si no existe, se crea usando el profile y región configurados
- **Configuraciones de seguridad**: Los buckets se crean con:
  - ✅ Versionado habilitado
  - ✅ Cifrado AES256 por defecto
  - ✅ Configuración de región apropiada

### Configuración de región:
```yaml
sync_configurations:
  - name: "Mi Backup"
    bucket_name: "mi-nuevo-bucket"
    aws_profile: "mi-profile"
    aws_region: "us-west-2"  # Opcional: especifica la región
    # ... otros parámetros
```

Si no se especifica `aws_region`, el sistema:
1. Intentará detectar la región del profile AWS configurado
2. Usará `us-east-1` como región por defecto

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
- **Estado**: `state.json` (información de la última copia realizada)
- **Rotación**: Los logs se limpian automáticamente

### 📊 Nuevo Sistema de Estado

El archivo `state.json` ahora registra información **detallada de la última copia realizada**:

```json
{
  "lastExecution": {
    "timestamp": "2025-01-20T10:00:00Z",
    "success": true,
    "totalConfigurations": 3,
    "successfulConfigurations": 2,
    "failedConfigurations": 1,
    "targetDate": "2025-01-19",
    "duration": "00:05:23"
  },
  "configurationResults": {
    "Documentos": {
      "lastStatus": "Success",
      "lastMessage": "Sincronización completada. Archivos transferidos: 15",
      "lastTimestamp": "2025-01-20T10:02:15Z",
      "localPath": "C:\\Datos\\2025-01-19",
      "s3Path": "s3://mi-bucket/2025/01/19",
      "filesTransferred": 15,
      "duration": "00:02:30"
    }
  },
  "lastSuccessfulSync": {
    "Documentos": {
      "timestamp": "2025-01-20T10:02:15Z",
      "date": "2025-01-19",
      "filesTransferred": 15
    }
  }
}
```

### 📈 Comando de Estado

```powershell
# Ver reporte completo del estado
.\show-status.ps1

# Ver solo última ejecución
.\show-status.ps1 -OnlyLastExecution

# Salida en formato JSON
.\show-status.ps1 -JsonOutput
```

## ❓ Problemas Comunes

**Error de ejecución de scripts**:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**AWS CLI no encontrado**:
Instalar desde: https://aws.amazon.com/cli/

---

📖 **Documentación detallada**: Ver `src/README.md` 