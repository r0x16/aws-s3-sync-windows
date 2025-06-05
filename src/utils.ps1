#region Funciones de Utilidad
<#
.SYNOPSIS
    Funciones de utilidad para el script de sincronización AWS S3
#>

# Función: Asegurar existencia de carpeta (crea si no existe)
function Test-AndCreateFolder {
    param (
        [string] $Path
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        try {
            New-Item -ItemType Directory -Path $Path -ErrorAction Stop | Out-Null
        }
        catch {
            Write-Error "Error al crear carpeta '$Path': $_"
            exit 1
        }
    }
}

# Función: Verificar existencia de AWS CLI
function Test-AwsCli {
    return ($null -ne (Get-Command "aws" -ErrorAction SilentlyContinue))
}

# Función: Construir rutas de sincronización para una configuración específica
function Get-SyncPaths {
    param (
        [datetime] $Date,
        [PSCustomObject] $SyncConfig
    )
    
    # Obtener la estrategia de sincronización (por defecto: DateFolder)
    $strategyType = if ($SyncConfig.sync_strategy -and $SyncConfig.sync_strategy.type) { 
        $SyncConfig.sync_strategy.type 
    } elseif ($SyncConfig.sync_mode) { 
        # Compatibilidad hacia atrás
        $SyncConfig.sync_mode 
    } else { 
        "DateFolder" 
    }
    
    Write-Log -Message "[$($SyncConfig.name)] Estrategia de sincronización: $strategyType"
    
    switch ($strategyType) {
        "DateFolder" {
            return Get-DateFolderSyncPaths -Date $Date -SyncConfig $SyncConfig
        }
        "FullDirectory" {
            return Get-FullDirectorySyncPaths -Date $Date -SyncConfig $SyncConfig
        }
        "DateRange" {
            return Get-DateRangeSyncPaths -Date $Date -SyncConfig $SyncConfig
        }
        "CustomPattern" {
            return Get-CustomPatternSyncPaths -Date $Date -SyncConfig $SyncConfig
        }
        default {
            Write-Log -Message "[$($SyncConfig.name)] Estrategia de sincronización no reconocida '$strategyType', usando 'DateFolder' por defecto" -Level "WARNING"
            return Get-DateFolderSyncPaths -Date $Date -SyncConfig $SyncConfig
        }
    }
}

# Función: Estrategia DateFolder - Sincronizar carpeta específica del día (estrategia original)
function Get-DateFolderSyncPaths {
    param (
        [datetime] $Date,
        [PSCustomObject] $SyncConfig
    )
    
    $year = $Date.ToString("yyyy")
    $month = $Date.ToString("MM")
    
    # Usar el formato de fecha especificado en la configuración
    $dateFormat = if ($SyncConfig.sync_strategy -and $SyncConfig.sync_strategy.date_folder_format) { 
        $SyncConfig.sync_strategy.date_folder_format 
    } elseif ($SyncConfig.mode_config -and $SyncConfig.mode_config.date_folder_format) { 
        # Compatibilidad hacia atrás
        $SyncConfig.mode_config.date_folder_format 
    } else { 
        "yyyy-MM-dd" 
    }
    $dayFolderName = $Date.ToString($dateFormat)
    
    # Construir ruta local
    $localFolderPath = Join-Path $SyncConfig.local_base_path $dayFolderName
    
    # Construir estructura S3 personalizada
    $s3Structure = if ($SyncConfig.destination_config -and $SyncConfig.destination_config.s3_path_structure) { 
        $SyncConfig.destination_config.s3_path_structure 
    } elseif ($SyncConfig.s3_path_structure) { 
        # Compatibilidad hacia atrás
        $SyncConfig.s3_path_structure 
    } else { 
        "{year}/{month}/{day}" 
    }
    
    # Reemplazar placeholders en la estructura S3
    $s3Structure = $s3Structure -replace '\{year\}', $year
    $s3Structure = $s3Structure -replace '\{month\}', $month
    $s3Structure = $s3Structure -replace '\{day\}', $dayFolderName
    
    # Obtener bucket name
    $bucketName = if ($SyncConfig.destination_config -and $SyncConfig.destination_config.bucket_name) { 
        $SyncConfig.destination_config.bucket_name 
    } else { 
        $SyncConfig.bucket_name 
    }
    
    $s3Destination = "s3://$bucketName/$s3Structure"
    
    return @{
        LocalPath = $localFolderPath
        S3Path = $s3Destination
        DayFolder = $dayFolderName
        ConfigName = $SyncConfig.name
        StrategyType = "DateFolder"
    }
}

# Función: Estrategia FullDirectory - Sincronizar toda la carpeta base
function Get-FullDirectorySyncPaths {
    param (
        [datetime] $Date,
        [PSCustomObject] $SyncConfig
    )
    
    $year = $Date.ToString("yyyy")
    $month = $Date.ToString("MM")
    $day = $Date.ToString("dd")
    
    # Ruta local es la carpeta base completa
    $localFolderPath = $SyncConfig.local_base_path
    
    # Construir estructura S3 (usando la fecha para organización)
    $s3Structure = if ($SyncConfig.destination_config -and $SyncConfig.destination_config.s3_path_structure) { 
        $SyncConfig.destination_config.s3_path_structure 
    } elseif ($SyncConfig.s3_path_structure) { 
        # Compatibilidad hacia atrás
        $SyncConfig.s3_path_structure 
    } else { 
        "full-backup/{year}/{month}"
    }
    
    # Reemplazar placeholders en la estructura S3
    $s3Structure = $s3Structure -replace '\{year\}', $year
    $s3Structure = $s3Structure -replace '\{month\}', $month
    $s3Structure = $s3Structure -replace '\{day\}', $day
    
    # Obtener bucket name
    $bucketName = if ($SyncConfig.destination_config -and $SyncConfig.destination_config.bucket_name) { 
        $SyncConfig.destination_config.bucket_name 
    } else { 
        $SyncConfig.bucket_name 
    }
    
    $s3Destination = "s3://$bucketName/$s3Structure"
    
    return @{
        LocalPath = $localFolderPath
        S3Path = $s3Destination
        DayFolder = "full-directory"
        ConfigName = $SyncConfig.name
        StrategyType = "FullDirectory"
    }
}

# Función: Estrategia DateRange - Sincronizar un rango de fechas
function Get-DateRangeSyncPaths {
    param (
        [datetime] $Date,
        [PSCustomObject] $SyncConfig
    )
    
    # Obtener configuración del rango de fechas
    $daysBack = if ($SyncConfig.sync_strategy -and $SyncConfig.sync_strategy.date_range_days_back) { 
        $SyncConfig.sync_strategy.date_range_days_back 
    } elseif ($SyncConfig.mode_config -and $SyncConfig.mode_config.date_range_days_back) { 
        # Compatibilidad hacia atrás
        $SyncConfig.mode_config.date_range_days_back 
    } else { 
        7 
    }
    $startDate = $Date.AddDays(-$daysBack)
    
    $year = $Date.ToString("yyyy")
    $month = $Date.ToString("MM")
    $day = $Date.ToString("dd")
    
    Write-Log -Message "[$($SyncConfig.name)] Rango de fechas: desde $($startDate.ToString('yyyy-MM-dd')) hasta $($Date.ToString('yyyy-MM-dd'))"
    
    # Para DateRange, sincronizamos la carpeta base pero con filtros específicos
    $localFolderPath = $SyncConfig.local_base_path
    
    # Construir estructura S3
    $s3Structure = if ($SyncConfig.destination_config -and $SyncConfig.destination_config.s3_path_structure) { 
        $SyncConfig.destination_config.s3_path_structure 
    } elseif ($SyncConfig.s3_path_structure) { 
        # Compatibilidad hacia atrás
        $SyncConfig.s3_path_structure 
    } else { 
        "date-range/{year}/{month}"
    }
    
    # Reemplazar placeholders en la estructura S3
    $s3Structure = $s3Structure -replace '\{year\}', $year
    $s3Structure = $s3Structure -replace '\{month\}', $month
    $s3Structure = $s3Structure -replace '\{day\}', $day
    
    # Obtener bucket name
    $bucketName = if ($SyncConfig.destination_config -and $SyncConfig.destination_config.bucket_name) { 
        $SyncConfig.destination_config.bucket_name 
    } else { 
        $SyncConfig.bucket_name 
    }
    
    $s3Destination = "s3://$bucketName/$s3Structure"
    
    return @{
        LocalPath = $localFolderPath
        S3Path = $s3Destination
        DayFolder = "date-range-$($daysBack)days"
        ConfigName = $SyncConfig.name
        StrategyType = "DateRange"
        StartDate = $startDate
        EndDate = $Date
        DaysBack = $daysBack
    }
}

# Función: Estrategia CustomPattern - Sincronizar basado en un patrón personalizado
function Get-CustomPatternSyncPaths {
    param (
        [datetime] $Date,
        [PSCustomObject] $SyncConfig
    )
    
    $year = $Date.ToString("yyyy")
    $month = $Date.ToString("MM")
    $day = $Date.ToString("dd")
    
    # Obtener patrón personalizado de carpeta local
    $customPattern = if ($SyncConfig.sync_strategy -and $SyncConfig.sync_strategy.custom_local_pattern) { 
        $SyncConfig.sync_strategy.custom_local_pattern 
    } elseif ($SyncConfig.mode_config -and $SyncConfig.mode_config.custom_local_pattern) { 
        # Compatibilidad hacia atrás
        $SyncConfig.mode_config.custom_local_pattern 
    } else { 
        "{base_path}" 
    }
    
    # Reemplazar placeholders en el patrón local
    $localPattern = $customPattern -replace '\{base_path\}', $SyncConfig.local_base_path
    $localPattern = $localPattern -replace '\{year\}', $year
    $localPattern = $localPattern -replace '\{month\}', $month
    $localPattern = $localPattern -replace '\{day\}', $day
    
    # Construir estructura S3
    $s3Structure = if ($SyncConfig.destination_config -and $SyncConfig.destination_config.s3_path_structure) { 
        $SyncConfig.destination_config.s3_path_structure 
    } elseif ($SyncConfig.s3_path_structure) { 
        # Compatibilidad hacia atrás
        $SyncConfig.s3_path_structure 
    } else { 
        "custom/{year}/{month}/{day}"
    }
    
    # Reemplazar placeholders en la estructura S3
    $s3Structure = $s3Structure -replace '\{year\}', $year
    $s3Structure = $s3Structure -replace '\{month\}', $month
    $s3Structure = $s3Structure -replace '\{day\}', $day
    
    # Obtener bucket name
    $bucketName = if ($SyncConfig.destination_config -and $SyncConfig.destination_config.bucket_name) { 
        $SyncConfig.destination_config.bucket_name 
    } else { 
        $SyncConfig.bucket_name 
    }
    
    $s3Destination = "s3://$bucketName/$s3Structure"
    
    return @{
        LocalPath = $localPattern
        S3Path = $s3Destination
        DayFolder = "custom-pattern"
        ConfigName = $SyncConfig.name
        StrategyType = "CustomPattern"
    }
}

# Función: Validar configuración de estrategia de sincronización
function Test-SyncStrategyConfiguration {
    param (
        [PSCustomObject] $SyncConfig
    )
    
    # Obtener tipo de estrategia con compatibilidad hacia atrás
    $strategyType = if ($SyncConfig.sync_strategy -and $SyncConfig.sync_strategy.type) { 
        $SyncConfig.sync_strategy.type 
    } elseif ($SyncConfig.sync_mode) { 
        $SyncConfig.sync_mode 
    } else { 
        "DateFolder" 
    }
    
    $issues = @()
    
    switch ($strategyType) {
        "DateFolder" {
            # Validaciones para estrategia DateFolder
            if (-not $SyncConfig.local_base_path) {
                $issues += "local_base_path es requerido para estrategia DateFolder"
            }
        }
        "FullDirectory" {
            # Validaciones para estrategia FullDirectory
            if (-not $SyncConfig.local_base_path) {
                $issues += "local_base_path es requerido para estrategia FullDirectory"
            }
        }
        "DateRange" {
            # Validaciones para estrategia DateRange
            if (-not $SyncConfig.local_base_path) {
                $issues += "local_base_path es requerido para estrategia DateRange"
            }
            
            # Verificar configuración específica de DateRange
            $daysBack = if ($SyncConfig.sync_strategy -and $SyncConfig.sync_strategy.date_range_days_back) { 
                $SyncConfig.sync_strategy.date_range_days_back 
            } elseif ($SyncConfig.mode_config -and $SyncConfig.mode_config.date_range_days_back) { 
                $SyncConfig.mode_config.date_range_days_back 
            } else { 
                $null 
            }
            
            if ($daysBack -and $daysBack -lt 1) {
                $issues += "sync_strategy.date_range_days_back debe ser mayor a 0 para estrategia DateRange"
            }
        }
        "CustomPattern" {
            # Validaciones para estrategia CustomPattern
            $hasCustomPattern = ($SyncConfig.sync_strategy -and $SyncConfig.sync_strategy.custom_local_pattern) -or 
                              ($SyncConfig.mode_config -and $SyncConfig.mode_config.custom_local_pattern)
            
            if (-not $hasCustomPattern -and -not $SyncConfig.local_base_path) {
                $issues += "sync_strategy.custom_local_pattern o local_base_path es requerido para estrategia CustomPattern"
            }
        }
        default {
            $issues += "Estrategia de sincronización '$strategyType' no es válida. Estrategias válidas: DateFolder, FullDirectory, DateRange, CustomPattern"
        }
    }
    
    return @{
        IsValid = ($issues.Count -eq 0)
        Issues = $issues
        StrategyType = $strategyType
    }
}

# Función: Ejecutar comando AWS S3 Sync con opciones personalizadas
function Invoke-S3Sync {
    param (
        [string] $LocalPath,
        [string] $S3Path,
        [string[]] $SyncOptions = @(),
        [string] $AwsProfile = "default"
    )
    
    try {
        # Construir comando base
        $syncCommand = "aws s3 sync"
        
        # Agregar profile si no es "default"
        if ($AwsProfile -and $AwsProfile -ne "default") {
            $syncCommand += " --profile `"$AwsProfile`""
        }
        
        # Agregar rutas
        $syncCommand += " `"$LocalPath`" `"$S3Path`""
        
        # Agregar opciones adicionales si existen
        if ($SyncOptions -and $SyncOptions.Count -gt 0) {
            $optionsString = $SyncOptions -join " "
            $syncCommand += " $optionsString"
        }
        
        Write-Log -Message "Ejecutando comando AWS S3: $syncCommand"
        $output = Invoke-Expression -Command $syncCommand 2>&1
        $success = $?

        return @{
            Success = $success
            ExitCode = if ($success) { 0 } else { 1 }
            Output = $output
            Command = $syncCommand
        }
    }
    catch {
        return @{
            Success = $false
            ExitCode = -1
            Output = $_.Exception.Message
            Command = $syncCommand
        }
    }
}

# Función: Verificar si un bucket S3 existe
function Test-S3Bucket {
    param (
        [string] $BucketName,
        [string] $AwsProfile = "default"
    )
    
    try {
        # Construir comando para verificar bucket usando aws s3 ls
        $command = "aws s3 ls s3://$BucketName/"
        
        # Agregar profile si no es "default"
        if ($AwsProfile -and $AwsProfile -ne "default") {
            $command += " --profile `"$AwsProfile`""
        }
        
        Write-Log -Message "Verificando existencia del bucket: $BucketName"
        Write-Log -Message "Ejecutando comando AWS: $command"
        
        # Capturar tanto stdout como stderr por separado
        $outputResult = & cmd /c "$command 2>&1"
        $exitCode = $LASTEXITCODE
        
        Write-Log -Message "Código de salida: $exitCode"
        Write-Log -Message "Output del comando: $($outputResult -join ' | ')"
        
        # Verificar si hay errores específicos de AWS
        $outputString = $outputResult -join " "
        $bucketExists = $true
        
        if ($exitCode -ne 0) {
            $bucketExists = $false
            Write-Log -Message "Comando falló con código de salida: $exitCode"
        }
        
        # Verificar errores específicos en el output
        if ($outputString -match "NoSuchBucket" -or 
            $outputString -match "does not exist" -or
            $outputString -match "AccessDenied.*bucket.*not.*exist" -or
            $outputString -match "The specified bucket does not exist") {
            $bucketExists = $false
            Write-Log -Message "Bucket no existe - detectado por contenido del error: $outputString"
        }
        
        # Si no hay errores y el código de salida es 0, el bucket existe
        if ($exitCode -eq 0 -and -not ($outputString -match "error|Error|ERROR")) {
            $bucketExists = $true
            Write-Log -Message "Bucket existe - comando exitoso sin errores"
        }
        
        return @{
            Exists = $bucketExists
            Output = $outputResult
            Command = $command
            ExitCode = $exitCode
        }
    }
    catch {
        Write-Log -Message "Excepción al verificar bucket: $_" -Level "ERROR"
        return @{
            Exists = $false
            Output = $_.Exception.Message
            Command = $command
            ExitCode = -1
        }
    }
}

# Función: Crear bucket S3 si no existe
function New-S3Bucket {
    param (
        [string] $BucketName,
        [string] $AwsProfile = "default",
        [string] $Region = $null
    )
    
    try {
        # Determinar región
        if (-not $Region) {
            # Intentar obtener región por defecto del profile
            try {
                $regionCommand = "aws configure get region"
                if ($AwsProfile -and $AwsProfile -ne "default") {
                    $regionCommand += " --profile `"$AwsProfile`""
                }
                Write-Log -Message "Ejecutando comando AWS para obtener región: $regionCommand"
                $Region = Invoke-Expression -Command $regionCommand 2>$null
                Write-Log -Message "Región detectada: $Region"
                if (-not $Region) {
                    $Region = "us-east-1"  # Región por defecto
                    Write-Log -Message "No se detectó región, usando por defecto: $Region"
                }
            }
            catch {
                $Region = "us-east-1"
                Write-Log -Message "Error al detectar región, usando por defecto: $Region"
            }
        }
        
        # Construir comando para crear bucket usando aws s3 mb
        $command = "aws s3 mb s3://$BucketName"
        
        # Agregar profile si no es "default"
        if ($AwsProfile -and $AwsProfile -ne "default") {
            $command += " --profile `"$AwsProfile`""
        }
        
        # Agregar región
        if ($Region) {
            $command += " --region `"$Region`""
        }
        
        Write-Log -Message "Creando bucket S3: $BucketName en región: $Region"
        Write-Log -Message "Ejecutando comando AWS: $command"
        $output = Invoke-Expression -Command $command 2>&1
        $success = $?
        Write-Log -Message "Resultado del comando (éxito: $success): $($output -join ' ')"
        
        if ($success) {
            Write-Log -Message "Bucket '$BucketName' creado exitosamente en la región '$Region'"
            
            # Opcional: Configurar versionado y cifrado por defecto usando aws s3api para estas configuraciones específicas
            try {
                # Habilitar versionado
                $versionCommand = "aws s3api put-bucket-versioning --bucket `"$BucketName`" --versioning-configuration Status=Enabled"
                if ($AwsProfile -and $AwsProfile -ne "default") {
                    $versionCommand += " --profile `"$AwsProfile`""
                }
                Write-Log -Message "Ejecutando comando AWS para versionado: $versionCommand"
                $versionOutput = Invoke-Expression -Command $versionCommand 2>&1
                $versionSuccess = $?
                Write-Log -Message "Resultado del versionado (éxito: $versionSuccess): $($versionOutput -join ' ')"
                
                # Habilitar cifrado por defecto
                $encryptionCommand = "aws s3api put-bucket-encryption --bucket `"$BucketName`" --server-side-encryption-configuration '{`"Rules`":[{`"ApplyServerSideEncryptionByDefault`":{`"SSEAlgorithm`":`"AES256`"}}]}'"
                if ($AwsProfile -and $AwsProfile -ne "default") {
                    $encryptionCommand += " --profile `"$AwsProfile`""
                }
                Write-Log -Message "Ejecutando comando AWS para cifrado: $encryptionCommand"
                $encryptionOutput = Invoke-Expression -Command $encryptionCommand 2>&1
                $encryptionSuccess = $?
                Write-Log -Message "Resultado del cifrado (éxito: $encryptionSuccess): $($encryptionOutput -join ' ')"
                
                Write-Log -Message "Configuraciones adicionales aplicadas al bucket '$BucketName' (versionado: $versionSuccess, cifrado: $encryptionSuccess)"
            }
            catch {
                Write-Log -Message "Advertencia: No se pudieron aplicar todas las configuraciones adicionales al bucket '$BucketName': $_" -Level "WARNING"
            }
        }
        
        return @{
            Success = $success
            Output = $output
            Command = $command
            Region = $Region
        }
    }
    catch {
        return @{
            Success = $false
            Output = $_.Exception.Message
            Command = $command
            Region = $Region
        }
    }
}

# Función: Asegurar que el bucket S3 existe (verificar y crear si es necesario)
function Confirm-S3Bucket {
    param (
        [string] $BucketName,
        [string] $AwsProfile = "default",
        [string] $Region = $null
    )
    
    # Verificar si el bucket ya existe
    $bucketCheck = Test-S3Bucket -BucketName $BucketName -AwsProfile $AwsProfile
    
    if ($bucketCheck.Exists) {
        Write-Log -Message "Bucket S3 '$BucketName' ya existe"
        return @{
            Success = $true
            Action = "Exists"
            Message = "Bucket ya existía"
        }
    }
    
    # El bucket no existe, intentar crearlo
    Write-Log -Message "Bucket S3 '$BucketName' no existe, creándolo..."
    $bucketCreation = New-S3Bucket -BucketName $BucketName -AwsProfile $AwsProfile -Region $Region
    
    if ($bucketCreation.Success) {
        return @{
            Success = $true
            Action = "Created"
            Message = "Bucket creado exitosamente en la región '$($bucketCreation.Region)'"
            Region = $bucketCreation.Region
        }
    } else {
        return @{
            Success = $false
            Action = "Failed"
            Message = "Error al crear bucket: $($bucketCreation.Output)"
            Output = $bucketCreation.Output
        }
    }
}

# Función: Eliminar carpeta de forma forzada cuando hay handles abiertos
function Remove-FolderForced {
    param (
        [string] $Path
    )
    
    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Host "La carpeta '$Path' no existe." -ForegroundColor Yellow
        return $true
    }
    
    try {
        # Método 1: Intentar eliminación normal
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
        Write-Host "Carpeta '$Path' eliminada exitosamente." -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Eliminación normal falló: $_" -ForegroundColor Yellow
    }
    
    try {
        # Método 2: Cambiar directorio y forzar garbage collection
        $originalLocation = Get-Location
        Set-Location -Path $env:TEMP
        
        # Múltiples ciclos de garbage collection
        for ($i = 0; $i -lt 5; $i++) {
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()
            [System.GC]::Collect()
            Start-Sleep -Milliseconds 200
        }
        
        # Intentar eliminación nuevamente
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
        Set-Location -Path $originalLocation
        Write-Host "Carpeta '$Path' eliminada exitosamente después de limpiar handles." -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Eliminación con limpieza falló: $_" -ForegroundColor Yellow
        try { Set-Location -Path $originalLocation } catch {}
    }
    
    try {
        # Método 3: Usar robocopy para "mover" a una carpeta temporal vacía (truco para liberar handles)
        $tempEmptyDir = Join-Path $env:TEMP "empty_$(Get-Random)"
        New-Item -ItemType Directory -Path $tempEmptyDir -Force | Out-Null
        
        # Usar robocopy para sincronizar con carpeta vacía (efectivamente vacía la carpeta original)
        & robocopy $tempEmptyDir $Path /MIR /NJH /NJS /NP | Out-Null
        Start-Sleep -Seconds 1
        
        # Ahora intentar eliminar
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
        Remove-Item -LiteralPath $tempEmptyDir -Force -ErrorAction SilentlyContinue
        
        Write-Host "Carpeta '$Path' eliminada exitosamente usando robocopy." -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Eliminación con robocopy falló: $_" -ForegroundColor Yellow
    }
    
    # Si todo falla, mostrar mensaje de ayuda
    Write-Host "No se pudo eliminar la carpeta '$Path'. Posibles soluciones:" -ForegroundColor Red
    Write-Host "1. Cerrar todos los exploradores de archivos" -ForegroundColor Red
    Write-Host "2. Cerrar este terminal de PowerShell y abrir uno nuevo" -ForegroundColor Red
    Write-Host "3. Reiniciar el sistema" -ForegroundColor Red
    return $false
}

# Función: Mostrar información sobre las estrategias de sincronización disponibles
function Show-SyncStrategies {
    Write-Log -Message "=== ESTRATEGIAS DE SINCRONIZACIÓN DISPONIBLES ===" -Level "INFO"
    
    Write-Log -Message "1. DateFolder (Predeterminada)"
    Write-Log -Message "   - Sincroniza carpeta específica del día (formato fecha configurable)"
    Write-Log -Message "   - Ejemplo: C:\Datos\2025-01-15 -> s3://bucket/2025/01/15/"
    Write-Log -Message "   - Configuración: sync_strategy: { type: 'DateFolder' }"
    Write-Log -Message "   - Opciones: date_folder_format (yyyy-MM-dd por defecto)"
    Write-Log -Message ""
    
    Write-Log -Message "2. FullDirectory"
    Write-Log -Message "   - Sincroniza toda la carpeta base, sin importar la estructura"
    Write-Log -Message "   - Ejemplo: C:\Datos\ (completa) -> s3://bucket/full-backup/2025/01/"
    Write-Log -Message "   - Configuración: sync_strategy: { type: 'FullDirectory' }"
    Write-Log -Message "   - Útil para backups completos periódicos"
    Write-Log -Message ""
    
    Write-Log -Message "3. DateRange"
    Write-Log -Message "   - Sincroniza carpeta base incluyendo archivos de un rango de fechas"
    Write-Log -Message "   - Ejemplo: últimos 7 días de C:\Logs\ -> s3://bucket/date-range/2025/01/"
    Write-Log -Message "   - Configuración: sync_strategy: { type: 'DateRange' }"
    Write-Log -Message "   - Opciones: date_range_days_back (7 por defecto)"
    Write-Log -Message ""
    
    Write-Log -Message "4. CustomPattern"
    Write-Log -Message "   - Sincroniza usando un patrón personalizado de carpetas"
    Write-Log -Message "   - Ejemplo: C:\Reportes\2025\01 -> s3://bucket/reportes/2025/01/"
    Write-Log -Message "   - Configuración: sync_strategy: { type: 'CustomPattern' }"
    Write-Log -Message "   - Opciones: custom_local_pattern con placeholders {base_path}, {year}, {month}, {day}"
    Write-Log -Message ""
    
    Write-Log -Message "PLACEHOLDERS DISPONIBLES:"
    Write-Log -Message "   {base_path} - Ruta base configurada"
    Write-Log -Message "   {year}      - Año actual (yyyy)"
    Write-Log -Message "   {month}     - Mes actual (MM)"
    Write-Log -Message "   {day}       - Día actual (dd)"
    Write-Log -Message ""
    
    Write-Log -Message "=== FIN INFORMACIÓN DE ESTRATEGIAS ==="
}

# Función: Obtener configuración predeterminada para una estrategia específica
function Get-DefaultSyncStrategyConfig {
    param (
        [ValidateSet("DateFolder", "FullDirectory", "DateRange", "CustomPattern")]
        [string] $StrategyType
    )
    
    switch ($StrategyType) {
        "DateFolder" {
            return @{
                sync_strategy = @{
                    type = "DateFolder"
                    date_folder_format = "yyyy-MM-dd"
                }
                destination_config = @{
                    s3_path_structure = "{year}/{month}/{day}"
                }
                description = "Configuración por defecto para sincronización de carpetas diarias"
            }
        }
        "FullDirectory" {
            return @{
                sync_strategy = @{
                    type = "FullDirectory"
                }
                destination_config = @{
                    s3_path_structure = "full-backup/{year}/{month}"
                }
                description = "Configuración por defecto para sincronización completa de directorio"
            }
        }
        "DateRange" {
            return @{
                sync_strategy = @{
                    type = "DateRange"
                    date_range_days_back = 7
                }
                destination_config = @{
                    s3_path_structure = "date-range/{year}/{month}"
                }
                description = "Configuración por defecto para sincronización por rango de fechas"
            }
        }
        "CustomPattern" {
            return @{
                sync_strategy = @{
                    type = "CustomPattern"
                    custom_local_pattern = "{base_path}\\{year}\\{month}"
                }
                destination_config = @{
                    s3_path_structure = "custom/{year}/{month}"
                }
                description = "Configuración por defecto para sincronización con patrón personalizado"
            }
        }
    }
}

# Función: Validar que una estrategia de sincronización existe
function Test-SyncStrategyExists {
    param (
        [string] $StrategyType
    )
    
    $validStrategies = @("DateFolder", "FullDirectory", "DateRange", "CustomPattern")
    return $validStrategies -contains $StrategyType
}
#endregion 