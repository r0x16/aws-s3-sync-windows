# Mochok - Documentación Técnica

[🇺🇸 English Version](README.md)

## Tabla de Contenidos

1. [Resumen del Proyecto](#resumen-del-proyecto)
2. [Arquitectura del Sistema](#arquitectura-del-sistema)
3. [Estructura del Proyecto](#estructura-del-proyecto)
4. [Componentes Principales](#componentes-principales)
5. [Estrategias de Sincronización](#estrategias-de-sincronización)
6. [Sistema de Configuración](#sistema-de-configuración)
7. [Gestión de Estado](#gestión-de-estado)
8. [Sistema de Comandos](#sistema-de-comandos)
9. [Guías de Desarrollo](#guías-de-desarrollo)
10. [Detalles de Implementación Técnica](#detalles-de-implementación-técnica)

---

## Resumen del Proyecto

**Mochok** es un sistema completo de sincronización con AWS S3 basado en PowerShell, diseñado para entornos empresariales. Proporciona un framework modular, configurable y extensible para automatizar tareas de sincronización de archivos entre directorios locales y buckets de AWS S3.

### Características Principales
- **Soporte multi-configuración**: Ejecuta múltiples tareas de sincronización en secuencia
- **Estrategias flexibles**: Diferentes patrones de sincronización (DateFolder, FullDirectory, DateRange, CustomPattern)
- **Persistencia de estado**: Seguimiento y reporte comprehensivo de ejecuciones
- **Logging empresarial**: Logging estructurado con limpieza automática
- **Interfaz de línea de comandos**: CLI intuitiva con múltiples comandos
- **Manejo de errores**: Detección y reporte robusto de errores
- **Integración AWS**: Integración completa con AWS CLI y soporte de perfiles

### Stack Tecnológico
- **Lenguaje**: PowerShell 5.1+
- **Proveedor de Nube**: AWS S3
- **Configuración**: YAML
- **Almacenamiento de Estado**: JSON
- **Dependencias**: AWS CLI, módulo powershell-yaml

---

## Arquitectura del Sistema

### Arquitectura de Alto Nivel

```
┌─────────────────────────────────────────────────────────────┐
│                       Sistema Mochok                       │
├─────────────────────────────────────────────────────────────┤
│  Punto de Entrada: mochok.ps1                             │
│  ├── Enrutador de Comandos                                │
│  └── Validación de Parámetros                             │
├─────────────────────────────────────────────────────────────┤
│  Capa de Comandos (src/commands/)                         │
│  ├── sync.ps1         - Sincronización principal         │
│  ├── status.ps1       - Reporte de estado del sistema    │
│  ├── strategies.ps1   - Documentación de estrategias     │
│  ├── install.ps1      - Instalación de prerrequisitos    │
│  └── clear-logs.ps1   - Limpieza de logs                 │
├─────────────────────────────────────────────────────────────┤
│  Capa de Servicios Principales (src/)                     │
│  ├── sync-service.ps1 - Orquestación de sincronización   │
│  ├── config.ps1       - Gestión de configuración         │
│  ├── state-manager.ps1- Persistencia de estado          │
│  ├── utils.ps1        - Funciones utilitarias           │
│  └── logging.ps1      - Sistema de logging               │
├─────────────────────────────────────────────────────────────┤
│  Dependencias Externas                                    │
│  ├── AWS CLI          - Operaciones S3                   │
│  ├── powershell-yaml  - Parsing YAML                     │
│  └── Sistema de Archivos - Operaciones de archivos locales │
└─────────────────────────────────────────────────────────────┘
```

### Flujo de Datos

1. **Carga de Configuración**: Se parsea y valida la configuración YAML
2. **Resolución de Estrategia**: Cada configuración de sync se mapea a su estrategia
3. **Cálculo de Rutas**: Se calculan las rutas locales y S3 basadas en la estrategia
4. **Ejecución**: Las tareas de sincronización se ejecutan secuencialmente
5. **Persistencia de Estado**: Los resultados se registran en state.json
6. **Logging**: Todas las operaciones se registran con salida estructurada

---

## Estructura del Proyecto

```
aws-s3-sync/
├── 📄 mochok.ps1                    # Punto de entrada principal y enrutador de comandos
├── 📄 sync-config.yaml              # Archivo de configuración activo
├── 📄 sync-config.yaml.example      # Ejemplos comprehensivos de configuración
├── 📄 state.json                    # Persistencia del estado de ejecución
├── 📄 .gitignore                    # Reglas de ignore de Git
├── 📄 README.md                     # Documentación de usuario
├── 📄 README-ES.md                  # Documentación de usuario en español
├── 📁 src/                          # Directorio de código fuente
│   ├── 📄 README.md                 # Documentación técnica (versión inglés)
│   ├── 📄 README-ES.md              # Documentación técnica (este archivo)
│   ├── 📄 sync-service.ps1          # Servicio principal de sincronización
│   ├── 📄 config.ps1                # Gestión de configuración
│   ├── 📄 utils.ps1                 # Funciones utilitarias y estrategias
│   ├── 📄 state-manager.ps1         # Gestión de persistencia de estado
│   ├── 📄 logging.ps1               # Sistema de logging
│   ├── 📄 log-cleaner.ps1           # Funcionalidad de limpieza de logs
│   └── 📁 commands/                 # Implementación de comandos CLI
│       ├── 📄 sync.ps1              # Comando principal de sync
│       ├── 📄 status.ps1            # Comando de reporte de estado
│       ├── 📄 strategies.ps1        # Comando de información de estrategias
│       ├── 📄 install.ps1           # Comando de instalación
│       └── 📄 clear-logs.ps1        # Comando de limpieza de logs
├── 📁 log/                          # Directorio de archivos de log
│   └── 📄 sync_YYYY-MM.log          # Archivos de log mensuales
└── 📁 tests/                        # Directorio de archivos de prueba
    ├── 📄 README.md                 # Documentación de testing
    └── 📄 Get-SyncPaths.tests.ps1   # Pruebas unitarias para funciones de ruta
```

---

## Componentes Principales

### 1. Punto de Entrada Principal (`mochok.ps1`)

**Propósito**: Enrutador de comandos y validación de parámetros
**Características Principales**:
- Normalización y validación de comandos
- Paso de parámetros a módulos de comando apropiados
- Sistema de ayuda unificado y manejo de errores
- Branding visual y experiencia de usuario

**Patrón de Arquitectura**: Patrón Command con implementación de enrutador

```powershell
# Patrón de ejecución de comandos
switch ($normalizedCommand) {
    "sync" { & (Join-Path $PSScriptRoot "src\commands\sync.ps1") -TargetDate $TargetDate }
    "status" { & (Join-Path $PSScriptRoot "src\commands\status.ps1") @statusParams }
    # ... otros comandos
}
```

### 2. Sistema de Configuración (`src/config.ps1`)

**Propósito**: Gestión de configuración basada en YAML
**Componentes Principales**:
- Clase `SyncConfiguration` para estado de configuración
- Parsing YAML con integración `powershell-yaml`
- Validación de configuración y valores por defecto
- Carga de configuración específica del entorno

**Estructura de Configuración**:
```yaml
global:
  log_retention_months: 12
  log_directory: "log"
  state_file: "state.json"

sync_configurations:
- name: "Nombre de Configuración"
  description: "Descripción"
  enabled: true|false
  local_base_path: "C:\\Ruta\\Al\\Origen"
  sync_strategy:
    type: "DateFolder|FullDirectory|DateRange|CustomPattern"
    # Opciones específicas de estrategia
  destination_config:
    bucket_name: "nombre-bucket-s3"
    aws_profile: "nombre-perfil-aws"
    aws_region: "región-aws"
    s3_path_structure: "estructura/ruta/{placeholders}"
  sync_options:
    - "--opción1"
    - "--opción2"
```

### 3. Servicio de Sincronización (`src/sync-service.ps1`)

**Propósito**: Orquestación principal de sincronización
**Funciones Principales**:

#### `Start-SyncProcess`
- Ejecuta sincronización para una configuración única
- Maneja validación de rutas, verificación de AWS CLI
- Gestiona creación/verificación de buckets S3
- Realiza conteo de archivos y ejecución de transferencia
- Registra resultados de ejecución y métricas

#### `Start-AllSyncProcesses`
- Orquesta ejecuciones de múltiples configuraciones
- Proporciona seguimiento de progreso y reporte de resumen
- Maneja acumulación de errores y determinación de estado final
- Se integra con gestión de estado para persistencia

**Estrategia de Manejo de Errores**:
- Degradación elegante: configuraciones fallidas no detienen la ejecución
- Logging detallado de errores con contexto
- Categorización de estado: Success, Failure, Skipped

### 4. Gestión de Estado (`src/state-manager.ps1`)

**Propósito**: Persistencia y seguimiento del estado de ejecución
**Estructura de Estado**:

```json
{
  "lastExecution": {
    "timestamp": "ISO8601",
    "success": boolean,
    "totalConfigurations": number,
    "successfulConfigurations": number,
    "failedConfigurations": number,
    "targetDate": "YYYY-MM-DD",
    "duration": "HH:MM:SS"
  },
  "configurationResults": {
    "NombreConfig": {
      "lastStatus": "Success|Failure|Skipped",
      "lastMessage": "Mensaje detallado",
      "lastTimestamp": "ISO8601",
      "lastDate": "YYYY-MM-DD",
      "localPath": "ruta/completa",
      "s3Path": "s3://bucket/ruta",
      "filesTransferred": number,
      "duration": "HH:MM:SS",
      "consecutiveFailures": number
    }
  },
  "lastSuccessfulSync": {
    "NombreConfig": {
      "timestamp": "ISO8601",
      "date": "YYYY-MM-DD",
      "localPath": "ruta/completa",
      "s3Path": "s3://bucket/ruta",
      "message": "Mensaje de éxito",
      "filesTransferred": number,
      "duration": "HH:MM:SS"
    }
  },
  "statistics": {
    "totalExecutions": number,
    "lastSuccessDate": "ISO8601",
    "consecutiveFailures": number
  }
}
```

**Funciones Principales**:
- `Get-State`: Cargar y validar estructura de estado
- `Set-State`: Persistir estado con manejo de errores
- `Start-StateExecution`: Inicializar seguimiento de ejecución
- `Complete-StateExecution`: Finalizar métricas de ejecución
- `Set-ConfigurationResult`: Registrar resultados de configuración individual

### 5. Funciones Utilitarias (`src/utils.ps1`)

**Propósito**: Implementaciones de estrategia y funciones auxiliares
**Funciones Principales de Estrategia**:

#### Estrategias de Resolución de Rutas
- `Get-SyncPaths`: Despachador de estrategia basado en configuración
- `Get-DateFolderSyncPaths`: Sincronización de carpetas basada en fechas
- `Get-FullDirectorySyncPaths`: Sincronización completa de directorio
- `Get-DateRangeSyncPaths`: Sincronización basada en rango de fechas
- `Get-CustomPatternSyncPaths`: Sincronización de patrón personalizado

#### Funciones de Integración AWS
- `Test-AwsCli`: Verificación de disponibilidad de AWS CLI
- `Confirm-S3Bucket`: Verificación y creación de existencia de bucket
- `Invoke-S3Sync`: Ejecución de AWS S3 sync con manejo de errores

#### Utilidades del Sistema
- `Test-AndCreateFolder`: Creación de directorio con manejo de errores
- `Test-SystemPrerequisites`: Validación de requisitos del sistema
- `Format-FileSize`: Formateo de tamaño de archivo legible para humanos

### 6. Sistema de Logging (`src/logging.ps1`)

**Propósito**: Logging estructurado con gestión automática
**Características**:
- Rotación mensual de archivos de log
- Entradas con timestamp y niveles de severidad
- Coordinación de salida de consola y archivo
- Limpieza automática de logs basada en política de retención

**Estructura de Log**:
```
[2025-01-15 14:30:25] [INFO] === Iniciando proceso de sync AWS S3 ===
[2025-01-15 14:30:26] [INFO] [NombreConfig] Procesando configuración
[2025-01-15 14:30:27] [ERROR] [NombreConfig] AWS CLI no encontrado
```

---

## Estrategias de Sincronización

### 1. Estrategia DateFolder
**Caso de Uso**: Directorios organizados diariamente (ej., `2025-01-15/`)
**Patrón de Ruta**: `{base_path}\{formato_fecha}` → `s3://bucket/{estructura}`
**Configuración**:
```yaml
sync_strategy:
  type: "DateFolder"
  date_folder_format: "yyyy-MM-dd"  # Formato de fecha configurable
```

**Implementación**: `Get-DateFolderSyncPaths` en `utils.ps1`

### 2. Estrategia FullDirectory
**Caso de Uso**: Backups completos de directorio
**Patrón de Ruta**: `{base_path}` (directorio completo) → `s3://bucket/{estructura}`
**Configuración**:
```yaml
sync_strategy:
  type: "FullDirectory"
```

**Implementación**: `Get-FullDirectorySyncPaths` en `utils.ps1`

### 3. Estrategia DateRange
**Caso de Uso**: Archivos dentro de un rango de fechas (ej., últimos 7 días)
**Patrón de Ruta**: `{base_path}` con filtrado por fecha → `s3://bucket/{estructura}`
**Configuración**:
```yaml
sync_strategy:
  type: "DateRange"
  date_range_days_back: 7  # Días hacia atrás
```

**Implementación**: `Get-DateRangeSyncPaths` en `utils.ps1`

### 4. Estrategia CustomPattern
**Caso de Uso**: Patrones de directorio personalizados con placeholders
**Patrón de Ruta**: Definido por usuario con `{base_path}`, `{year}`, `{month}`, `{day}`
**Configuración**:
```yaml
sync_strategy:
  type: "CustomPattern"
  custom_local_pattern: "{base_path}\\{year}\\{month}"
```

**Implementación**: `Get-CustomPatternSyncPaths` en `utils.ps1`

---

## Sistema de Configuración

### Proceso de Carga de Configuración

1. **Ubicación de Archivo**: `sync-config.yaml` en la raíz del proyecto
2. **Importación de Módulo**: Instalación automática de `powershell-yaml` si falta
3. **Validación de Estructura**: Validación de esquema con valores por defecto
4. **Cacheo de Configuración**: Patrón singleton para rendimiento

### Estructura de Clase de Configuración

```powershell
class SyncConfiguration {
    [string]$ConfigFile     # Ruta a configuración YAML
    [int]$LogRetentionMonths # Período de retención de logs
    [string]$LogDir         # Ruta del directorio de logs
    [string]$StateFile      # Ruta del archivo de estado
    [array]$SyncConfigurations # Array de configuraciones habilitadas
}
```

### Opciones de Configuración Global

| Opción | Tipo | Por Defecto | Descripción |
|--------|------|-------------|-------------|
| `log_retention_months` | int | 12 | Meses para retener archivos de log |
| `log_directory` | string | "log" | Ruta relativa al directorio de logs |
| `state_file` | string | "state.json" | Ruta relativa al archivo de estado |

### Esquema de Configuración de Sync

| Sección | Requerido | Tipo | Descripción |
|---------|-----------|------|-------------|
| `name` | ✅ | string | Identificador único de configuración |
| `description` | ✅ | string | Descripción legible para humanos |
| `enabled` | ✅ | boolean | Si ejecutar esta configuración |
| `local_base_path` | ✅ | string | Ruta del directorio fuente |
| `sync_strategy` | ✅ | object | Configuración de estrategia |
| `destination_config` | ✅ | object | Configuraciones de destino AWS S3 |
| `sync_options` | ❌ | array | Opciones adicionales de AWS CLI |

---

## Gestión de Estado

### Arquitectura del Archivo de Estado

El sistema de gestión de estado usa un archivo JSON para persistir información de ejecución entre ejecuciones. Esto habilita:

- **Seguimiento histórico**: Historial completo de ejecuciones
- **Capacidad de reanudación**: Entendimiento de últimas operaciones exitosas
- **Seguimiento de errores**: Conteo de fallos consecutivos
- **Métricas de rendimiento**: Estadísticas de duración y transferencia

### Proceso de Inicialización de Estado

1. **Verificación de Existencia de Archivo**: Verificar que `state.json` existe
2. **Validación de Estructura**: Asegurar que todas las secciones requeridas existen
3. **Migración de Esquema**: Agregar campos faltantes para compatibilidad hacia atrás
4. **Valores por Defecto**: Inicializar estado vacío si el archivo falta/está corrupto

### Ciclo de Vida de Actualización de Estado

1. **Inicio de Ejecución**: `Start-StateExecution` inicializa la ejecución actual
2. **Procesamiento de Configuración**: `Set-ConfigurationResult` registra resultados individuales
3. **Finalización de Ejecución**: `Complete-StateExecution` finaliza métricas de ejecución
4. **Persistencia**: `Set-State` escribe estado actualizado al disco

---

## Sistema de Comandos

### Arquitectura de Comandos

El sistema de comandos sigue una arquitectura modular donde cada comando se implementa como un script PowerShell separado en `src/commands/`. Este diseño habilita:

- **Separación de responsabilidades**: Cada comando maneja funcionalidad específica
- **Aislamiento de parámetros**: Parámetros específicos del comando y validación
- **Testing independiente**: Cada comando puede ser probado por separado
- **Extensibilidad**: Nuevos comandos pueden ser agregados fácilmente

### Comandos Disponibles

#### 1. Comando `sync` (`src/commands/sync.ps1`)
**Propósito**: Ejecutar proceso principal de sincronización
**Parámetros**:
- `TargetDate`: Fecha a sincronizar (por defecto: ayer)

**Flujo de Trabajo**:
1. Cargar y validar configuración
2. Mostrar resumen de configuración
3. Verificar prerrequisitos del sistema
4. Ejecutar todas las configuraciones de sincronización habilitadas
5. Reportar resultados finales

#### 2. Comando `status` (`src/commands/status.ps1`)
**Propósito**: Mostrar estado comprehensivo del sistema
**Parámetros**:
- `OnlyLastExecution`: Mostrar solo información de la última ejecución
- `JsonOutput`: Salida en formato JSON para automatización

**Secciones de Salida**:
- Resumen de última ejecución
- Estadísticas generales
- Detalles por configuración
- Últimas sincronizaciones exitosas

#### 3. Comando `strategies` (`src/commands/strategies.ps1`)
**Propósito**: Mostrar estrategias de sincronización disponibles
**Parámetros**:
- `ShowExamples`: Incluir ejemplos detallados de configuración

**Información Proporcionada**:
- Descripciones de estrategias y casos de uso
- Sintaxis de configuración
- Explicaciones de placeholders
- Ejemplos del mundo real

#### 4. Comando `install` (`src/commands/install.ps1`)
**Propósito**: Instalar prerrequisitos del sistema
**Características**:
- Verificación de instalación de AWS CLI
- Gestión de dependencias de módulos PowerShell
- Verificación de capacidades del sistema
- Guía de configuración

#### 5. Comando `clear-logs` (`src/commands/clear-logs.ps1`)
**Propósito**: Limpiar archivos de log basado en política de retención
**Parámetros**:
- `RemoveDirectory`: También remover directorio de logs si está vacío
- `KeepLastDays`: Sobrescribir política de retención para logs recientes

---

## Guías de Desarrollo

### Principios de Organización de Código

1. **Diseño Modular**: Cada archivo tiene una responsabilidad específica
2. **Nomenclatura de Funciones**: Patrón Verbo-Sustantivo siguiendo convenciones PowerShell
3. **Manejo de Errores**: Manejo consistente de errores con logging
4. **Documentación**: Documentación inline comprehensiva y ejemplos

### Mejores Prácticas de PowerShell

#### Estructura de Función
```powershell
function Verbo-Sustantivo {
    <#
    .SYNOPSIS
        Descripción breve
    .DESCRIPTION
        Descripción detallada
    .PARAMETER NombreParametro
        Descripción del parámetro
    .EXAMPLE
        Ejemplo de uso
    #>
    param(
        [Parameter(Mandatory)]
        [Tipo] $ParametroRequerido,
        
        [Tipo] $ParametroOpcional = "ValorPorDefecto"
    )
    
    try {
        # Implementación
        Write-Log -Message "Detalles de ejecución de función"
        return $resultado
    }
    catch {
        Write-Log -Message "Detalles de error: $_" -Level "ERROR"
        throw
    }
}
```

#### Patrón de Manejo de Errores
```powershell
# Manejo elegante de errores con logging
try {
    $resultado = Invoke-Operation
    Write-Log -Message "Operación exitosa"
    return @{ Success = $true; Data = $resultado }
}
catch {
    $errorMsg = "Operación falló: $_"
    Write-Log -Message $errorMsg -Level "ERROR"
    return @{ Success = $false; Message = $errorMsg }
}
```

### Agregando Nuevas Estrategias de Sincronización

1. **Implementar Función de Estrategia**:
   ```powershell
   function Get-EstrategiaPersonalizadaSyncPaths {
       param([datetime] $Date, [PSCustomObject] $SyncConfig)
       # Implementación de estrategia
       return @{
           LocalPath = $rutaLocal
           S3Path = $rutaS3
           DayFolder = $carpetaDia
           ConfigName = $SyncConfig.name
           StrategyType = "EstrategiaPersonalizada"
       }
   }
   ```

2. **Agregar al Despachador de Estrategia**:
   ```powershell
   # En función Get-SyncPaths
   "EstrategiaPersonalizada" {
       return Get-EstrategiaPersonalizadaSyncPaths -Date $Date -SyncConfig $SyncConfig
   }
   ```

3. **Actualizar Documentación**:
   - Agregar descripción de estrategia a `src/commands/strategies.ps1`
   - Incluir ejemplos en `sync-config.yaml.example`
   - Actualizar esta documentación técnica

### Agregando Nuevos Comandos

1. **Crear Archivo de Comando**: `src/commands/nuevo-comando.ps1`
2. **Implementar Lógica de Comando**: Seguir patrones de comandos existentes
3. **Agregar al Enrutador**: Actualizar switch statement en `mochok.ps1`
4. **Agregar Ayuda**: Incluir comando en sistema de ayuda
5. **Actualizar Documentación**: Agregar a archivos README

### Guías de Testing

- **Pruebas Unitarias**: Crear pruebas en directorio `tests/`
- **Pruebas de Integración**: Probar flujos de trabajo completos
- **Escenarios de Error**: Probar condiciones de fallo
- **Pruebas de Rendimiento**: Verificar rendimiento con datasets grandes

---

## Detalles de Implementación Técnica

### Integración con AWS CLI

El sistema se integra con AWS CLI para operaciones S3, proporcionando:

- **Soporte de Perfiles**: Múltiples perfiles AWS para diferentes entornos
- **Gestión de Regiones**: Detección automática de región y creación de buckets
- **Manejo de Errores**: Parsing comprehensivo de errores de AWS CLI
- **Paso de Opciones**: Soporte directo de opciones de AWS CLI

#### Ejecución de S3 Sync
```powershell
function Invoke-S3Sync {
    param($LocalPath, $S3Path, $SyncOptions, $AwsProfile)
    
    # Construir comando AWS CLI
    $awsCommand = @("aws", "s3", "sync", $LocalPath, $S3Path)
    if ($AwsProfile -ne "default") {
        $awsCommand += @("--profile", $AwsProfile)
    }
    $awsCommand += $SyncOptions
    
    # Ejecutar con manejo comprehensivo de errores
    $process = Start-Process -FilePath "aws" -ArgumentList $awsCommand
    # Procesar salida y retornar resultado estructurado
}
```

### Procesamiento de Configuración YAML

El procesamiento de configuración involucra:

1. **Detección de Módulo**: Instalación automática de `powershell-yaml`
2. **Parsing YAML**: Convertir YAML a objetos PowerShell
3. **Validación de Esquema**: Asegurar que campos requeridos existen
4. **Aplicación de Defaults**: Aplicar valores por defecto para campos opcionales

### Optimización de Rendimiento

#### Optimización de Conteo de Archivos
```powershell
# Conteo optimizado de archivos con manejo de errores
try {
    $conteoArchivos = (Get-ChildItem -LiteralPath $ruta -File -Recurse -ErrorAction SilentlyContinue | Measure-Object).Count
}
catch {
    Write-Log -Message "No se pudo contar archivos: $_" -Level "WARNING"
    $conteoArchivos = 0
}
```

#### Consideraciones de Procesamiento Paralelo
- Actualmente secuencial por simplicidad y manejo de errores
- Mejora futura: procesamiento paralelo de configuraciones
- Gestión de estado diseñada para acceso concurrente

### Consideraciones de Seguridad

1. **Gestión de Credenciales**: Se basa en la cadena de credenciales de AWS CLI
2. **Validación de Rutas**: Previene ataques de traversal de directorio
3. **Información de Error**: Mensajes de error sanitizados en logs
4. **Permisos de Archivo**: Respeta permisos del sistema de archivos

### Puntos de Extensibilidad

1. **Sistema de Estrategias**: Fácilmente agregar nuevos patrones de sincronización
2. **Sistema de Comandos**: Adición modular de comandos
3. **Esquema de Configuración**: Extensiones compatibles hacia atrás
4. **Sistema de Logging**: Destinos de salida pluggeables
5. **Gestión de Estado**: Estructura de estado extensible

---

## Resolución de Problemas y Mantenimiento

### Problemas Comunes y Soluciones

1. **AWS CLI No Encontrado**
   - Instalar AWS CLI v2
   - Verificar variable de entorno PATH
   - Probar con `aws --version`

2. **Módulo PowerShell Faltante**
   - El sistema auto-instalará `powershell-yaml`
   - Instalación manual: `Install-Module powershell-yaml -Force`

3. **Errores de Permisos**
   - Verificar permisos del sistema de archivos
   - Verificar credenciales AWS y permisos S3
   - Asegurar acceso de escritura al bucket

4. **Errores de Configuración**
   - Validar sintaxis YAML
   - Verificar campos requeridos
   - Verificar existencia de rutas

### Monitoreo y Alertas

- **Archivos de Log**: Monitorear `log/sync_YYYY-MM.log` para errores
- **Archivo de Estado**: Verificar `state.json` para fallos consecutivos
- **Códigos de Salida**: Usar códigos de salida de comando para automatización
- **Salida JSON**: Parsear JSON del comando status para monitoreo

### Backup y Recuperación

- **Configuración**: Control de versiones `sync-config.yaml`
- **Estado**: Backup regular de `state.json`
- **Logs**: Archivar archivos de log importantes antes de limpieza
- **Datos S3**: Implementar políticas de versionado y backup de S3

---

Esta documentación técnica proporciona un entendimiento comprehensivo de la arquitectura del sistema Mochok, detalles de implementación, y guías de desarrollo. Para documentación orientada al usuario, referirse al archivo principal [README.md](../README.md).