#region Limpiador de Logs
<#
.SYNOPSIS
    Funciones especializadas para limpiar logs evitando conflictos de handles de archivo
#>

# Función: Limpiar logs de manera segura
function Clear-LogsSafely {
    param (
        [string] $LogDirectory = (Get-LogDirectory),
        [switch] $RemoveAll,
        [int] $KeepLastDays = 0
    )
    
    if (-not (Test-Path -LiteralPath $LogDirectory)) {
        Write-Host "Directorio de logs '$LogDirectory' no existe." -ForegroundColor Yellow
        return
    }
    
    try {
        # Convertir a path absoluto antes de cambiar directorios
        $LogDirectory = Resolve-Path -LiteralPath $LogDirectory -ErrorAction Stop
        
        # Cambiar a directorio temporal para liberar handles
        $originalLocation = Get-Location
        Set-Location -Path $env:TEMP
        
        # Forzar liberación de recursos
        for ($i = 0; $i -lt 3; $i++) {
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()
            [System.GC]::Collect()
            Start-Sleep -Milliseconds 300
        }
        
        $logFiles = Get-ChildItem -LiteralPath $LogDirectory -Filter "*.log" -File
        $deletedCount = 0
        $failedCount = 0
        
        foreach ($logFile in $logFiles) {
            $shouldDelete = $false
            
            if ($RemoveAll) {
                $shouldDelete = $true
            }
            elseif ($KeepLastDays -gt 0) {
                $cutoffDate = (Get-Date).AddDays(-$KeepLastDays)
                if ($logFile.LastWriteTime -lt $cutoffDate) {
                    $shouldDelete = $true
                }
            }
            
            if ($shouldDelete) {
                try {
                    # Intentar eliminar archivo individual
                    Remove-Item -LiteralPath $logFile.FullName -Force -ErrorAction Stop
                    Write-Host "Eliminado: $($logFile.Name)" -ForegroundColor Green
                    $deletedCount++
                }
                catch {
                    Write-Host "Error al eliminar $($logFile.Name): $_" -ForegroundColor Red
                    $failedCount++
                    
                    # Intentar método alternativo: renombrar y marcar para eliminación
                    try {
                        $tempName = "$($logFile.FullName).delete_$(Get-Random)"
                        Rename-Item -LiteralPath $logFile.FullName -NewName $tempName -ErrorAction Stop
                        Write-Host "Archivo $($logFile.Name) renombrado para eliminación posterior" -ForegroundColor Yellow
                    }
                    catch {
                        Write-Host "No se pudo renombrar $($logFile.Name)" -ForegroundColor Red
                    }
                }
            }
        }
        
        Write-Host "Limpieza completada: $deletedCount eliminados, $failedCount errores" -ForegroundColor Cyan
        
        # Restaurar ubicación
        Set-Location -Path $originalLocation
        
    }
    catch {
        Write-Host "Error durante la limpieza: $_" -ForegroundColor Red
        try { Set-Location -Path $originalLocation } catch {}
    }
}

# Función: Limpiar directorio completo de logs de manera segura
function Remove-LogDirectorySafely {
    param (
        [string] $LogDirectory = (Get-LogDirectory)
    )
    
    Write-Host "Iniciando limpieza segura del directorio de logs..." -ForegroundColor Cyan
    
    # Convertir a path absoluto
    try {
        $LogDirectory = Resolve-Path -LiteralPath $LogDirectory -ErrorAction Stop
    }
    catch {
        Write-Host "El directorio '$LogDirectory' no existe." -ForegroundColor Yellow
        return $true
    }
    
    # Primero limpiar todos los archivos
    Clear-LogsSafely -LogDirectory $LogDirectory -RemoveAll
    
    # Luego intentar eliminar el directorio
    try {
        # Cambiar a directorio temporal
        $originalLocation = Get-Location
        Set-Location -Path $env:TEMP
        
        # Múltiple limpieza de recursos
        for ($i = 0; $i -lt 5; $i++) {
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()
            [System.GC]::Collect()
            Start-Sleep -Milliseconds 500
        }
        
        # Verificar si el directorio está vacío
        $remainingFiles = @()
        try {
            $remainingFiles = Get-ChildItem -LiteralPath $LogDirectory -ErrorAction SilentlyContinue
        } catch {}
        
        if ($remainingFiles.Count -eq 0) {
            try {
                Remove-Item -LiteralPath $LogDirectory -Force -ErrorAction Stop
                Write-Host "Directorio de logs eliminado exitosamente." -ForegroundColor Green
                Set-Location -Path $originalLocation
                return $true
            }
            catch {
                Write-Host "No se pudo eliminar el directorio vacío: $_" -ForegroundColor Yellow
            }
        }
        else {
            Write-Host "El directorio aún contiene $($remainingFiles.Count) archivo(s)" -ForegroundColor Yellow
        }
        
        Set-Location -Path $originalLocation
        return $false
        
    }
    catch {
        Write-Host "Error durante la eliminación del directorio: $_" -ForegroundColor Red
        try { Set-Location -Path $originalLocation } catch {}
        return $false
    }
}

# Función: Limpieza de emergencia usando métodos del sistema
function Clear-LogsEmergency {
    param (
        [string] $LogDirectory = (Get-LogDirectory)
    )
    
    Write-Host "Ejecutando limpieza de emergencia..." -ForegroundColor Red
    
    try {
        # Método de último recurso: usar cmd para forzar eliminación
        $cmdCommand = "rmdir /s /q `"$LogDirectory`""
        Write-Host "Ejecutando: $cmdCommand" -ForegroundColor Yellow
        
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c", $cmdCommand -Wait -NoNewWindow
        
        if (-not (Test-Path -LiteralPath $LogDirectory)) {
            Write-Host "Directorio eliminado exitosamente con cmd" -ForegroundColor Green
            return $true
        }
        else {
            Write-Host "La eliminación con cmd no fue completamente exitosa" -ForegroundColor Yellow
            return $false
        }
    }
    catch {
        Write-Host "Error en limpieza de emergencia: $_" -ForegroundColor Red
        return $false
    }
}

# Export-ModuleMember -Function Clear-LogsSafely, Remove-LogDirectorySafely, Clear-LogsEmergency
#endregion 