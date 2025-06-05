<#
.SYNOPSIS
    Script principal para sincronizar periódicamente la carpeta del día anterior a un bucket de AWS S3,
    manteniendo estado de ejecución, logs mensuales con rotación (máximo 12 meses) y manejo de errores.

.DESCRIPCIÓN
    Este script:
      - Calcula la fecha del día anterior.
      - Forma la ruta local correspondiente a esa carpeta (formato "yyyy-MM-dd").
      - Sincroniza esa carpeta con S3 usando `aws s3 sync`, sin la opción --delete.
      - Guarda el resultado de cada ejecución (fecha, hora, estado y mensaje) en un archivo JSON de estado.
      - Registra entradas de log en un archivo mensual dentro de la carpeta "log" al lado del script.
      - Rota los logs automáticamente, borrando archivos de log con más de 12 meses de antigüedad.
      - Maneja errores comunes (por ejemplo, AWS CLI no instalado, carpeta inexistente, errores de red).

.NOTAS
    - Colocar este script en la carpeta raíz donde están los subdirectorios diarios (ej. "2025-05-10", "2025-05-11", ...).
    - Debe existir AWS CLI configurado previamente (credenciales en ~/.aws/credentials o %USERPROFILE%\.aws\credentials).
    - Programar su ejecución periódica a las 00:00 cada día (por ejemplo, con el Programador de Tareas de Windows).

.PARAMETER TargetDate
    Fecha específica para sincronizar. Por defecto es el día anterior.

.EXAMPLE
    .\sync-main.ps1
    Sincroniza la carpeta del día anterior

.EXAMPLE
    .\sync-main.ps1 -TargetDate (Get-Date "2025-01-15")
    Sincroniza la carpeta del 15 de enero de 2025
#>

param(
    [datetime] $TargetDate = (Get-Date).AddDays(-1)
)

#region Importación de Módulos
# Importar archivos de configuración y funciones desde la carpeta src
. (Join-Path $PSScriptRoot "src\config.ps1")
. (Join-Path $PSScriptRoot "src\utils.ps1")
. (Join-Path $PSScriptRoot "src\logging.ps1")
. (Join-Path $PSScriptRoot "src\state-manager.ps1")
. (Join-Path $PSScriptRoot "src\sync-service.ps1")
#endregion

#region Ejecución Principal
try {
    # Cargar configuración desde YAML
    Import-YamlConfig
    
    # Inicializar sistema de logging
    Initialize-Logging
    
    Write-Log -Message "=== Iniciando proceso de sincronización AWS S3 multiples configuraciones ==="
    
    # Validar prerrequisitos del sistema
    $prerequisites = Test-SystemPrerequisites
    if (-not $prerequisites.IsValid) {
        $errorMsg = "Prerrequisitos del sistema no cumplidos: $($prerequisites.Issues -join '; ')"
        Write-Log -Message $errorMsg -Level "ERROR"
        Write-Error $errorMsg
        exit 1
    }
    
    # Ejecutar proceso de sincronización para todas las configuraciones
    $syncResults = Start-AllSyncProcesses -TargetDate $TargetDate
    
    if ($syncResults.Success) {
        Write-Log -Message "=== Proceso de sincronización completado exitosamente. Total: $($syncResults.TotalConfigs), Exitosas: $($syncResults.SuccessCount) ==="
        exit 0
    }
    else {
        Write-Log -Message "=== Proceso de sincronización completado con errores. Total: $($syncResults.TotalConfigs), Exitosas: $($syncResults.SuccessCount), Errores: $($syncResults.ErrorCount) ==="
        exit 1
    }
}
catch {
    $errorMsg = "Error inesperado durante la ejecución: $_"
    Write-Log -Message $errorMsg -Level "ERROR"
    Write-Error $errorMsg
    exit 1
}
#endregion 