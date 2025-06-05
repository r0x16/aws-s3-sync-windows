<#
.SYNOPSIS
    Comando clear logs para Mochok - Limpia archivos de log del sistema

.DESCRIPTION
    Este comando debe ejecutarse desde una nueva sesión de PowerShell para evitar
    conflictos con handles de archivo abiertos por el script principal.

.EXAMPLE
    .\clear-logs.ps1
    Limpia todos los archivos de log

.EXAMPLE
    .\clear-logs.ps1 -RemoveDirectory
    Intenta eliminar también el directorio de logs

.EXAMPLE
    .\clear-logs.ps1 -KeepLastDays 7
    Mantiene los logs de los últimos 7 días
#>

param(
    [switch] $RemoveDirectory,
    [int] $KeepLastDays = 0
)

# Obtener la ruta raíz del proyecto (dos niveles arriba desde src/commands)
$ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

# Cargar configuración
. (Join-Path $ProjectRoot "src\config.ps1")
try {
    Import-YamlConfig -ScriptRoot $ProjectRoot
}
catch {
    Write-Host "⚠️  Error al cargar configuración. Usando valores por defecto." -ForegroundColor Yellow
    $logDir = Join-Path $ProjectRoot "log"
}

$logDir = Get-LogDirectory

if (-not (Test-Path -LiteralPath $logDir)) {
    Write-Host "╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║                                                                  ║" -ForegroundColor Green
    Write-Host "║                🌟 MOCHOK - LIMPIADOR DE LOGS 🌟                 ║" -ForegroundColor Green
    Write-Host "║                                                                  ║" -ForegroundColor Green
    Write-Host "╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Host "✅ Directorio de logs '$logDir' no existe. Nada que limpiar." -ForegroundColor Green
    exit 0
}

Write-Host "╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                                                                  ║" -ForegroundColor Cyan
Write-Host "║                🌟 MOCHOK - LIMPIADOR DE LOGS 🌟                 ║" -ForegroundColor Cyan
Write-Host "║                                                                  ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "📁 Directorio de logs: $logDir" -ForegroundColor White

try {
    # Cambiar a directorio temporal para liberar handles
    $originalLocation = Get-Location
    Set-Location -Path $env:TEMP
    
    # Forzar limpieza de memoria múltiples veces
    Write-Host "🔄 Liberando handles de archivo..." -ForegroundColor Yellow
    for ($i = 0; $i -lt 5; $i++) {
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
        [System.GC]::Collect()
        Start-Sleep -Milliseconds 200
    }
    
    # Obtener archivos de log
    $logFiles = Get-ChildItem -LiteralPath $logDir -Filter "*.log" -File -ErrorAction SilentlyContinue
    
    if ($logFiles.Count -eq 0) {
        Write-Host "✅ No se encontraron archivos de log para limpiar." -ForegroundColor Green
    }
    else {
        Write-Host "📋 Encontrados $($logFiles.Count) archivo(s) de log." -ForegroundColor White
        Write-Host ""
        
        $deletedCount = 0
        $failedCount = 0
        
        foreach ($logFile in $logFiles) {
            $shouldDelete = $false
            
            if ($KeepLastDays -eq 0) {
                $shouldDelete = $true
            }
            else {
                $cutoffDate = (Get-Date).AddDays(-$KeepLastDays)
                if ($logFile.LastWriteTime -lt $cutoffDate) {
                    $shouldDelete = $true
                }
            }
            
            if ($shouldDelete) {
                try {
                    Remove-Item -LiteralPath $logFile.FullName -Force -ErrorAction Stop
                    Write-Host "✅ Eliminado: $($logFile.Name)" -ForegroundColor Green
                    $deletedCount++
                }
                catch {
                    Write-Host "❌ Error al eliminar $($logFile.Name): $_" -ForegroundColor Red
                    $failedCount++
                }
            }
            else {
                Write-Host "➡️  Mantenido: $($logFile.Name) (dentro del período de retención)" -ForegroundColor Yellow
            }
        }
        
        Write-Host ""
        Write-Host "📊 Resumen: $deletedCount eliminados, $failedCount errores" -ForegroundColor Cyan
    }
    
    # Intentar eliminar directorio si se solicita
    if ($RemoveDirectory) {
        Write-Host ""
        Write-Host "🗑️  Intentando eliminar directorio de logs..." -ForegroundColor Yellow
        
        # Verificar si está vacío
        $remainingFiles = @()
        try {
            $remainingFiles = Get-ChildItem -LiteralPath $logDir -ErrorAction SilentlyContinue
        } catch {}
        
        if ($remainingFiles.Count -eq 0) {
            try {
                Remove-Item -LiteralPath $logDir -Force -ErrorAction Stop
                Write-Host "✅ Directorio eliminado exitosamente." -ForegroundColor Green
            }
            catch {
                Write-Host "❌ No se pudo eliminar el directorio: $_" -ForegroundColor Red
                Write-Host ""
                Write-Host "💡 SOLUCIÓN: Para eliminar el directorio completamente:" -ForegroundColor Yellow
                Write-Host "1. Cierre este terminal de PowerShell" -ForegroundColor White
                Write-Host "2. Abra un nuevo terminal" -ForegroundColor White
                Write-Host "3. Ejecute: Remove-Item -Force -Recurse '$logDir'" -ForegroundColor White
                Write-Host "4. O reinicie el sistema si persiste el problema" -ForegroundColor White
            }
        }
        else {
            Write-Host "❌ El directorio aún contiene $($remainingFiles.Count) archivo(s)" -ForegroundColor Red
        }
    }
    
    # Restaurar ubicación
    Set-Location -Path $originalLocation
    
}
catch {
    Write-Host "❌ Error durante la limpieza: $_" -ForegroundColor Red
    try { Set-Location -Path $originalLocation } catch {}
    exit 1
}

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║              🎉 LIMPIEZA DE LOGS COMPLETADA - MOCHOK              ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Green 