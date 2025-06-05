#region Funciones de Manejo de Estado
<#
.SYNOPSIS
    Funciones para manejo del archivo de estado JSON
    NOTA: Modificado para registrar información de la última copia realizada
#>

# Función: Inicializar o cargar archivo de estado JSON
function Get-State {
    if (-not (Test-Path -LiteralPath $(Get-StateFile))) {
        # Crear archivo con estructura de estado para última copia
        try {
            $initialState = @{
                lastExecution = @{
                    timestamp = $null
                    success = $null
                    totalConfigurations = 0
                    successfulConfigurations = 0
                    failedConfigurations = 0
                    targetDate = $null
                    duration = $null
                }
                configurationResults = @{}
                lastSuccessfulSync = @{}
                statistics = @{
                    totalExecutions = 0
                    lastSuccessDate = $null
                    consecutiveFailures = 0
                }
            }
            $initialState | ConvertTo-Json -Depth 10 | Out-File -LiteralPath $(Get-StateFile) -Encoding UTF8 -Force
        }
        catch {
            Write-Error "No se pudo crear el archivo de estado '$(Get-StateFile)': $_"
            exit 1
        }
    }
    
    # Leer JSON existente
    try {
        $jsonContent = Get-Content -LiteralPath $(Get-StateFile) -Raw -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($jsonContent)) {
            # Si el archivo está vacío, inicializar con estructura nueva
            return Initialize-EmptyState
        }
        else {
            $result = $jsonContent | ConvertFrom-Json
            
            # Verificar si es la estructura antigua (array) y migrar
            if ($result -is [System.Array]) {
                Write-Log -Message "Detectada estructura de estado antigua. Migrando a nueva estructura..." -Level "WARNING"
                return Migrate-LegacyState -LegacyState $result
            }
            
            # Verificar y completar estructura si faltan campos
            return Ensure-StateStructure -State $result
        }
    }
    catch {
        Write-Error "No se pudo leer o parsear el archivo de estado '$(Get-StateFile)': $_"
        exit 1
    }
}

# Función: Inicializar estado vacío con nueva estructura
function Initialize-EmptyState {
    return [PSCustomObject]@{
        lastExecution = [PSCustomObject]@{
            timestamp = $null
            success = $null
            totalConfigurations = 0
            successfulConfigurations = 0
            failedConfigurations = 0
            targetDate = $null
            duration = $null
        }
        configurationResults = [PSCustomObject]@{}
        lastSuccessfulSync = [PSCustomObject]@{}
        statistics = [PSCustomObject]@{
            totalExecutions = 0
            lastSuccessDate = $null
            consecutiveFailures = 0
        }
    }
}

# Función: Migrar estado legacy (array) a nueva estructura
function Migrate-LegacyState {
    param (
        [System.Array] $LegacyState
    )
    
    $newState = Initialize-EmptyState
    
    if ($LegacyState.Count -gt 0) {
        # Obtener última entrada global
        $lastEntry = $LegacyState | Sort-Object Timestamp | Select-Object -Last 1
        
        # Migrar información básica
        $newState.lastExecution.timestamp = $lastEntry.Timestamp
        $newState.lastExecution.targetDate = $lastEntry.Date
        
        # Procesar configuraciones
        $configGroups = $LegacyState | Group-Object ConfigName
        foreach ($group in $configGroups) {
            $configName = $group.Name
            $lastConfigEntry = $group.Group | Sort-Object Timestamp | Select-Object -Last 1
            
            $newState.configurationResults | Add-Member -NotePropertyName $configName -NotePropertyValue ([PSCustomObject]@{
                lastStatus = $lastConfigEntry.Status
                lastMessage = $lastConfigEntry.Message
                lastTimestamp = $lastConfigEntry.Timestamp
                lastDate = $lastConfigEntry.Date
                consecutiveFailures = 0
                localPath = ""
                s3Path = ""
                filesTransferred = 0
                duration = ""
            })
            
            # Si fue exitosa, agregar a lastSuccessfulSync
            if ($lastConfigEntry.Status -eq "Success") {
                $newState.lastSuccessfulSync | Add-Member -NotePropertyName $configName -NotePropertyValue ([PSCustomObject]@{
                    timestamp = $lastConfigEntry.Timestamp
                    date = $lastConfigEntry.Date
                    message = $lastConfigEntry.Message
                    localPath = ""
                    s3Path = ""
                    filesTransferred = 0
                    duration = ""
                })
            }
        }
        
        # Estadísticas básicas
        $newState.statistics.totalExecutions = $LegacyState.Count
        $successEntries = $LegacyState | Where-Object { $_.Status -eq "Success" }
        if ($successEntries.Count -gt 0) {
            $newState.statistics.lastSuccessDate = ($successEntries | Sort-Object Timestamp | Select-Object -Last 1).Timestamp
        }
    }
    
    Write-Log -Message "Migración de estado completada. $(($LegacyState).Count) entradas legacy procesadas."
    return $newState
}

# Función: Asegurar que la estructura del estado tenga todos los campos necesarios
function Ensure-StateStructure {
    param (
        [PSCustomObject] $State
    )
    
    # Verificar y agregar campos faltantes
    if (-not $State.PSObject.Properties["lastExecution"]) {
        $State | Add-Member -NotePropertyName "lastExecution" -NotePropertyValue (Initialize-EmptyState).lastExecution
    }
    if (-not $State.PSObject.Properties["configurationResults"]) {
        $State | Add-Member -NotePropertyName "configurationResults" -NotePropertyValue ([PSCustomObject]@{})
    }
    if (-not $State.PSObject.Properties["lastSuccessfulSync"]) {
        $State | Add-Member -NotePropertyName "lastSuccessfulSync" -NotePropertyValue ([PSCustomObject]@{})
    }
    if (-not $State.PSObject.Properties["statistics"]) {
        $State | Add-Member -NotePropertyName "statistics" -NotePropertyValue (Initialize-EmptyState).statistics
    }
    
    return $State
}

# Función: Guardar estado en JSON
function Set-State {
    param (
        [Parameter(Mandatory)]
        [PSCustomObject] $State
    )
    try {
        $State | ConvertTo-Json -Depth 10 | Out-File -LiteralPath $(Get-StateFile) -Encoding UTF8 -Force
    }
    catch {
        Write-Error "No se pudo escribir el archivo de estado '$(Get-StateFile)': $_"
    }
}

# Función: Inicializar ejecución en el estado
function Start-StateExecution {
    param (
        [datetime] $TargetDate,
        [int] $TotalConfigurations
    )
    
    $state = Get-State
    
    # Actualizar información de la ejecución actual
    $state.lastExecution.timestamp = (Get-Date).ToString("o")
    $state.lastExecution.targetDate = $TargetDate.ToString("yyyy-MM-dd")
    $state.lastExecution.totalConfigurations = $TotalConfigurations
    $state.lastExecution.successfulConfigurations = 0
    $state.lastExecution.failedConfigurations = 0
    $state.lastExecution.success = $null
    $state.lastExecution.duration = $null
    
    # Incrementar contador de ejecuciones
    $state.statistics.totalExecutions = $state.statistics.totalExecutions + 1
    
    Set-State -State $state
    return $state
}

# Función: Finalizar ejecución en el estado
function Complete-StateExecution {
    param (
        [bool] $Success,
        [timespan] $Duration
    )
    
    $state = Get-State
    
    # Actualizar resultado final de la ejecución
    $state.lastExecution.success = $Success
    $state.lastExecution.duration = $Duration.ToString("hh\:mm\:ss")
    
    # Actualizar estadísticas
    if ($Success) {
        $state.statistics.lastSuccessDate = (Get-Date).ToString("o")
        $state.statistics.consecutiveFailures = 0
    } else {
        $state.statistics.consecutiveFailures = $state.statistics.consecutiveFailures + 1
    }
    
    Set-State -State $state
}

# Función: Registrar resultado de configuración específica
function Set-ConfigurationResult {
    param (
        [string] $ConfigName,
        [string] $Status,
        [string] $Message,
        [string] $Date,
        [string] $LocalPath = "",
        [string] $S3Path = "",
        [int] $FilesTransferred = 0,
        [string] $Duration = ""
    )
    
    $state = Get-State
    $timestamp = (Get-Date).ToString("o")
    
    # Crear o actualizar resultado de configuración
    if (-not $state.configurationResults.PSObject.Properties[$ConfigName]) {
        $state.configurationResults | Add-Member -NotePropertyName $ConfigName -NotePropertyValue ([PSCustomObject]@{})
    }
    
    $configResult = [PSCustomObject]@{
        lastStatus = $Status
        lastMessage = $Message
        lastTimestamp = $timestamp
        lastDate = $Date
        localPath = $LocalPath
        s3Path = $S3Path
        filesTransferred = $FilesTransferred
        duration = $Duration
        consecutiveFailures = 0
    }
    
    # Calcular fallos consecutivos
    if ($Status -ne "Success") {
        $currentFailures = if ($state.configurationResults.$ConfigName.consecutiveFailures) { 
            $state.configurationResults.$ConfigName.consecutiveFailures 
        } else { 0 }
        $configResult.consecutiveFailures = $currentFailures + 1
        
        # Incrementar contador de fallos en ejecución actual
        $state.lastExecution.failedConfigurations = $state.lastExecution.failedConfigurations + 1
    } else {
        # Incrementar contador de éxitos en ejecución actual
        $state.lastExecution.successfulConfigurations = $state.lastExecution.successfulConfigurations + 1
        
        # Actualizar última sincronización exitosa
        if (-not $state.lastSuccessfulSync.PSObject.Properties[$ConfigName]) {
            $state.lastSuccessfulSync | Add-Member -NotePropertyName $ConfigName -NotePropertyValue ([PSCustomObject]@{})
        }
        
        $state.lastSuccessfulSync.$ConfigName = [PSCustomObject]@{
            timestamp = $timestamp
            date = $Date
            localPath = $LocalPath
            s3Path = $S3Path
            message = $Message
            filesTransferred = $FilesTransferred
            duration = $Duration
        }
    }
    
    $state.configurationResults.$ConfigName = $configResult
    Set-State -State $state
}

# Función: Obtener última sincronización exitosa para una configuración
function Get-LastSuccessfulSync {
    param (
        [string] $ConfigName
    )
    
    $state = Get-State
    
    if ($state.lastSuccessfulSync.PSObject.Properties[$ConfigName]) {
        return $state.lastSuccessfulSync.$ConfigName
    }
    
    return $null
}

# Función: Obtener resumen del estado actual
function Get-StateReport {
    $state = Get-State
    
    $report = [PSCustomObject]@{
        LastExecution = $state.lastExecution
        TotalConfigurations = ($state.configurationResults.PSObject.Properties | Measure-Object).Count
        SuccessfulConfigurations = ($state.configurationResults.PSObject.Properties | Where-Object { 
            $state.configurationResults.($_.Name).lastStatus -eq "Success" 
        } | Measure-Object).Count
        FailedConfigurations = ($state.configurationResults.PSObject.Properties | Where-Object { 
            $state.configurationResults.($_.Name).lastStatus -ne "Success" 
        } | Measure-Object).Count
        Statistics = $state.statistics
        ConfigurationDetails = $state.configurationResults
        LastSuccessfulSyncs = $state.lastSuccessfulSync
    }
    
    return $report
}

# Función: Compatibilidad con código legacy - Agregar entrada al estado
function Add-StateEntry {
    param (
        [string] $Date,
        [string] $Status,
        [string] $Message,
        [string] $ConfigName = ""
    )
    
    # Llamar a la nueva función con parámetros básicos
    Set-ConfigurationResult -ConfigName $ConfigName -Status $Status -Message $Message -Date $Date
}

#endregion 