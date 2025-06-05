<#
.SYNOPSIS
    Script para instalar prerrequisitos del sistema de sincronización AWS S3

.DESCRIPCIÓN
    Este script instala automáticamente:
    - Módulo PowerShell-Yaml (para parsear archivos YAML)
    - Verificaciones de AWS CLI
    - Configuración de permisos de ejecución
#>

Write-Host "=== Instalando prerrequisitos para AWS S3 Sync ===" -ForegroundColor Green

# Verificar y ajustar política de ejecución
$currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
if ($currentPolicy -eq "Restricted") {
    Write-Host "Ajustando política de ejecución..." -ForegroundColor Yellow
    try {
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        Write-Host "✓ Política de ejecución configurada correctamente" -ForegroundColor Green
    }
    catch {
        Write-Error "Error al configurar política de ejecución: $_"
        exit 1
    }
}
else {
    Write-Host "✓ Política de ejecución ya configurada: $currentPolicy" -ForegroundColor Green
}

# Instalar módulo PowerShell-Yaml
Write-Host "Verificando módulo PowerShell-Yaml..." -ForegroundColor Yellow
if (-not (Get-Module -ListAvailable -Name powershell-yaml)) {
    Write-Host "Instalando módulo PowerShell-Yaml..." -ForegroundColor Yellow
    try {
        Install-Module -Name powershell-yaml -Force -Scope CurrentUser -AllowClobber
        Write-Host "✓ Módulo PowerShell-Yaml instalado correctamente" -ForegroundColor Green
    }
    catch {
        Write-Error "Error al instalar módulo PowerShell-Yaml: $_"
        Write-Host "Instálelo manualmente ejecutando: Install-Module powershell-yaml" -ForegroundColor Red
        exit 1
    }
}
else {
    Write-Host "✓ Módulo PowerShell-Yaml ya está instalado" -ForegroundColor Green
}

# Verificar AWS CLI
Write-Host "Verificando AWS CLI..." -ForegroundColor Yellow
if (Get-Command "aws" -ErrorAction SilentlyContinue) {
    $awsVersion = aws --version 2>&1
    Write-Host "✓ AWS CLI encontrado: $awsVersion" -ForegroundColor Green
    
    # Verificar configuración básica de AWS
    try {
        aws sts get-caller-identity *>$null
        if ($?) {
            Write-Host "✓ AWS CLI configurado correctamente" -ForegroundColor Green
        }
        else {
            Write-Host "⚠ AWS CLI instalado pero no configurado. Ejecute: aws configure" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "⚠ No se pudo verificar la configuración de AWS CLI" -ForegroundColor Yellow
    }
}
else {
    Write-Host "✗ AWS CLI no encontrado" -ForegroundColor Red
    Write-Host "Descargue e instale AWS CLI desde: https://aws.amazon.com/cli/" -ForegroundColor Yellow
    Write-Host "Después de instalarlo, ejecute: aws configure" -ForegroundColor Yellow
}

# Verificar archivo de configuración
$configFile = Join-Path $PSScriptRoot "sync-config.yaml"
if (Test-Path $configFile) {
    Write-Host "✓ Archivo de configuración encontrado: sync-config.yaml" -ForegroundColor Green
}
else {
    Write-Host "⚠ Archivo de configuración no encontrado. Se creará con valores de ejemplo." -ForegroundColor Yellow
}

Write-Host "`n=== Instalación de prerrequisitos completada ===" -ForegroundColor Green
Write-Host "Pasos siguientes:" -ForegroundColor White
Write-Host "1. Configure AWS CLI si no está configurado: aws configure" -ForegroundColor White
Write-Host "2. Edite el archivo sync-config.yaml con sus configuraciones" -ForegroundColor White
Write-Host "3. Ejecute el script: .\sync-main.ps1" -ForegroundColor White 