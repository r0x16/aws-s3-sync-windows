param(
    [datetime] $TargetDate = (Get-Date).AddDays(-1)
)

# Obtener la ruta raíz del proyecto
$ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

# Importar funciones
. (Join-Path $ProjectRoot "src\config.ps1")
. (Join-Path $ProjectRoot "src\utils.ps1")
. (Join-Path $ProjectRoot "src\logging.ps1")
. (Join-Path $ProjectRoot "src\state-manager.ps1")
. (Join-Path $ProjectRoot "src\sync-service.ps1")

function Show-ConfigSummary {
    param([datetime] $TargetDate)
    
    $configurations = Get-EnabledSyncConfigurations
    $totalConfigs = $configurations.Count
    
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host "RESUMEN DE CONFIGURACIONES DE SINCRONIZACION" -ForegroundColor Yellow
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Fecha objetivo de sincronizacion: " -NoNewline -ForegroundColor White
    Write-Host $TargetDate.ToString("yyyy-MM-dd") -ForegroundColor Green
    Write-Host "Total de configuraciones habilitadas: " -NoNewline -ForegroundColor White
    Write-Host $totalConfigs -ForegroundColor Green
    Write-Host ""
    
    if ($totalConfigs -eq 0) {
        Write-Host "No hay configuraciones habilitadas para sincronizar." -ForegroundColor Red
        return
    }
    
    for ($i = 0; $i -lt $configurations.Count; $i++) {
        $config = $configurations[$i]
        $configNum = $i + 1
        
        Write-Host "[$configNum/$totalConfigs] " -NoNewline -ForegroundColor Cyan
        Write-Host "$($config.name)" -ForegroundColor Yellow
        Write-Host "    Descripcion: " -NoNewline -ForegroundColor Gray
        Write-Host "$($config.description)" -ForegroundColor White
        
        try {
            $syncPaths = Get-SyncPaths -Date $TargetDate -SyncConfig $config
            
            Write-Host "    Origen:  " -NoNewline -ForegroundColor Gray
            if (Test-Path -LiteralPath $syncPaths.LocalPath) {
                Write-Host "$($syncPaths.LocalPath)" -ForegroundColor Green
                try {
                    $fileCount = (Get-ChildItem -LiteralPath $syncPaths.LocalPath -File -Recurse -ErrorAction SilentlyContinue | Measure-Object).Count
                    Write-Host "              Archivos encontrados: " -NoNewline -ForegroundColor Gray
                    Write-Host $fileCount -ForegroundColor Cyan
                }
                catch {
                    Write-Host "              No se pudo contar archivos" -ForegroundColor Yellow
                }
            } else {
                Write-Host "$($syncPaths.LocalPath) " -NoNewline -ForegroundColor Red
                Write-Host "(No existe)" -ForegroundColor Red
            }
            
            Write-Host "    Destino: " -NoNewline -ForegroundColor Gray
            Write-Host "$($syncPaths.S3Path)" -ForegroundColor Green
        }
        catch {
            Write-Host "    Error al obtener rutas: $_" -ForegroundColor Red
        }
        
        $awsProfile = if ($config.destination_config -and $config.destination_config.aws_profile) { 
            $config.destination_config.aws_profile 
        } elseif ($config.aws_profile) { 
            $config.aws_profile 
        } else { 
            "default" 
        }
        
        $bucketName = if ($config.destination_config -and $config.destination_config.bucket_name) { 
            $config.destination_config.bucket_name 
        } else { 
            $config.bucket_name 
        }
        
        $awsRegion = if ($config.destination_config -and $config.destination_config.aws_region) { 
            $config.destination_config.aws_region 
        } elseif ($config.aws_region) { 
            $config.aws_region 
        } else { 
            "auto-detectar" 
        }
        
        Write-Host "    AWS Profile: " -NoNewline -ForegroundColor Gray
        Write-Host $awsProfile -ForegroundColor Cyan
        Write-Host "    Bucket S3:   " -NoNewline -ForegroundColor Gray
        Write-Host $bucketName -ForegroundColor Cyan
        Write-Host "    Region AWS:  " -NoNewline -ForegroundColor Gray
        Write-Host $awsRegion -ForegroundColor Cyan
        
        $strategyType = if ($config.sync_strategy -and $config.sync_strategy.type) { 
            $config.sync_strategy.type 
        } elseif ($config.sync_mode) { 
            $config.sync_mode 
        } else { 
            "DateFolder" 
        }
        
        Write-Host "    Estrategia:  " -NoNewline -ForegroundColor Gray
        Write-Host $strategyType -ForegroundColor Magenta
        
        if ($config.sync_options -and $config.sync_options.Count -gt 0) {
            Write-Host "    Opciones:    " -NoNewline -ForegroundColor Gray
            Write-Host ($config.sync_options -join ", ") -ForegroundColor DarkYellow
        }
        
        Write-Host ""
    }
    
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host "La sincronizacion comenzara en 3 segundos..." -ForegroundColor Yellow
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host ""
    
    Start-Sleep -Seconds 3
}

try {
    Import-YamlConfig -ScriptRoot $ProjectRoot
    Initialize-Logging
    
    Write-Log -Message "=== Iniciando proceso de sincronizacion AWS S3 multiples configuraciones - Mochok ==="
    
    Show-ConfigSummary -TargetDate $TargetDate
    
    $prerequisites = Test-SystemPrerequisites
    if (-not $prerequisites.IsValid) {
        $errorMsg = "Prerrequisitos del sistema no cumplidos: $($prerequisites.Issues -join '; ')"
        Write-Log -Message $errorMsg -Level "ERROR"
        Write-Error $errorMsg
        exit 1
    }
    
    $syncResults = Start-AllSyncProcesses -TargetDate $TargetDate
    
    if ($syncResults.Success) {
        Write-Log -Message "=== Proceso de sincronizacion completado exitosamente. Total: $($syncResults.TotalConfigs), Exitosas: $($syncResults.SuccessCount) ==="
        Complete-Logging
        exit 0
    }
    else {
        Write-Log -Message "=== Proceso de sincronizacion completado con errores. Total: $($syncResults.TotalConfigs), Exitosas: $($syncResults.SuccessCount), Errores: $($syncResults.ErrorCount) ==="
        Complete-Logging
        exit 1
    }
}
catch {
    $errorMsg = "Error inesperado durante la ejecucion: $_"
    Write-Log -Message $errorMsg -Level "ERROR"
    Write-Error $errorMsg
    Complete-Logging
    exit 1
} 