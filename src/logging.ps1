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
    $logPath = Join-Path $(Get-LogDirectory) $logFileName

    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $entry = "[$timestamp] [$Level] $Message"
    try {
        # Usar StreamWriter para control más preciso del handle de archivo
        $streamWriter = $null
        try {
            $streamWriter = [System.IO.StreamWriter]::new($logPath, $true, [System.Text.Encoding]::UTF8)
            $streamWriter.WriteLine($entry)
            $streamWriter.Flush()
        }
        finally {
            if ($streamWriter) {
                $streamWriter.Close()
                $streamWriter.Dispose()
            }
        }
    }
    catch {
        Write-Error "No se pudo escribir en el archivo de log '$logPath': $_"
    }
}

# Función: Rotar logs (eliminar archivos con más de X meses de antigüedad)
function Remove-OldLogs {
    # Fecha límite: hace X meses según configuración
    $limitDate = (Get-Date).AddMonths(-$(Get-LogRetentionMonths))
    
    if (-not (Test-Path -LiteralPath $(Get-LogDirectory))) {
        return
    }
    
    Get-ChildItem -LiteralPath $(Get-LogDirectory) -Filter "sync_*.log" -File | ForEach-Object {
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
    Test-AndCreateFolder -Path $(Get-LogDirectory)
    Remove-OldLogs
}

# Función: Limpiar recursos de logging al finalizar
function Complete-Logging {
    try {
        # Cambiar directorio de trabajo para liberar cualquier handle de carpeta
        $originalLocation = Get-Location
        Set-Location -Path $env:TEMP
        
        # Forzar garbage collection múltiples veces para liberar handles de archivo
        for ($i = 0; $i -lt 3; $i++) {
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()
            [System.GC]::Collect()
            Start-Sleep -Milliseconds 100
        }
        
        # Forzar liberación de recursos .NET
        [System.GC]::GetTotalMemory($true) | Out-Null
        
        # Restaurar ubicación original solo si no era la carpeta de logs
        if ($originalLocation.Path -notlike "*log*") {
            Set-Location -Path $originalLocation
        }
    }
    catch {
        # Silenciosamente ignorar errores de limpieza
        try {
            Set-Location -Path $env:TEMP
        } catch {}
    }
}
#endregion 