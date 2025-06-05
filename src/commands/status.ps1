<#
.SYNOPSIS
    Comando status para Mochok - Muestra el estado actual de las sincronizaciones

.DESCRIPTION
    Este comando muestra un reporte detallado del estado de la última copia realizada en Mochok,
    incluyendo información de cada configuración y estadísticas generales.

.EXAMPLE
    .\status.ps1
    Muestra el reporte completo del estado actual

.EXAMPLE
    .\status.ps1 -OnlyLastExecution
    Muestra solo información de la última ejecución
#>

param(
    [switch] $OnlyLastExecution,
    [switch] $JsonOutput
)

# Obtener la ruta raíz del proyecto (dos niveles arriba desde src/commands)
$ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

#region Importación de Módulos
# Importar funciones desde archivos especializados
. (Join-Path $ProjectRoot "src\config.ps1")
. (Join-Path $ProjectRoot "src\state-manager.ps1")
. (Join-Path $ProjectRoot "src\logging.ps1")
#endregion

function Show-ColoredOutput {
    param(
        [string] $Text,
        [string] $Color = "White"
    )
    
    if ($JsonOutput) {
        Write-Output $Text
    } else {
        Write-Host $Text -ForegroundColor $Color
    }
}

function Format-Duration {
    param([string] $Duration)
    
    if ([string]::IsNullOrEmpty($Duration)) {
        return "N/A"
    }
    return $Duration
}

function Format-DateTime {
    param([string] $DateTime)
    
    if ([string]::IsNullOrEmpty($DateTime)) {
        return "N/A"
    }
    
    try {
        $dt = [DateTime]::Parse($DateTime)
        return $dt.ToString("yyyy-MM-dd HH:mm:ss")
    }
    catch {
        return $DateTime
    }
}

function Show-StatusReport {
    try {
        # Cargar configuración
        Import-YamlConfig -ScriptRoot $ProjectRoot
        
        # Obtener reporte del estado
        $report = Get-StateReport
        
        if ($JsonOutput) {
            $report | ConvertTo-Json -Depth 10
            return
        }
        
        Show-ColoredOutput "╔══════════════════════════════════════════════════════════════════╗" "Cyan"
        Show-ColoredOutput "║                      REPORTE DE ESTADO MOCHOK                   ║" "Cyan"
        Show-ColoredOutput "╚══════════════════════════════════════════════════════════════════╝" "Cyan"
        Show-ColoredOutput ""
        
        # Información de la última ejecución
        Show-ColoredOutput "📊 ÚLTIMA EJECUCIÓN" "Yellow"
        Show-ColoredOutput "─────────────────────────────────────────────────────────────────" "Gray"
        
        if ($report.LastExecution.timestamp) {
            $successIcon = if ($report.LastExecution.success) { "✅" } else { "❌" }
            $successText = if ($report.LastExecution.success) { "EXITOSA" } else { "CON ERRORES" }
            $successColor = if ($report.LastExecution.success) { "Green" } else { "Red" }
            
            Show-ColoredOutput "   Timestamp: $(Format-DateTime $report.LastExecution.timestamp)" "White"
            Show-ColoredOutput "   Fecha objetivo: $($report.LastExecution.targetDate)" "White"
            Show-ColoredOutput "   Estado: $successIcon $successText" $successColor
            Show-ColoredOutput "   Duración: $(Format-Duration $report.LastExecution.duration)" "White"
            Show-ColoredOutput "   Total configuraciones: $($report.LastExecution.totalConfigurations)" "White"
            Show-ColoredOutput "   ├─ Exitosas: $($report.LastExecution.successfulConfigurations)" "Green"
            Show-ColoredOutput "   └─ Fallidas: $($report.LastExecution.failedConfigurations)" "Red"
        } else {
            Show-ColoredOutput "   ⚠️  No hay ejecuciones registradas" "Yellow"
        }
        
        Show-ColoredOutput ""
        
        if (-not $OnlyLastExecution) {
            # Estadísticas generales
            Show-ColoredOutput "📈 ESTADÍSTICAS GENERALES" "Yellow"
            Show-ColoredOutput "─────────────────────────────────────────────────────────────────" "Gray"
            Show-ColoredOutput "   Total configuraciones: $($report.TotalConfigurations)" "White"
            Show-ColoredOutput "   ├─ Exitosas: $($report.SuccessfulConfigurations)" "Green"
            Show-ColoredOutput "   └─ Fallidas: $($report.FailedConfigurations)" "Red"
            Show-ColoredOutput "   Total ejecuciones: $($report.Statistics.totalExecutions)" "White"
            Show-ColoredOutput "   Última fecha exitosa: $(Format-DateTime $report.Statistics.lastSuccessDate)" "White"
            Show-ColoredOutput "   Fallos consecutivos: $($report.Statistics.consecutiveFailures)" "White"
            Show-ColoredOutput ""
            
            # Detalle por configuración
            Show-ColoredOutput "🔧 CONFIGURACIONES" "Yellow"
            Show-ColoredOutput "─────────────────────────────────────────────────────────────────" "Gray"
            
            if ($report.ConfigurationDetails.PSObject.Properties.Count -eq 0) {
                Show-ColoredOutput "   ⚠️  No hay configuraciones registradas" "Yellow"
            } else {
                foreach ($configProperty in $report.ConfigurationDetails.PSObject.Properties) {
                    $configName = $configProperty.Name
                    $configData = $configProperty.Value
                    
                    $statusIcon = switch ($configData.lastStatus) {
                        "Success" { "✅" }
                        "Failure" { "❌" }
                        "Skipped" { "⏭️ " }
                        default { "❓" }
                    }
                    
                    $statusColor = switch ($configData.lastStatus) {
                        "Success" { "Green" }
                        "Failure" { "Red" }
                        "Skipped" { "Yellow" }
                        default { "Gray" }
                    }
                    
                    Show-ColoredOutput ""
                    Show-ColoredOutput "   🔸 [$configName]" "Cyan"
                    Show-ColoredOutput "      Estado: $statusIcon $($configData.lastStatus)" $statusColor
                    Show-ColoredOutput "      Timestamp: $(Format-DateTime $configData.lastTimestamp)" "White"
                    Show-ColoredOutput "      Fecha: $($configData.lastDate)" "White"
                    Show-ColoredOutput "      Mensaje: $($configData.lastMessage)" "White"
                    
                    if ($configData.localPath) {
                        Show-ColoredOutput "      Ruta local: $($configData.localPath)" "Gray"
                        Show-ColoredOutput "      Ruta S3: $($configData.s3Path)" "Gray"
                    }
                    
                    if ($configData.filesTransferred -gt 0) {
                        Show-ColoredOutput "      Archivos transferidos: $($configData.filesTransferred)" "White"
                    }
                    
                    if ($configData.duration) {
                        Show-ColoredOutput "      Duración: $(Format-Duration $configData.duration)" "White"
                    }
                    
                    if ($configData.consecutiveFailures -gt 0) {
                        Show-ColoredOutput "      ⚠️  Fallos consecutivos: $($configData.consecutiveFailures)" "Red"
                    }
                }
            }
            
            Show-ColoredOutput ""
            
            # Últimas sincronizaciones exitosas
            Show-ColoredOutput "✅ ÚLTIMAS SINCRONIZACIONES EXITOSAS" "Yellow"
            Show-ColoredOutput "─────────────────────────────────────────────────────────────────" "Gray"
            
            if ($report.LastSuccessfulSyncs.PSObject.Properties.Count -eq 0) {
                Show-ColoredOutput "   ⚠️  No hay sincronizaciones exitosas registradas" "Yellow"
            } else {
                foreach ($syncProperty in $report.LastSuccessfulSyncs.PSObject.Properties) {
                    $syncName = $syncProperty.Name
                    $syncData = $syncProperty.Value
                    
                    Show-ColoredOutput ""
                    Show-ColoredOutput "   🔸 [$syncName]" "Green"
                    Show-ColoredOutput "      Timestamp: $(Format-DateTime $syncData.timestamp)" "White"
                    Show-ColoredOutput "      Fecha: $($syncData.date)" "White"
                    
                    if ($syncData.filesTransferred -gt 0) {
                        Show-ColoredOutput "      Archivos transferidos: $($syncData.filesTransferred)" "White"
                    }
                    
                    if ($syncData.duration) {
                        Show-ColoredOutput "      Duración: $(Format-Duration $syncData.duration)" "White"
                    }
                    
                    Show-ColoredOutput "      Ruta S3: $($syncData.s3Path)" "Gray"
                }
            }
        }
        
        Show-ColoredOutput ""
        Show-ColoredOutput "═══════════════════════════════════════════════════════════════════" "Cyan"
        Show-ColoredOutput "                     🌟 Fin del reporte Mochok 🌟                  " "Cyan"
        Show-ColoredOutput "═══════════════════════════════════════════════════════════════════" "Cyan"
        
    }
    catch {
        Write-Error "Error al generar reporte de estado en Mochok: $_"
        exit 1
    }
}

# Ejecutar el reporte
Show-StatusReport 