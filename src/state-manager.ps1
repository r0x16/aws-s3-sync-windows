#region Funciones de Manejo de Estado
<#
.SYNOPSIS
    Funciones para manejo del archivo de estado JSON
#>

# Función: Inicializar o cargar archivo de estado JSON
function Get-State {
    if (-not (Test-Path -LiteralPath $(Get-StateFile))) {
        # Crear archivo con arreglo vacío
        try {
            @() | ConvertTo-Json | Out-File -LiteralPath $(Get-StateFile) -Encoding UTF8 -Force
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
            return @()
        }
        else {
            $result = $jsonContent | ConvertFrom-Json
            # Asegurar que el resultado sea un array
            if ($null -eq $result) {
                return @()
            }
            elseif ($result -is [System.Array]) {
                return $result
            }
            else {
                return @($result)
            }
        }
    }
    catch {
        Write-Error "No se pudo leer o parsear el archivo de estado '$(Get-StateFile)': $_"
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
        $StateArray | ConvertTo-Json -Depth 5 | Out-File -LiteralPath $(Get-StateFile) -Encoding UTF8 -Force
    }
    catch {
        Write-Error "No se pudo escribir el archivo de estado '$(Get-StateFile)': $_"
    }
}

# Función: Crear entrada de estado
function New-StateEntry {
    param (
        [string] $Date,
        [string] $Status,
        [string] $Message,
        [string] $ConfigName = ""
    )
    
    return [PSCustomObject]@{
        Date      = $Date
        Timestamp = (Get-Date).ToString("o")
        Status    = $Status
        Message   = $Message
        ConfigName = $ConfigName
    }
}

# Función: Agregar entrada al estado
function Add-StateEntry {
    param (
        [string] $Date,
        [string] $Status,
        [string] $Message,
        [string] $ConfigName = ""
    )
    
    $stateArray = Get-State
    # Asegurar que $stateArray es un array
    if ($null -eq $stateArray) {
        $stateArray = @()
    }
    elseif ($stateArray -isnot [System.Array]) {
        $stateArray = @($stateArray)
    }
    
    $entry = New-StateEntry -Date $Date -Status $Status -Message $Message -ConfigName $ConfigName
    $stateArray = $stateArray + $entry
    Set-State -StateArray $stateArray
}
#endregion 