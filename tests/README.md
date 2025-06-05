# Pruebas Pester

Este directorio contiene las pruebas unitarias para el proyecto AWS S3 Sync.

## Requisitos

- PowerShell 5.0 o superior
- Módulo Pester (v3.4.0 o superior)

## Ejecutar las pruebas

### Ejecutar todas las pruebas
```powershell
Invoke-Pester .\tests\
```

### Ejecutar una prueba específica
```powershell
Invoke-Pester .\tests\Get-SyncPaths.tests.ps1
```

### Ejecutar con salida detallada
```powershell
Invoke-Pester .\tests\ -Verbose
```

## Estructura de archivos

- `Get-SyncPaths.tests.ps1` - Pruebas para la función `Get-SyncPaths` del módulo `utils.ps1`

## Casos de prueba cubiertos

### Get-SyncPaths
- ✅ Configuración básica con estructura S3 por defecto
- ✅ Configuración con estructura S3 personalizada
- ✅ Configuración con formato de fecha personalizado
- ✅ Configuración con valores por defecto
- ✅ Manejo de diferentes fechas (meses y años)

Cada caso de prueba verifica que se generen correctamente:
- `LocalPath` - Ruta local de la carpeta a sincronizar
- `S3Path` - Ruta de destino en S3
- `DayFolder` - Nombre de la carpeta del día
- `ConfigName` - Nombre de la configuración 