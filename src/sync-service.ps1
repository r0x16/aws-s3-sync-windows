#region Servicio de Sincronización
<#
.SYNOPSIS
    Servicio principal para la sincronización con AWS S3
#>

# Función: Ejecutar proceso completo de sincronización para una configuración específica
function Start-SyncProcess {
    param (
        [datetime] $TargetDate,
        [PSCustomObject] $SyncConfig
    )
    
    # Obtener rutas de sincronización para esta configuración
    $syncPaths = Get-SyncPaths -Date $TargetDate -SyncConfig $SyncConfig
    
    Write-Log -Message "[$($SyncConfig.name)] Iniciando sincronización de '$($syncPaths.LocalPath)' a '$($syncPaths.S3Path)'."
    
    # Verificar existencia de la carpeta local
    if (-not (Test-Path -LiteralPath $syncPaths.LocalPath)) {
        $msg = "[$($SyncConfig.name)] Carpeta local '$($syncPaths.LocalPath)' no encontrada. Se omite sincronización del día $($syncPaths.DayFolder)."
        Write-Log -Message $msg -Level "ERROR"
        Add-StateEntry -Date $syncPaths.DayFolder -Status "Skipped" -Message "Carpeta local inexistente" -ConfigName $SyncConfig.name
        return $false
    }
    
    # Verificar existencia de AWS CLI
    if (-not (Test-AwsCli)) {
        $msg = "[$($SyncConfig.name)] AWS CLI no está instalado o no se encuentra en PATH."
        Write-Log -Message $msg -Level "ERROR"
        Add-StateEntry -Date $syncPaths.DayFolder -Status "Failure" -Message "AWS CLI no instalado" -ConfigName $SyncConfig.name
        return $false
    }
    
    # Ejecutar sincronización con opciones específicas
    $syncOptions = if ($SyncConfig.sync_options) { $SyncConfig.sync_options } else { @() }
    $awsProfile = if ($SyncConfig.aws_profile) { $SyncConfig.aws_profile } else { "default" }
    $syncResult = Invoke-S3Sync -LocalPath $syncPaths.LocalPath -S3Path $syncPaths.S3Path -SyncOptions $syncOptions -AwsProfile $awsProfile
    
    if ($syncResult.Success) {
        Write-Log -Message "[$($SyncConfig.name)] Sincronización exitosa."
        Add-StateEntry -Date $syncPaths.DayFolder -Status "Success" -Message "Sincronización completada sin errores." -ConfigName $SyncConfig.name
        return $true
    }
    else {
        $errorMessage = "[$($SyncConfig.name)] aws s3 sync devolvió código $($syncResult.ExitCode). Comando: $($syncResult.Command). Detalles: $($syncResult.Output)"
        Write-Log -Message $errorMessage -Level "ERROR"
        Add-StateEntry -Date $syncPaths.DayFolder -Status "Failure" -Message $errorMessage -ConfigName $SyncConfig.name
        return $false
    }
}

# Función: Ejecutar sincronización para todas las configuraciones habilitadas
function Start-AllSyncProcesses {
    param (
        [datetime] $TargetDate = (Get-Date).AddDays(-1)
    )
    
    $configurations = Get-EnabledSyncConfigurations
    $totalConfigs = $configurations.Count
    $successCount = 0
    $errorCount = 0
    
    Write-Log -Message "=== Iniciando sincronización para $totalConfigs configuración(es) ==="
    
    foreach ($config in $configurations) {
        try {
            Write-Log -Message "Procesando configuración: '$($config.name)' - $($config.description)"
            $success = Start-SyncProcess -TargetDate $TargetDate -SyncConfig $config
            
            if ($success) {
                $successCount++
                Write-Log -Message "[$($config.name)] Configuración procesada exitosamente." -Level "INFO"
            }
            else {
                $errorCount++
                Write-Log -Message "[$($config.name)] Error al procesar configuración." -Level "ERROR"
            }
        }
        catch {
            $errorCount++
            $errorMsg = "[$($config.name)] Excepción inesperada: $_"
            Write-Log -Message $errorMsg -Level "ERROR"
        }
    }
    
    Write-Log -Message "=== Resumen de sincronización: $successCount exitosas, $errorCount con errores ==="
    
    return @{
        TotalConfigs = $totalConfigs
        SuccessCount = $successCount
        ErrorCount = $errorCount
        Success = ($errorCount -eq 0)
    }
}

# Función: Validar prerrequisitos del sistema
function Test-SystemPrerequisites {
    $issues = @()
    
    # Verificar AWS CLI
    if (-not (Test-AwsCli)) {
        $issues += "AWS CLI no está instalado o no se encuentra en PATH"
    }
    
    # Verificar configuraciones
    $configurations = Get-EnabledSyncConfigurations
    if ($configurations.Count -eq 0) {
        $issues += "No hay configuraciones de sincronización habilitadas"
    }
    
    # Verificar carpetas base de cada configuración
    foreach ($config in $configurations) {
        if (-not (Test-Path -LiteralPath $config.local_base_path)) {
            $issues += "[$($config.name)] Carpeta base '$($config.local_base_path)' no existe"
        }
    }
    
    return @{
        IsValid = ($issues.Count -eq 0)
        Issues = $issues
    }
}
#endregion 