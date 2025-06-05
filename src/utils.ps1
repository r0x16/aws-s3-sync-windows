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
        [string[]] $SyncOptions = @()
    )
    
    try {
        # Construir comando base
        $syncCommand = "aws s3 sync `"$LocalPath`" `"$S3Path`""
        
        # Agregar opciones adicionales si existen
        if ($SyncOptions -and $SyncOptions.Count -gt 0) {
            $optionsString = $SyncOptions -join " "
            $syncCommand += " $optionsString"
        }
        
        Write-Verbose "Ejecutando comando: $syncCommand"
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
#endregion 