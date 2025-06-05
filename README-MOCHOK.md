# 🌟 Mochok - Sistema de Sincronización AWS S3

Mochok es un sistema completo y modular para la sincronización de archivos con AWS S3, diseñado para ser fácil de usar y altamente configurable.

## 🚀 Características Principales

- **Arquitectura Modular**: Comandos separados para diferentes funciones
- **Múltiples Estrategias de Sincronización**: DateFolder, FullDirectory, DateRange, CustomPattern
- **Configuración Flexible**: Archivos YAML para configuración
- **Logging Avanzado**: Sistema de logs con rotación automática
- **Manejo de Estado**: Seguimiento detallado de sincronizaciones
- **Interfaz Amigable**: Salidas coloridas y fáciles de leer

## 📋 Comandos Disponibles

### 🔄 `sync` - Sincronización Principal
Ejecuta la sincronización de archivos con AWS S3 según las configuraciones definidas.

```powershell
.\mochok.ps1 sync
.\mochok.ps1 sync -TargetDate (Get-Date "2025-01-15")
```

### 📋 `strategies` - Estrategias de Sincronización
Muestra información sobre las estrategias de sincronización disponibles.

```powershell
.\mochok.ps1 strategies
.\mochok.ps1 strategies -ShowExamples
```

### 📊 `status` - Estado del Sistema
Muestra el estado actual de las sincronizaciones y estadísticas.

```powershell
.\mochok.ps1 status
.\mochok.ps1 status -OnlyLastExecution
.\mochok.ps1 status -JsonOutput
```

### ⚙️ `install` - Instalación de Prerrequisitos
Instala automáticamente los prerrequisitos necesarios para Mochok.

```powershell
.\mochok.ps1 install
```

### 🧹 `"clear logs"` - Limpieza de Logs
Limpia los archivos de log del sistema.

```powershell
.\mochok.ps1 "clear logs"
.\mochok.ps1 "clear logs" -KeepLastDays 7
.\mochok.ps1 "clear logs" -RemoveDirectory
```

### ❓ `help` - Ayuda
Muestra información de ayuda sobre los comandos disponibles.

```powershell
.\mochok.ps1 help
```

## 🏗️ Estructura del Proyecto

```
aws-s3-sync/
├── mochok.ps1                    # Archivo principal de la aplicación
├── sync-config.yaml              # Configuración principal
├── sync-config.yaml.example      # Ejemplo de configuración
├── state.json                    # Estado de sincronizaciones
├── log/                          # Directorio de logs
├── src/
│   ├── commands/                 # Comandos modulares
│   │   ├── sync.ps1             # Comando de sincronización
│   │   ├── strategies.ps1       # Comando de estrategias
│   │   ├── status.ps1           # Comando de estado
│   │   ├── install.ps1          # Comando de instalación
│   │   └── clear-logs.ps1       # Comando de limpieza
│   ├── config.ps1               # Gestión de configuración
│   ├── utils.ps1                # Utilidades generales
│   ├── logging.ps1              # Sistema de logging
│   ├── state-manager.ps1        # Gestión de estado
│   └── sync-service.ps1         # Servicios de sincronización
└── tests/                       # Pruebas del sistema
```

## 🔧 Instalación y Configuración

### 1. Instalación de Prerrequisitos

```powershell
.\mochok.ps1 install
```

Este comando instalará automáticamente:
- Módulo PowerShell-Yaml
- Verificará AWS CLI
- Configurará permisos de ejecución
- Creará archivo de configuración base

### 2. Configuración de AWS CLI

```bash
aws configure
```

### 3. Configuración de Mochok

Edite el archivo `sync-config.yaml` con sus configuraciones específicas:

```yaml
# Configuración de Sincronización Mochok
global:
  log_retention_months: 12
  log_directory: "log"
  state_file: "state.json"

sync_configurations:
- name: "Documentos Diarios"
  description: "Sincronización de documentos diarios"
  enabled: true
  local_base_path: "C:\\Datos\\Documentos"
  bucket_name: "mi-bucket-documentos"
  aws_profile: "default"
  s3_path_structure: "{year}/{month}/{day}"
  date_folder_format: "yyyy-MM-dd"
  sync_options:
  - "--exclude=*.tmp"
  - "--exclude=*.log"
```

## 🎯 Estrategias de Sincronización

### DateFolder (Predeterminada)
Sincroniza carpetas específicas del día con formato de fecha configurable.

### FullDirectory
Sincroniza toda la carpeta base sin importar la estructura.

### DateRange
Sincroniza archivos de un rango de fechas específico.

### CustomPattern
Utiliza patrones personalizados para definir rutas de sincronización.

Para ver ejemplos detallados:
```powershell
.\mochok.ps1 strategies -ShowExamples
```

## 🔍 Monitoreo y Mantenimiento

### Ver Estado Actual
```powershell
.\mochok.ps1 status
```

### Limpiar Logs Antiguos
```powershell
.\mochok.ps1 "clear logs" -KeepLastDays 30
```

### Ejecutar Sincronización
```powershell
.\mochok.ps1 sync
```

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

## 📝 Logs y Estado

- **Logs**: Se almacenan en la carpeta `log/` con rotación automática
- **Estado**: Se mantiene en `state.json` para seguimiento de sincronizaciones
- **Configuración**: `sync-config.yaml` para todas las configuraciones

## 🤝 Migración desde Versión Anterior

Si tenía la versión anterior con `sync-main.ps1`, simplemente:

1. Use `.\mochok.ps1 sync` en lugar de `.\sync-main.ps1`
2. Los otros scripts ahora son comandos: `status`, `strategies`, etc.
3. Todas las configuraciones existentes permanecen igual

## 💡 Ejemplos de Uso

```powershell
# Instalación inicial
.\mochok.ps1 install

# Ver estrategias disponibles
.\mochok.ps1 strategies -ShowExamples

# Ejecutar sincronización
.\mochok.ps1 sync

# Ver estado del sistema
.\mochok.ps1 status

# Limpiar logs antiguos manteniendo los últimos 7 días
.\mochok.ps1 "clear logs" -KeepLastDays 7

# Ver ayuda
.\mochok.ps1 help
```

---

**🌟 Mochok** - Tu sistema de sincronización AWS S3 confiable y fácil de usar. 