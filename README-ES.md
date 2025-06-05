# 🌟 Mochok - Sistema de Sincronización AWS S3

> **[🇺🇸 Read in English](README.md)** | Español

Mochok es un sistema modular para sincronizar archivos con AWS S3, diseñado para ser fácil de usar y altamente configurable.

## 🚀 Inicio Rápido

1. **Instalar prerrequisitos**:
   ```powershell
   .\mochok.ps1 install
   ```

2. **Configurar AWS CLI**:
   ```bash
   aws configure
   ```

3. **Configurar sincronización**:
   - Copiar `sync-config.yaml.example` a `sync-config.yaml`
   - Editar con tus rutas, buckets y perfiles

4. **Ejecutar sincronización**:
   ```powershell
   .\mochok.ps1 sync
   ```

## 📋 Comandos

### `sync` - Sincronización Principal
```powershell
.\mochok.ps1 sync
.\mochok.ps1 sync -TargetDate (Get-Date "2025-01-15")
```

### `status` - Estado del Sistema
```powershell
.\mochok.ps1 status
.\mochok.ps1 status -OnlyLastExecution
.\mochok.ps1 status -JsonOutput
```

### `strategies` - Estrategias de Sincronización
```powershell
.\mochok.ps1 strategies
.\mochok.ps1 strategies -ShowExamples
```

### `install` - Instalar Prerrequisitos
```powershell
.\mochok.ps1 install
```

### `"clear logs"` - Limpiar Logs
```powershell
.\mochok.ps1 "clear logs"
.\mochok.ps1 "clear logs" -KeepLastDays 30
.\mochok.ps1 "clear logs" -RemoveDirectory
```

### `help` - Ayuda
```powershell
.\mochok.ps1 help
```

## ⚙️ Configuración

Editar el archivo `sync-config.yaml`:

```yaml
global:
  log_retention_months: 12

sync_configurations:
  - name: "Documentos Diarios"
    description: "Backup diario de documentos"
    enabled: true
    local_base_path: "C:\\MisCarpetas"
    
    sync_strategy:
      type: "DateFolder"
      date_folder_format: "yyyy-MM-dd"
    
    destination_config:
      bucket_name: "mi-bucket-s3"
      aws_profile: "default"
      s3_path_structure: "{year}/{month}/{day}"
    
    sync_options:
      - "--exclude=*.tmp"
```

### Parámetros de Configuración

- **`local_base_path`**: Carpeta base para sincronización
- **`sync_strategy`**: Configuración de estrategia
  - **`type`**: Tipo de estrategia (`DateFolder`, `FullDirectory`, `DateRange`, `CustomPattern`)
  - **`date_folder_format`**: Formato de carpeta de fecha (solo estrategia DateFolder)
  - **`custom_local_pattern`**: Patrón personalizado (solo estrategia CustomPattern)
  - **`date_range_days_back`**: Días hacia atrás (solo estrategia DateRange)
- **`destination_config`**: Configuración de destino AWS S3
  - **`bucket_name`**: Nombre del bucket S3 (se crea automáticamente si no existe)
  - **`aws_profile`**: Perfil AWS a usar
  - **`aws_region`**: Región AWS (opcional, se detecta automáticamente)
  - **`s3_path_structure`**: Estructura de organización S3 usando `{year}`, `{month}`, `{day}`
- **`sync_options`**: Opciones adicionales de AWS CLI

## 🎯 Estrategias de Sincronización

### 1. DateFolder (Predeterminada)
Sincroniza carpeta de día específico con formato de fecha configurable.
```yaml
sync_strategy:
  type: "DateFolder"
  date_folder_format: "yyyy-MM-dd"
```

### 2. FullDirectory
Sincroniza toda la carpeta base.
```yaml
sync_strategy:
  type: "FullDirectory"
```

### 3. DateRange
Sincroniza archivos de un rango de fechas.
```yaml
sync_strategy:
  type: "DateRange"
  date_range_days_back: 7
```

### 4. CustomPattern
Usa patrones personalizados para rutas de sincronización.
```yaml
sync_strategy:
  type: "CustomPattern"
  custom_local_pattern: "{base_path}\\{year}\\{month}"
```

## ⏰ Programación Automática

Para ejecutar automáticamente cada día, usar el Programador de Tareas de Windows:

1. Abrir **Programador de Tareas**
2. Crear nueva tarea básica
3. Configurar:
   - **Programa**: `powershell.exe`
   - **Argumentos**: `-File "C:\ruta\completa\mochok.ps1" sync`
   - **Iniciar en**: `C:\ruta\completa\`

## 📁 Estructura de Archivos

```
├── mochok.ps1                    # Archivo principal de la aplicación
├── sync-config.yaml              # Tu configuración
├── sync-config.yaml.example      # Ejemplos de configuración
├── state.json                    # Estado de sincronización
├── log/                          # Logs automáticos
└── src/                          # Código fuente del sistema
```

## 📋 Logs y Estado

- **Logs**: `log/sync_YYYY-MM.log` (un archivo por mes)
- **Estado**: `state.json` (información de la última ejecución de sincronización)
- **Retención**: Los logs se limpian automáticamente

## 🚨 Solución de Problemas

### Error de Política de Ejecución
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### AWS CLI No Configurado
```bash
aws configure
```

### Verificar Prerrequisitos
```powershell
.\mochok.ps1 install
```
