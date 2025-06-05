#region Configuración Global
# Configuración para el script de sincronización AWS S3

# Clase para almacenar la configuración
class SyncConfiguration {
    [string]$ConfigFile
    [int]$LogRetentionMonths
    [string]$LogDir
    [string]$StateFile
    [array]$SyncConfigurations
    
    SyncConfiguration([string]$ScriptRoot) {
        $this.ConfigFile = Join-Path $ScriptRoot "sync-config.yaml"
        $this.LogRetentionMonths = 12
        $this.LogDir = Join-Path $ScriptRoot "log"
        $this.StateFile = Join-Path $ScriptRoot "state.json"
        $this.SyncConfigurations = @()
    }
}

# Variable para almacenar la configuración cargada
$script:LoadedConfig = $null

# Función: Obtener o crear la instancia de configuración
function Get-SyncConfig {
    param(
        [string]$ScriptRoot = $PSScriptRoot
    )
    
    if ($null -eq $script:LoadedConfig) {
        $script:LoadedConfig = [SyncConfiguration]::new($ScriptRoot)
    }
    
    return $script:LoadedConfig
}

# Función: Cargar configuración desde archivo YAML
function Import-YamlConfig {
    param(
        [string]$ScriptRoot = $PSScriptRoot
    )
    
    $config = Get-SyncConfig -ScriptRoot $ScriptRoot
    
    if (-not (Test-Path -LiteralPath $config.ConfigFile)) {
        Write-Error "Archivo de configuración no encontrado: $($config.ConfigFile)"
        exit 1
    }
    
    try {
        # Leer contenido del archivo YAML
        $yamlContent = Get-Content -LiteralPath $config.ConfigFile -Raw -Encoding UTF8
        
        # Convertir YAML a PowerShell object usando ConvertFrom-Yaml (requiere módulo powershell-yaml)
        if (-not (Get-Module -ListAvailable -Name powershell-yaml)) {
            Write-Warning "Módulo 'powershell-yaml' no encontrado. Intentando instalarlo..."
            try {
                Install-Module -Name powershell-yaml -Force -Scope CurrentUser
                Import-Module powershell-yaml
            }
            catch {
                Write-Error "No se pudo instalar el módulo 'powershell-yaml'. Instálelo manualmente: Install-Module powershell-yaml"
                exit 1
            }
        }
        else {
            Import-Module powershell-yaml
        }
        
        $yamlConfig = ConvertFrom-Yaml -Yaml $yamlContent
        
        # Cargar configuración global
        if ($yamlConfig.global) {
            if ($yamlConfig.global.log_retention_months) {
                $config.LogRetentionMonths = $yamlConfig.global.log_retention_months
            }
            if ($yamlConfig.global.log_directory) {
                $config.LogDir = Join-Path $ScriptRoot $yamlConfig.global.log_directory
            }
            if ($yamlConfig.global.state_file) {
                $config.StateFile = Join-Path $ScriptRoot $yamlConfig.global.state_file
            }
        }
        
        # Cargar configuraciones de sincronización
        if ($yamlConfig.sync_configurations) {
            $config.SyncConfigurations = $yamlConfig.sync_configurations | Where-Object { $_.enabled -eq $true }
        }
        
        Write-Verbose "Configuración cargada exitosamente. $(($config.SyncConfigurations).Count) configuraciones habilitadas."
        
        return $config
    }
    catch {
        Write-Error "Error al cargar configuración YAML: $_"
        exit 1
    }
}

# Función: Obtener configuraciones habilitadas
function Get-EnabledSyncConfigurations {
    $config = Get-SyncConfig
    return $config.SyncConfigurations
}

# Función: Obtener directorio de logs
function Get-LogDirectory {
    $config = Get-SyncConfig
    return $config.LogDir
}

# Función: Obtener período de retención de logs
function Get-LogRetentionMonths {
    $config = Get-SyncConfig
    return $config.LogRetentionMonths
}

# Función: Obtener archivo de estado
function Get-StateFile {
    $config = Get-SyncConfig
    return $config.StateFile
}

# Función: Obtener archivo de configuración
function Get-ConfigFile {
    $config = Get-SyncConfig
    return $config.ConfigFile
}
#endregion 