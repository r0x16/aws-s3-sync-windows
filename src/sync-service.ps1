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
    
    $startTime = Get-Date
    
    # Obtener rutas de sincronización para esta configuración
    $syncPaths = Get-SyncPaths -Date $TargetDate -SyncConfig $SyncConfig
    
    Write-Log -Message "[$($SyncConfig.name)] Iniciando sincronización de '$($syncPaths.LocalPath)' a '$($syncPaths.S3Path)'."
    
    # Verificar existencia de la carpeta local
    if (-not (Test-Path -LiteralPath $syncPaths.LocalPath)) {
        $msg = "[$($SyncConfig.name)] Carpeta local '$($syncPaths.LocalPath)' no encontrada. Se omite sincronización del día $($syncPaths.DayFolder)."
        Write-Log -Message $msg -Level "ERROR"
        
        # Registrar resultado con información detallada
        Set-ConfigurationResult -ConfigName $SyncConfig.name -Status "Skipped" -Message "Carpeta local inexistente" -Date $syncPaths.DayFolder -LocalPath $syncPaths.LocalPath -S3Path $syncPaths.S3Path
        return $false
    }
    
    # Verificar existencia de AWS CLI
    if (-not (Test-AwsCli)) {
        $msg = "[$($SyncConfig.name)] AWS CLI no está instalado o no se encuentra en PATH."
        Write-Log -Message $msg -Level "ERROR"
        
        # Registrar resultado con información detallada
        Set-ConfigurationResult -ConfigName $SyncConfig.name -Status "Failure" -Message "AWS CLI no instalado" -Date $syncPaths.DayFolder -LocalPath $syncPaths.LocalPath -S3Path $syncPaths.S3Path
        return $false
    }
    
    # Verificar/crear bucket S3 si es necesario
    $awsProfile = if ($SyncConfig.destination_config -and $SyncConfig.destination_config.aws_profile) { 
        $SyncConfig.destination_config.aws_profile 
    } elseif ($SyncConfig.aws_profile) { 
        $SyncConfig.aws_profile 
    } else { 
        "default" 
    }
    
    $bucketRegion = if ($SyncConfig.destination_config -and $SyncConfig.destination_config.aws_region) { 
        $SyncConfig.destination_config.aws_region 
    } elseif ($SyncConfig.aws_region) { 
        $SyncConfig.aws_region 
    } else { 
        $null 
    }
    
    $bucketName = if ($SyncConfig.destination_config -and $SyncConfig.destination_config.bucket_name) { 
        $SyncConfig.destination_config.bucket_name 
    } else { 
        $SyncConfig.bucket_name 
    }
    
    Write-Log -Message "[$($SyncConfig.name)] Verificando bucket S3: $bucketName"
    $bucketResult = Confirm-S3Bucket -BucketName $bucketName -AwsProfile $awsProfile -Region $bucketRegion
    
    if (-not $bucketResult.Success) {
        $msg = "[$($SyncConfig.name)] Error al verificar/crear bucket S3 '$bucketName': $($bucketResult.Message)"
        Write-Log -Message $msg -Level "ERROR"
        
        # Registrar resultado con información detallada
        Set-ConfigurationResult -ConfigName $SyncConfig.name -Status "Failure" -Message $msg -Date $syncPaths.DayFolder -LocalPath $syncPaths.LocalPath -S3Path $syncPaths.S3Path
        return $false
    }
    
    # Registrar el resultado del bucket
    if ($bucketResult.Action -eq "Created") {
        Write-Log -Message "[$($SyncConfig.name)] Bucket S3 '$bucketName' creado exitosamente en la región '$($bucketResult.Region)'"
    } elseif ($bucketResult.Action -eq "Exists") {
        Write-Log -Message "[$($SyncConfig.name)] Bucket S3 '$bucketName' ya existía"
    }
    
    # Contar archivos antes de la sincronización
    $filesBeforeSync = 0
    try {
        $filesBeforeSync = (Get-ChildItem -LiteralPath $syncPaths.LocalPath -File -Recurse -ErrorAction SilentlyContinue | Measure-Object).Count
        Write-Log -Message "[$($SyncConfig.name)] Archivos a sincronizar: $filesBeforeSync"
    }
    catch {
        Write-Log -Message "[$($SyncConfig.name)] No se pudo contar archivos locales: $_" -Level "WARNING"
    }
    
    # Ejecutar sincronización con opciones específicas
    $syncOptions = if ($SyncConfig.sync_options) { $SyncConfig.sync_options } else { @() }
    $syncResult = Invoke-S3Sync -LocalPath $syncPaths.LocalPath -S3Path $syncPaths.S3Path -SyncOptions $syncOptions -AwsProfile $awsProfile
    
    # Calcular duración
    $endTime = Get-Date
    $duration = $endTime - $startTime
    $durationString = $duration.ToString("hh\:mm\:ss")
    
    if ($syncResult.Success) {
        # Analizar output para contar archivos transferidos
        $filesTransferred = 0
        if ($syncResult.Output) {
            $outputText = $syncResult.Output -join "`n"
            # Buscar patrones como "upload: file.txt to s3://bucket/file.txt"
            $uploadMatches = [regex]::Matches($outputText, "upload:|copy:")
            $filesTransferred = $uploadMatches.Count
        }
        
        $successMessage = "Sincronización completada sin errores. Archivos transferidos: $filesTransferred"
        Write-Log -Message "[$($SyncConfig.name)] $successMessage (Duración: $durationString)"
        
        # Registrar resultado exitoso con información detallada
        Set-ConfigurationResult -ConfigName $SyncConfig.name -Status "Success" -Message $successMessage -Date $syncPaths.DayFolder -LocalPath $syncPaths.LocalPath -S3Path $syncPaths.S3Path -FilesTransferred $filesTransferred -Duration $durationString
        return $true
    }
    else {
        $errorMessage = "aws s3 sync devolvió código $($syncResult.ExitCode). Comando: $($syncResult.Command). Detalles: $($syncResult.Output)"
        Write-Log -Message "[$($SyncConfig.name)] $errorMessage (Duración: $durationString)" -Level "ERROR"
        
        # Registrar resultado fallido con información detallada
        Set-ConfigurationResult -ConfigName $SyncConfig.name -Status "Failure" -Message $errorMessage -Date $syncPaths.DayFolder -LocalPath $syncPaths.LocalPath -S3Path $syncPaths.S3Path -Duration $durationString
        return $false
    }
}

# Función: Ejecutar sincronización para todas las configuraciones habilitadas
function Start-AllSyncProcesses {
    param (
        [datetime] $TargetDate = (Get-Date).AddDays(-1)
    )
    
    $startTime = Get-Date
    $configurations = Get-EnabledSyncConfigurations
    $totalConfigs = [int]$configurations.Count
    $successCount = [int]0
    $errorCount = [int]0
    
    Write-Log -Message "=== Iniciando sincronización para $totalConfigs configuración(es) ==="
    
    # Inicializar ejecución en el estado
    Start-StateExecution -TargetDate $TargetDate -TotalConfigurations $totalConfigs
    
    foreach ($config in $configurations) {
        try {
            Write-Log -Message "Procesando configuración: '$($config.name)' - $($config.description)"
            $success = Start-SyncProcess -TargetDate $TargetDate -SyncConfig $config
            
            if ($success) {
                $successCount = $successCount + 1
                Write-Log -Message "[$($config.name)] Configuración procesada exitosamente." -Level "INFO"
            }
            else {
                $errorCount = $errorCount + 1
                Write-Log -Message "[$($config.name)] Error al procesar configuración." -Level "ERROR"
            }
        }
        catch {
            $errorCount = $errorCount + 1
            $errorMsg = "[$($config.name)] Excepción inesperada: $_"
            Write-Log -Message $errorMsg -Level "ERROR"
            
            # Registrar excepción en el estado
            $syncPaths = Get-SyncPaths -Date $TargetDate -SyncConfig $config
            Set-ConfigurationResult -ConfigName $config.name -Status "Failure" -Message $errorMsg -Date $syncPaths.DayFolder -LocalPath $syncPaths.LocalPath -S3Path $syncPaths.S3Path
        }
    }
    
    # Calcular duración total y finalizar ejecución en el estado
    $endTime = Get-Date
    $totalDuration = $endTime - $startTime
    $overallSuccess = ($errorCount -eq 0)
    
    Complete-StateExecution -Success $overallSuccess -Duration $totalDuration
    
    Write-Log -Message "=== Resumen de sincronización: $successCount exitosas, $errorCount con errores (Duración total: $($totalDuration.ToString("hh\:mm\:ss"))) ==="
    
    return @{
        TotalConfigs = $totalConfigs
        SuccessCount = $successCount
        ErrorCount = $errorCount
        Success = $overallSuccess
        Duration = $totalDuration
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
    
    # Verificar configuración de cada estrategia de sincronización
    foreach ($config in $configurations) {
        # Validar configuración de la estrategia de sincronización
        $strategyValidation = Test-SyncStrategyConfiguration -SyncConfig $config
        if (-not $strategyValidation.IsValid) {
            foreach ($issue in $strategyValidation.Issues) {
                $issues += "[$($config.name)] $issue"
            }
        }
        
        # Verificar carpetas base según la estrategia
        $strategyType = if ($config.sync_strategy -and $config.sync_strategy.type) { 
            $config.sync_strategy.type 
        } elseif ($config.sync_mode) { 
            $config.sync_mode 
        } else { 
            "DateFolder" 
        }
        
        switch ($strategyType) {
            "DateFolder" {
                if (-not (Test-Path -LiteralPath $config.local_base_path)) {
                    $issues += "[$($config.name)] Carpeta base '$($config.local_base_path)' no existe"
                }
            }
            "FullDirectory" {
                if (-not (Test-Path -LiteralPath $config.local_base_path)) {
                    $issues += "[$($config.name)] Carpeta base '$($config.local_base_path)' no existe"
                }
            }
            "DateRange" {
                if (-not (Test-Path -LiteralPath $config.local_base_path)) {
                    $issues += "[$($config.name)] Carpeta base '$($config.local_base_path)' no existe"
                }
            }
            "CustomPattern" {
                # Para CustomPattern verificamos si es un patrón que incluye carpeta base
                $hasCustomPattern = ($config.sync_strategy -and $config.sync_strategy.custom_local_pattern) -or 
                                  ($config.mode_config -and $config.mode_config.custom_local_pattern)
                
                if ($hasCustomPattern) {
                    $customPattern = if ($config.sync_strategy -and $config.sync_strategy.custom_local_pattern) { 
                        $config.sync_strategy.custom_local_pattern 
                    } else { 
                        $config.mode_config.custom_local_pattern 
                    }
                    
                    if ($customPattern.Contains("{base_path}") -and -not (Test-Path -LiteralPath $config.local_base_path)) {
                        $issues += "[$($config.name)] Carpeta base '$($config.local_base_path)' no existe (requerida por sync_strategy.custom_local_pattern)"
                    }
                } elseif ($config.local_base_path -and -not (Test-Path -LiteralPath $config.local_base_path)) {
                    $issues += "[$($config.name)] Carpeta base '$($config.local_base_path)' no existe"
                }
            }
        }
    }
    
    return @{
        IsValid = ($issues.Count -eq 0)
        Issues = $issues
    }
}

# Función: Generar reporte del estado actual
function Show-SyncStatusReport {
    Write-Log -Message "=== Generando reporte de estado ==="
    
    try {
        $report = Get-StateReport
        
        Write-Log -Message "--- ÚLTIMA EJECUCIÓN ---"
        if ($report.LastExecution.timestamp) {
            Write-Log -Message "Fecha: $($report.LastExecution.timestamp)"
            Write-Log -Message "Fecha objetivo: $($report.LastExecution.targetDate)"
            Write-Log -Message "Éxito: $($report.LastExecution.success)"
            Write-Log -Message "Duración: $($report.LastExecution.duration)"
            Write-Log -Message "Configuraciones totales: $($report.LastExecution.totalConfigurations)"
            Write-Log -Message "Exitosas: $($report.LastExecution.successfulConfigurations)"
            Write-Log -Message "Fallidas: $($report.LastExecution.failedConfigurations)"
        } else {
            Write-Log -Message "No hay ejecuciones previas registradas"
        }
        
        Write-Log -Message "--- ESTADÍSTICAS GENERALES ---"
        Write-Log -Message "Total configuraciones: $($report.TotalConfigurations)"
        Write-Log -Message "Configuraciones exitosas: $($report.SuccessfulConfigurations)"
        Write-Log -Message "Configuraciones fallidas: $($report.FailedConfigurations)"
        Write-Log -Message "Total ejecuciones: $($report.Statistics.totalExecutions)"
        Write-Log -Message "Última fecha exitosa: $($report.Statistics.lastSuccessDate)"
        Write-Log -Message "Fallos consecutivos: $($report.Statistics.consecutiveFailures)"
        
        Write-Log -Message "--- DETALLE POR CONFIGURACIÓN ---"
        foreach ($configProperty in $report.ConfigurationDetails.PSObject.Properties) {
            $configName = $configProperty.Name
            $configData = $configProperty.Value
            
            Write-Log -Message "[$configName]"
            Write-Log -Message "  Estado: $($configData.lastStatus)"
            Write-Log -Message "  Último timestamp: $($configData.lastTimestamp)"
            Write-Log -Message "  Última fecha: $($configData.lastDate)"
            Write-Log -Message "  Mensaje: $($configData.lastMessage)"
            if ($configData.localPath) {
                Write-Log -Message "  Ruta local: $($configData.localPath)"
                Write-Log -Message "  Ruta S3: $($configData.s3Path)"
            }
            if ($configData.filesTransferred -gt 0) {
                Write-Log -Message "  Archivos transferidos: $($configData.filesTransferred)"
            }
            if ($configData.duration) {
                Write-Log -Message "  Duración: $($configData.duration)"
            }
            Write-Log -Message "  Fallos consecutivos: $($configData.consecutiveFailures)"
            Write-Log -Message ""
        }
        
        Write-Log -Message "=== Reporte de estado completado ==="
        return $report
    }
    catch {
        Write-Log -Message "Error al generar reporte de estado: $_" -Level "ERROR"
        return $null
    }
}
#endregion 