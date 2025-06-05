<#
.SYNOPSIS
    Comando install para Mochok - Instala prerrequisitos del sistema

.DESCRIPCIÓN
    Este comando instala automáticamente los prerrequisitos necesarios para Mochok:
    - Módulo PowerShell-Yaml (para parsear archivos YAML)
    - Verificaciones de AWS CLI
    - Configuración de permisos de ejecución
#>

# Obtener la ruta raíz del proyecto (dos niveles arriba desde src/commands)
$ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

Write-Host "╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                                                                  ║" -ForegroundColor Green
Write-Host "║            🌟 MOCHOK - INSTALADOR DE PRERREQUISITOS 🌟          ║" -ForegroundColor Green
Write-Host "║                                                                  ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

# Verificar y ajustar política de ejecución
$currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
if ($currentPolicy -ne "RemoteSigned") {
    Write-Host "⚙️ Ajustando política de ejecución desde '$currentPolicy' a 'RemoteSigned'..." -ForegroundColor Yellow
    try {
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        Write-Host "✅ Política de ejecución configurada correctamente a RemoteSigned" -ForegroundColor Green
    }
    catch {
        Write-Error "❌ Error al configurar política de ejecución: $_"
        Write-Host "💡 Ejecute PowerShell como administrador y vuelva a intentar" -ForegroundColor Yellow
        exit 1
    }
}
else {
    Write-Host "✅ Política de ejecución ya configurada: $currentPolicy" -ForegroundColor Green
}

# Instalar módulo PowerShell-Yaml
Write-Host "🔍 Verificando módulo PowerShell-Yaml..." -ForegroundColor Yellow
if (-not (Get-Module -ListAvailable -Name powershell-yaml)) {
    Write-Host "📦 Instalando módulo PowerShell-Yaml..." -ForegroundColor Yellow
    try {
        Install-Module -Name powershell-yaml -Force -Scope CurrentUser -AllowClobber
        Write-Host "✅ Módulo PowerShell-Yaml instalado correctamente" -ForegroundColor Green
    }
    catch {
        Write-Error "❌ Error al instalar módulo PowerShell-Yaml: $_"
        Write-Host "💡 Instálelo manualmente ejecutando: Install-Module powershell-yaml" -ForegroundColor Red
        exit 1
    }
}
else {
    Write-Host "✅ Módulo PowerShell-Yaml ya está instalado" -ForegroundColor Green
}

# Verificar AWS CLI
Write-Host "🔍 Verificando AWS CLI..." -ForegroundColor Yellow
if (Get-Command "aws" -ErrorAction SilentlyContinue) {
    $awsVersion = aws --version 2>&1
    Write-Host "✅ AWS CLI encontrado: $awsVersion" -ForegroundColor Green
    
    # Verificar configuración básica de AWS
    try {
        aws sts get-caller-identity *>$null
        if ($?) {
            Write-Host "✅ AWS CLI configurado correctamente" -ForegroundColor Green
        }
        else {
            Write-Host "⚠️  AWS CLI instalado pero no configurado. Ejecute: aws configure" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "⚠️  No se pudo verificar la configuración de AWS CLI" -ForegroundColor Yellow
    }
}
else {
    Write-Host "❌ AWS CLI no encontrado" -ForegroundColor Red
    Write-Host "💡 Descargue e instale AWS CLI desde: https://aws.amazon.com/cli/" -ForegroundColor Yellow
    Write-Host "💡 Después de instalarlo, ejecute: aws configure" -ForegroundColor Yellow
}

# Verificar archivo de configuración
$configFile = Join-Path $ProjectRoot "sync-config.yaml"

if (Test-Path $configFile) {
    Write-Host "✅ Archivo de configuración encontrado: sync-config.yaml" -ForegroundColor Green
}
else {
    Write-Host "⚠️  Archivo de configuración no encontrado. Creando archivo de ejemplo..." -ForegroundColor Yellow
    
    # Crear archivo de configuración básico
    $basicConfig = @"
# Configuración de Sincronización Mochok
# Este archivo permite configurar múltiples tareas de sincronización

# Configuración global
global:
  # Retención de logs en meses
  log_retention_months: 12
  # Carpeta base para logs (relativa al script)
  log_directory: "log"
  # Archivo de estado (relativo al script)
  state_file: "state.json"

# Configuraciones de sincronización
sync_configurations:
- name: "Documentos Ejemplo"
  description: "Configuración de ejemplo para sincronización con Mochok"
  enabled: false # Cambiar a true para habilitar
  local_base_path: "C:\\Ruta\\Local\\Ejemplo"
  bucket_name: "mi-bucket-ejemplo"
  aws_profile: "default"
  s3_path_structure: "{year}/{month}/{day}"
  date_folder_format: "yyyy-MM-dd"
  sync_options:
  - "--exclude=*.tmp"
  - "--exclude=*.log"
"@
    
    try {
        $basicConfig | Out-File -FilePath $configFile -Encoding UTF8
        Write-Host "✅ Archivo de configuración creado: sync-config.yaml" -ForegroundColor Green
        Write-Host "💡 Edite el archivo para configurar sus rutas y buckets específicos" -ForegroundColor Yellow
    }
    catch {
        Write-Error "❌ Error al crear archivo de configuración: $_"
    }
}

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║              🎉 INSTALACIÓN DE PRERREQUISITOS COMPLETADA         ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "📋 PASOS SIGUIENTES:" -ForegroundColor White
Write-Host "1. Configure AWS CLI si no está configurado: aws configure" -ForegroundColor White
Write-Host "2. Edite el archivo sync-config.yaml con sus configuraciones" -ForegroundColor White
Write-Host "3. Ejecute Mochok: .\mochok.ps1 sync" -ForegroundColor White
Write-Host ""
Write-Host "💡 Para ver todos los comandos disponibles: .\mochok.ps1 help" -ForegroundColor Yellow 