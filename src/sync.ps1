<#
.SYNOPSIS
    Script para sincronizar periódicamente la carpeta del día anterior a un bucket de AWS S3,
    manteniendo estado de ejecución, logs mensuales con rotación (máximo 12 meses) y manejo de errores.

.DESCRIPCIÓN
    Este script:
      - Calcula la fecha del día anterior.
      - Forma la ruta local correspondiente a esa carpeta (formato "yyyy-MM-dd").
      - Sincroniza esa carpeta con S3 usando `aws s3 sync`, sin la opción --delete.
      - Guarda el resultado de cada ejecución (fecha, hora, estado y mensaje) en un archivo JSON de estado.
      - Registra entradas de log en un archivo mensual dentro de la carpeta "log" al lado del script.
      - Rota los logs automáticamente, borrando archivos de log con más de 12 meses de antigüedad.
      - Maneja errores comunes (por ejemplo, AWS CLI no instalado, carpeta inexistente, errores de red).

.NOTAS
    - Colocar este script en la carpeta raíz donde están los subdirectorios diarios (ej. "2025-05-10", "2025-05-11", ...).
    - Debe existir AWS CLI configurado previamente (credenciales en ~/.aws/credentials o %USERPROFILE%\.aws\credentials).
    - Programar su ejecución periódica a las 00:00 cada día (por ejemplo, con el Programador de Tareas de Windows).

#>

#region Configuración
# Nombre de bucket sin la parte "s3://"
$bucketName = "bucket-de-prueba"

# La carpeta base donde están los subdirectorios diarios. 
# Se asume que el script .ps1 está dentro de esta carpeta base, así que usamos $PSScriptRoot.
$localBasePath = $PSScriptRoot

# Carpeta donde se guardarán los logs; se creará automáticamente si no existe.
$logDir = Join-Path $PSScriptRoot "log"

# Archivo JSON donde se guardará el estado de ejecuciones.
$stateFile = Join-Path $PSScriptRoot "state.json"
#endregion

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

# Función: Registrar mensaje en el log del mes correspondiente
function Write-Log {
    param (
        [string] $Message,
        [ValidateSet("INFO","ERROR","WARNING")]
        [string] $Level = "INFO"
    )
    # Nombre del archivo de log: sync_YYYY-MM.log (correspondiente al mes actual)
    $logFileName = "sync_$((Get-Date).ToString('yyyy-MM')).log"
    $logPath = Join-Path $logDir $logFileName

    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $entry = "[$timestamp] [$Level] $Message"
    try {
        Add-Content -LiteralPath $logPath -Value $entry -ErrorAction Stop
    }
    catch {
        Write-Error "No se pudo escribir en el archivo de log '$logPath': $_"
    }
}

# Función: Rotar logs (eliminar archivos con más de 12 meses de antigüedad)
function Remove-OldLogs {
    # Fecha límite: hace N meses según configuración
    $limitDate = (Get-Date).AddMonths(-$Global:LogRetentionMonths)
    Get-ChildItem -LiteralPath $logDir -Filter "sync_*.log" -File | ForEach-Object {
        # Nombre de archivo: sync_YYYY-MM.log
        if ($_.Name -match '^sync_(\d{4})-(\d{2})\.log$') {
            $year = [int]$Matches[1]
            $month = [int]$Matches[2]
            # Construir primer día de ese mes
            $fileMonthDate = [datetime]"$($year)-$($month)-01"
            if ($fileMonthDate -lt $limitDate) {
                try {
                    Remove-Item -LiteralPath $_.FullName -ErrorAction Stop
                    # Opcional: registrar en otro log de mantenimiento o en consola
                }
                catch {
                    Write-Log -Message "Error al eliminar log antiguo '$($_.Name)': $_" -Level "WARNING"
                }
            }
        }
    }
}

# Función: Inicializar o cargar archivo de estado JSON
function Get-State {
    if (-not (Test-Path -LiteralPath $stateFile)) {
        # Crear archivo con arreglo vacío
        try {
            @() | ConvertTo-Json | Out-File -LiteralPath $stateFile -Encoding UTF8 -Force
        }
        catch {
            Write-Error "No se pudo crear el archivo de estado '$stateFile': $_"
            exit 1
        }
    }
    # Leer JSON existente
    try {
        $jsonContent = Get-Content -LiteralPath $stateFile -Raw -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($jsonContent)) {
            return @()
        }
        else {
            return $jsonContent | ConvertFrom-Json
        }
    }
    catch {
        Write-Error "No se pudo leer o parsear el archivo de estado '$stateFile': $_"
        exit 1
    }
}

# Función: Guardar estado en JSON
function Set-State {
    param (
        [Parameter(Mandatory)]
        [object[]] $StateArray
    )
    try {
        $StateArray | ConvertTo-Json -Depth 5 | Out-File -LiteralPath $stateFile -Encoding UTF8 -Force
    }
    catch {
        Write-Error "No se pudo escribir el archivo de estado '$stateFile': $_"
    }
}

# ------------------- EJECUCIÓN PRINCIPAL -------------------

# 1. Asegurar carpeta de logs
Test-AndCreateFolder -Path $logDir

# 2. Rotar logs (borrar mayores a 12 meses)
Remove-OldLogs

# 3. Calcular fecha del día anterior
$yesterday = (Get-Date).AddDays(-1)
$year  = $yesterday.ToString("yyyy")
$month = $yesterday.ToString("MM")
$dayFolderName = $yesterday.ToString("yyyy-MM-dd")

# 4. Construir rutas
$localFolderPath = Join-Path $localBasePath $dayFolderName
# Ruta en S3: s3://bucket-de-prueba/{año}/{mes}/{día}
$s3Destination = "s3://$bucketName/$year/$month/$dayFolderName"

# 5. Cargar estado actual
$stateArray = Get-State

# 6. Registrar inicio de sincronización en log
Write-Log -Message "Iniciando sincronización de '$localFolderPath' a '$s3Destination'."

# 7. Verificar existencia de la carpeta local
if (-not (Test-Path -LiteralPath $localFolderPath)) {
    $msg = "Carpeta local '$localFolderPath' no encontrada. Se omite sincronización del día $dayFolderName."
    Write-Log -Message $msg -Level "ERROR"

    # Agregar entrada al estado
    $entry = [PSCustomObject]@{
        Date      = $dayFolderName
        Timestamp = (Get-Date).ToString("o")
        Status    = "Skipped"
        Message   = "Carpeta local inexistente"
    }
    $stateArray += $entry
    Set-State -StateArray $stateArray

    exit 0
}

# 8. Verificar existencia de AWS CLI
if (-not (Get-Command "aws" -ErrorAction SilentlyContinue)) {
    $msg = "AWS CLI no está instalado o no se encuentra en PATH."
    Write-Log -Message $msg -Level "ERROR"

    $entry = [PSCustomObject]@{
        Date      = $dayFolderName
        Timestamp = (Get-Date).ToString("o")
        Status    = "Failure"
        Message   = "AWS CLI no instalado"
    }
    $stateArray += $entry
    Set-State -StateArray $stateArray

    exit 1
}

# 9. Ejecutar aws s3 sync dentro de un bloque try/catch
$syncSucceeded = $false
$errorMessage = ""
try {
    $syncCommand = "aws s3 sync `"$localFolderPath`" `"$s3Destination`""
    # Ejecutar el comando y capturar salida
    $output = Invoke-Expression -Command $syncCommand 2>&1
    $syncSucceeded = $?

    if ($syncSucceeded) {
        Write-Log -Message "Sincronización exitosa."
    }
    else {
        $errorMessage = "aws s3 sync falló. Detalles: $output"
        Write-Log -Message $errorMessage -Level "ERROR"
    }
}
catch {
    $syncSucceeded = $false
    $errorMessage = "Excepción durante aws s3 sync: $_"
    Write-Log -Message $errorMessage -Level "ERROR"
}

# 10. Agregar entrada de estado
if ($syncSucceeded) {
    $entry = [PSCustomObject]@{
        Date      = $dayFolderName
        Timestamp = (Get-Date).ToString("o")
        Status    = "Success"
        Message   = "Sincronización completada sin errores."
    }
}
else {
    $entry = [PSCustomObject]@{
        Date      = $dayFolderName
        Timestamp = (Get-Date).ToString("o")
        Status    = "Failure"
        Message   = $errorMessage
    }
}
$stateArray += $entry
Set-State -StateArray $stateArray

# Fin del script
