<#
.SYNOPSIS
    Mochok - Sistema de sincronización AWS S3 con múltiples comandos

.DESCRIPCIÓN
    Mochok es un sistema completo para sincronización de archivos con AWS S3.
    Proporciona múltiples comandos para gestionar sincronizaciones, ver estado, configurar estrategias y más.

.PARAMETER Command
    Comando a ejecutar. Comandos disponibles:
    - sync: Ejecuta la sincronización principal (anteriormente sync-main.ps1)
    - strategies: Muestra información sobre estrategias de sincronización disponibles
    - status: Muestra el estado actual de las sincronizaciones
    - install: Instala prerrequisitos del sistema
    - clear logs: Limpia los archivos de log

.PARAMETER TargetDate
    Fecha específica para sincronizar (solo para comando 'sync'). Por defecto es el día anterior.

.PARAMETER ShowExamples
    Muestra ejemplos detallados (solo para comando 'strategies')

.PARAMETER OnlyLastExecution
    Muestra solo información de la última ejecución (solo para comando 'status')

.PARAMETER JsonOutput
    Salida en formato JSON (solo para comando 'status')

.PARAMETER RemoveDirectory
    Intenta eliminar también el directorio de logs (solo para comando 'clear logs')

.PARAMETER KeepLastDays
    Mantiene los logs de los últimos N días (solo para comando 'clear logs')

.EXAMPLE
    .\mochok.ps1 sync
    Ejecuta la sincronización principal

.EXAMPLE
    .\mochok.ps1 strategies -ShowExamples
    Muestra estrategias de sincronización con ejemplos

.EXAMPLE
    .\mochok.ps1 status
    Muestra el estado actual de las sincronizaciones

.EXAMPLE
    .\mochok.ps1 install
    Instala los prerrequisitos del sistema

.EXAMPLE
    .\mochok.ps1 "clear logs"
    Limpia todos los archivos de log
#>

param(
    [Parameter(Position=0, Mandatory=$true)]
    [string] $Command,
    
    # Parámetros para comando 'sync'
    [datetime] $TargetDate = (Get-Date).AddDays(-1),
    
    # Parámetros para comando 'strategies'
    [switch] $ShowExamples,
    
    # Parámetros para comando 'status'
    [switch] $OnlyLastExecution,
    [switch] $JsonOutput,
    
    # Parámetros para comando 'clear logs'
    [switch] $RemoveDirectory,
    [int] $KeepLastDays = 0
)

function Show-MochokHeader {
    Write-Host "╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                                                                  ║" -ForegroundColor Cyan
    Write-Host "║                            🌟 MOCHOK 🌟                          ║" -ForegroundColor Cyan
    Write-Host "║                     Sistema de Sincronización AWS S3            ║" -ForegroundColor Cyan
    Write-Host "║                                                                  ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Show-Help {
    Show-MochokHeader
    Write-Host "🔧 COMANDOS DISPONIBLES:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "   sync              - Ejecuta la sincronización principal" -ForegroundColor White
    Write-Host "   strategies        - Muestra estrategias de sincronización disponibles" -ForegroundColor White
    Write-Host "   status           - Muestra el estado actual de las sincronizaciones" -ForegroundColor White
    Write-Host "   install          - Instala prerrequisitos del sistema" -ForegroundColor White
    Write-Host "   'clear logs'     - Limpia los archivos de log" -ForegroundColor White
    Write-Host ""
    Write-Host "💡 EJEMPLOS:" -ForegroundColor Yellow
    Write-Host "   .\mochok.ps1 sync" -ForegroundColor Gray
    Write-Host "   .\mochok.ps1 strategies -ShowExamples" -ForegroundColor Gray
    Write-Host "   .\mochok.ps1 status" -ForegroundColor Gray
    Write-Host "   .\mochok.ps1 install" -ForegroundColor Gray
    Write-Host "   .\mochok.ps1 'clear logs'" -ForegroundColor Gray
    Write-Host ""
    Write-Host "📖 Para ayuda específica de un comando:" -ForegroundColor Yellow
    Write-Host "   Get-Help .\mochok.ps1 -Parameter Command" -ForegroundColor Gray
    Write-Host ""
}

# Normalizar el comando y manejar espacios
$normalizedCommand = $Command.ToLower().Trim()

# Validar comando
$validCommands = @("sync", "strategies", "status", "install", "clear logs", "help")
if ($normalizedCommand -notin $validCommands) {
    Show-MochokHeader
    Write-Host "❌ Error: Comando '$Command' no reconocido." -ForegroundColor Red
    Write-Host ""
    Show-Help
    exit 1
}

# Mostrar ayuda si se solicita
if ($normalizedCommand -eq "help") {
    Show-Help
    exit 0
}

# Ejecutar el comando correspondiente
try {
    switch ($normalizedCommand) {
        "sync" {
            Show-MochokHeader
            Write-Host "🔄 Ejecutando sincronización..." -ForegroundColor Green
            Write-Host ""
            & (Join-Path $PSScriptRoot "src\commands\sync.ps1") -TargetDate $TargetDate
        }
        
        "strategies" {
            Show-MochokHeader
            Write-Host "📋 Mostrando estrategias de sincronización..." -ForegroundColor Green
            Write-Host ""
            if ($ShowExamples) {
                & (Join-Path $PSScriptRoot "src\commands\strategies.ps1") -ShowExamples
            } else {
                & (Join-Path $PSScriptRoot "src\commands\strategies.ps1")
            }
        }
        
        "status" {
            Show-MochokHeader
            Write-Host "📊 Mostrando estado del sistema..." -ForegroundColor Green
            Write-Host ""
            $statusParams = @{}
            if ($OnlyLastExecution) { $statusParams.OnlyLastExecution = $true }
            if ($JsonOutput) { $statusParams.JsonOutput = $true }
            & (Join-Path $PSScriptRoot "src\commands\status.ps1") @statusParams
        }
        
        "install" {
            Show-MochokHeader
            Write-Host "⚙️ Instalando prerrequisitos..." -ForegroundColor Green
            Write-Host ""
            & (Join-Path $PSScriptRoot "src\commands\install.ps1")
        }
        
        "clear logs" {
            Show-MochokHeader
            Write-Host "🧹 Limpiando logs..." -ForegroundColor Green
            Write-Host ""
            $cleanParams = @{}
            if ($RemoveDirectory) { $cleanParams.RemoveDirectory = $true }
            if ($KeepLastDays -gt 0) { $cleanParams.KeepLastDays = $KeepLastDays }
            & (Join-Path $PSScriptRoot "src\commands\clear-logs.ps1") @cleanParams
        }
    }
}
catch {
    Write-Host "❌ Error ejecutando comando '$Command': $_" -ForegroundColor Red
    exit 1
} 