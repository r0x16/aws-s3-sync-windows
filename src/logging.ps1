#region Funciones de Logging
<#
.SYNOPSIS
    Funciones para manejo de logs y rotación automática
#>

# Función: Registrar mensaje en el log del mes correspondiente
function Write-Log {
    param (
        [string] $Message,
        [ValidateSet("INFO","ERROR","WARNING")]
        [string] $Level = "INFO"
    )
    # Nombre del archivo de log: sync_YYYY-MM.log (correspondiente al mes actual)
    $logFileName = "sync_$((Get-Date).ToString('yyyy-MM')).log"
    $logPath = Join-Path $Global:LogDir $logFileName

    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $entry = "[$timestamp] [$Level] $Message"
    try {
        Add-Content -LiteralPath $logPath -Value $entry -ErrorAction Stop
    }
    catch {
        Write-Error "No se pudo escribir en el archivo de log '$logPath': $_"
    }
}

# Función: Rotar logs (eliminar archivos con más de X meses de antigüedad)
function Remove-OldLogs {
    # Fecha límite: hace X meses según configuración
    $limitDate = (Get-Date).AddMonths(-$Global:LogRetentionMonths)
    
    if (-not (Test-Path -LiteralPath $Global:LogDir)) {
        return
    }
    
    Get-ChildItem -LiteralPath $Global:LogDir -Filter "sync_*.log" -File | ForEach-Object {
        # Nombre de archivo: sync_YYYY-MM.log
        if ($_.Name -match '^sync_(\d{4})-(\d{2})\.log$') {
            $year = [int]$Matches[1]
            $month = [int]$Matches[2]
            # Construir primer día de ese mes
            try {
                $fileMonthDate = [datetime]"$($year)-$($month)-01"
                if ($fileMonthDate -lt $limitDate) {
                    try {
                        Remove-Item -LiteralPath $_.FullName -ErrorAction Stop
                        Write-Log -Message "Log antiguo eliminado: '$($_.Name)'" -Level "INFO"
                    }
                    catch {
                        Write-Log -Message "Error al eliminar log antiguo '$($_.Name)': $_" -Level "WARNING"
                    }
                }
            }
            catch {
                Write-Log -Message "Error al procesar fecha del log '$($_.Name)': $_" -Level "WARNING"
            }
        }
    }
}

# Función: Inicializar sistema de logging
function Initialize-Logging {
    Test-AndCreateFolder -Path $Global:LogDir
    Remove-OldLogs
}
#endregion 