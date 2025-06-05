#region Funciones de Utilidad
<#
.SYNOPSIS
    Funciones de utilidad para el script de sincronización AWS S3
#>

# Función: Asegurar existencia de carpeta (crea si no existe)
function Test-AndCreateFolder {
    param (
        [string] $Path
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        try {
            New-Item -ItemType Directory -Path $Path -ErrorAction Stop | Out-Null
        }
        catch {
            Write-Error "Error al crear carpeta '$Path': $_"
            exit 1
        }
    }
}

# Función: Verificar existencia de AWS CLI
function Test-AwsCli {
    return ($null -ne (Get-Command "aws" -ErrorAction SilentlyContinue))
}

# Función: Construir rutas de sincronización para una configuración específica
function Get-SyncPaths {
    param (
        [datetime] $Date,
        [PSCustomObject] $SyncConfig
    )
    
    $year = $Date.ToString("yyyy")
    $month = $Date.ToString("MM")
    
    # Usar el formato de fecha especificado en la configuración
    $dateFormat = if ($SyncConfig.date_folder_format) { $SyncConfig.date_folder_format } else { "yyyy-MM-dd" }
    $dayFolderName = $Date.ToString($dateFormat)
    
    # Construir ruta local
    $localFolderPath = Join-Path $SyncConfig.local_base_path $dayFolderName
    
    # Construir estructura S3 personalizada
    $s3Structure = if ($SyncConfig.s3_path_structure) { 
        $SyncConfig.s3_path_structure 
    } else { 
        "{year}/{month}/{day}" 
    }
    
    # Reemplazar placeholders en la estructura S3
    $s3Structure = $s3Structure -replace '\{year\}', $year
    $s3Structure = $s3Structure -replace '\{month\}', $month
    $s3Structure = $s3Structure -replace '\{day\}', $dayFolderName
    
    $s3Destination = "s3://$($SyncConfig.bucket_name)/$s3Structure"
    
    return @{
        LocalPath = $localFolderPath
        S3Path = $s3Destination
        DayFolder = $dayFolderName
        ConfigName = $SyncConfig.name
    }
}

# Función: Ejecutar comando AWS S3 Sync con opciones personalizadas
function Invoke-S3Sync {
    param (
        [string] $LocalPath,
        [string] $S3Path,
        [string[]] $SyncOptions = @(),
        [string] $AwsProfile = "default"
    )
    
    try {
        # Construir comando base
        $syncCommand = "aws s3 sync"
        
        # Agregar profile si no es "default"
        if ($AwsProfile -and $AwsProfile -ne "default") {
            $syncCommand += " --profile `"$AwsProfile`""
        }
        
        # Agregar rutas
        $syncCommand += " `"$LocalPath`" `"$S3Path`""
        
        # Agregar opciones adicionales si existen
        if ($SyncOptions -and $SyncOptions.Count -gt 0) {
            $optionsString = $SyncOptions -join " "
            $syncCommand += " $optionsString"
        }
        
        Write-Log -Message "Ejecutando comando AWS S3: $syncCommand"
        $output = Invoke-Expression -Command $syncCommand 2>&1
        $success = $?

        return @{
            Success = $success
            ExitCode = if ($success) { 0 } else { 1 }
            Output = $output
            Command = $syncCommand
        }
    }
    catch {
        return @{
            Success = $false
            ExitCode = -1
            Output = $_.Exception.Message
            Command = $syncCommand
        }
    }
}

# Función: Eliminar carpeta de forma forzada cuando hay handles abiertos
function Remove-FolderForced {
    param (
        [string] $Path
    )
    
    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Host "La carpeta '$Path' no existe." -ForegroundColor Yellow
        return $true
    }
    
    try {
        # Método 1: Intentar eliminación normal
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
        Write-Host "Carpeta '$Path' eliminada exitosamente." -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Eliminación normal falló: $_" -ForegroundColor Yellow
    }
    
    try {
        # Método 2: Cambiar directorio y forzar garbage collection
        $originalLocation = Get-Location
        Set-Location -Path $env:TEMP
        
        # Múltiples ciclos de garbage collection
        for ($i = 0; $i -lt 5; $i++) {
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()
            [System.GC]::Collect()
            Start-Sleep -Milliseconds 200
        }
        
        # Intentar eliminación nuevamente
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
        Set-Location -Path $originalLocation
        Write-Host "Carpeta '$Path' eliminada exitosamente después de limpiar handles." -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Eliminación con limpieza falló: $_" -ForegroundColor Yellow
        try { Set-Location -Path $originalLocation } catch {}
    }
    
    try {
        # Método 3: Usar robocopy para "mover" a una carpeta temporal vacía (truco para liberar handles)
        $tempEmptyDir = Join-Path $env:TEMP "empty_$(Get-Random)"
        New-Item -ItemType Directory -Path $tempEmptyDir -Force | Out-Null
        
        # Usar robocopy para sincronizar con carpeta vacía (efectivamente vacía la carpeta original)
        & robocopy $tempEmptyDir $Path /MIR /NJH /NJS /NP | Out-Null
        Start-Sleep -Seconds 1
        
        # Ahora intentar eliminar
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
        Remove-Item -LiteralPath $tempEmptyDir -Force -ErrorAction SilentlyContinue
        
        Write-Host "Carpeta '$Path' eliminada exitosamente usando robocopy." -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Eliminación con robocopy falló: $_" -ForegroundColor Yellow
    }
    
    # Si todo falla, mostrar mensaje de ayuda
    Write-Host "No se pudo eliminar la carpeta '$Path'. Posibles soluciones:" -ForegroundColor Red
    Write-Host "1. Cerrar todos los exploradores de archivos" -ForegroundColor Red
    Write-Host "2. Cerrar este terminal de PowerShell y abrir uno nuevo" -ForegroundColor Red
    Write-Host "3. Reiniciar el sistema" -ForegroundColor Red
    return $false
}
#endregion 