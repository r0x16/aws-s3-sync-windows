#region Funciones de Manejo de Estado
<#
.SYNOPSIS
    Funciones para manejo del archivo de estado JSON
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
            
            # Verificar y completar estructura si faltan campos
            return Confirm-StateStructure -State $result
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



# Función: Confirmar que la estructura del estado tenga todos los campos necesarios
function Confirm-StateStructure {
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



#endregion 