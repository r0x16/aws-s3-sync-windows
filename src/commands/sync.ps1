<#
.SYNOPSIS
    Comando sync para Mochok - Ejecuta la sincronización principal

.DESCRIPCIÓN
    Este comando ejecuta la sincronización principal de archivos con AWS S3,
    manteniendo estado de ejecución, logs mensuales con rotación y manejo de errores.

.PARAMETER TargetDate
    Fecha específica para sincronizar. Por defecto es el día anterior.

.EXAMPLE
    .\sync.ps1
    Sincroniza la carpeta del día anterior

.EXAMPLE
    .\sync.ps1 -TargetDate (Get-Date "2025-01-15")
    Sincroniza la carpeta del 15 de enero de 2025
#>

param(
    [datetime] $TargetDate = (Get-Date).AddDays(-1)
)

# Obtener la ruta raíz del proyecto (dos niveles arriba desde src/commands)
$ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

#region Importación de Módulos
# Importar funciones desde archivos especializados
. (Join-Path $ProjectRoot "src\config.ps1")
. (Join-Path $ProjectRoot "src\utils.ps1")
. (Join-Path $ProjectRoot "src\logging.ps1")
. (Join-Path $ProjectRoot "src\state-manager.ps1")
. (Join-Path $ProjectRoot "src\sync-service.ps1")
#endregion

#region Ejecución Principal
try {
    # Cargar configuración desde YAML
    Import-YamlConfig -ScriptRoot $ProjectRoot
    
    # Inicializar sistema de logging
    Initialize-Logging
    
    Write-Log -Message "=== Iniciando proceso de sincronización AWS S3 múltiples configuraciones - Mochok ==="
    
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
        Complete-Logging
        exit 0
    }
    else {
        Write-Log -Message "=== Proceso de sincronización completado con errores. Total: $($syncResults.TotalConfigs), Exitosas: $($syncResults.SuccessCount), Errores: $($syncResults.ErrorCount) ==="
        Complete-Logging
        exit 1
    }
}
catch {
    $errorMsg = "Error inesperado durante la ejecución: $_"
    Write-Log -Message $errorMsg -Level "ERROR"
    Write-Error $errorMsg
    Complete-Logging
    exit 1
}
#endregion 