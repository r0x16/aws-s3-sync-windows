<#
.SYNOPSIS
    Muestra información sobre las estrategias de sincronización disponibles

.DESCRIPCIÓN
    Este script muestra una guía completa de las estrategias de sincronización disponibles,
    incluyendo ejemplos de configuración y casos de uso.

.PARAMETER ShowExamples
    Muestra ejemplos detallados de configuración para cada estrategia

.EXAMPLE
    .\show-sync-strategies.ps1
    Muestra la información básica de todas las estrategias

.EXAMPLE
    .\show-sync-strategies.ps1 -ShowExamples
    Muestra la información completa con ejemplos de configuración
#>

param(
    [switch] $ShowExamples
)

try {
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host " ESTRATEGIAS DE SINCRONIZACION AWS S3 DISPONIBLES" -ForegroundColor Cyan
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "1. DateFolder (Predeterminada)" -ForegroundColor Yellow
    Write-Host "   - Sincroniza carpeta especifica del dia (formato fecha configurable)" -ForegroundColor White
    Write-Host "   - Ejemplo: C:\Datos\2025-01-15 -> s3://bucket/2025/01/15/" -ForegroundColor Gray
    Write-Host "   - Configuracion: sync_strategy: { type: 'DateFolder' }" -ForegroundColor White
    Write-Host "   - Opciones: sync_strategy.date_folder_format (yyyy-MM-dd por defecto)" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "2. FullDirectory" -ForegroundColor Yellow
    Write-Host "   - Sincroniza toda la carpeta base, sin importar la estructura" -ForegroundColor White
    Write-Host "   - Ejemplo: C:\Datos\ (completa) -> s3://bucket/full-backup/2025/01/" -ForegroundColor Gray
    Write-Host "   - Configuracion: sync_strategy: { type: 'FullDirectory' }" -ForegroundColor White
    Write-Host "   - Util para backups completos periodicos" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "3. DateRange" -ForegroundColor Yellow
    Write-Host "   - Sincroniza carpeta base incluyendo archivos de un rango de fechas" -ForegroundColor White
    Write-Host "   - Ejemplo: ultimos 7 dias de C:\Logs\ -> s3://bucket/date-range/2025/01/" -ForegroundColor Gray
    Write-Host "   - Configuracion: sync_strategy: { type: 'DateRange' }" -ForegroundColor White
    Write-Host "   - Opciones: sync_strategy.date_range_days_back (7 por defecto)" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "4. CustomPattern" -ForegroundColor Yellow
    Write-Host "   - Sincroniza usando un patron personalizado de carpetas" -ForegroundColor White
    Write-Host "   - Ejemplo: C:\Reportes\2025\01 -> s3://bucket/reportes/2025/01/" -ForegroundColor Gray
    Write-Host "   - Configuracion: sync_strategy: { type: 'CustomPattern' }" -ForegroundColor White
    Write-Host "   - Opciones: sync_strategy.custom_local_pattern con placeholders" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "PLACEHOLDERS DISPONIBLES:" -ForegroundColor Cyan
    Write-Host "   {base_path} - Ruta base configurada" -ForegroundColor White
    Write-Host "   {year}      - Anio actual (yyyy)" -ForegroundColor White
    Write-Host "   {month}     - Mes actual (MM)" -ForegroundColor White
    Write-Host "   {day}       - Dia actual (dd)" -ForegroundColor White
    Write-Host ""

    if ($ShowExamples) {
        Write-Host "===============================================" -ForegroundColor Green
        Write-Host "        EJEMPLOS DE CONFIGURACION" -ForegroundColor Green
        Write-Host "===============================================" -ForegroundColor Green
        Write-Host ""
        
        Write-Host "ESTRATEGIA DateFolder (Carpetas diarias):" -ForegroundColor Yellow
        Write-Host "- name: 'Documentos Diarios'" -ForegroundColor White
        Write-Host "  description: 'Sincronizacion de carpeta del dia anterior'" -ForegroundColor White
        Write-Host "  enabled: true" -ForegroundColor White
        Write-Host "  local_base_path: 'C:\\Datos\\Documentos'" -ForegroundColor White
        Write-Host "  sync_strategy:" -ForegroundColor White
        Write-Host "    type: 'DateFolder'" -ForegroundColor White
        Write-Host "    date_folder_format: 'yyyy-MM-dd'" -ForegroundColor White
        Write-Host "  destination_config:" -ForegroundColor White
        Write-Host "    bucket_name: 'documentos-backup'" -ForegroundColor White
        Write-Host "    s3_path_structure: '{year}/{month}/{day}'" -ForegroundColor White
        Write-Host ""
        
        Write-Host "ESTRATEGIA FullDirectory (Directorio completo):" -ForegroundColor Yellow
        Write-Host "- name: 'Backup Completo'" -ForegroundColor White
        Write-Host "  description: 'Sincronizacion completa de carpeta'" -ForegroundColor White
        Write-Host "  enabled: true" -ForegroundColor White
        Write-Host "  local_base_path: 'D:\\Fotos'" -ForegroundColor White
        Write-Host "  sync_strategy:" -ForegroundColor White
        Write-Host "    type: 'FullDirectory'" -ForegroundColor White
        Write-Host "  destination_config:" -ForegroundColor White
        Write-Host "    bucket_name: 'fotos-backup-completo'" -ForegroundColor White
        Write-Host "    s3_path_structure: 'full-backup/{year}/{month}'" -ForegroundColor White
        Write-Host ""
        
        Write-Host "ESTRATEGIA DateRange (Rango de fechas):" -ForegroundColor Yellow
        Write-Host "- name: 'Logs Ultima Semana'" -ForegroundColor White
        Write-Host "  description: 'Sincronizacion de logs de ultimos 7 dias'" -ForegroundColor White
        Write-Host "  enabled: true" -ForegroundColor White
        Write-Host "  local_base_path: 'C:\\Logs\\Sistema'" -ForegroundColor White
        Write-Host "  sync_strategy:" -ForegroundColor White
        Write-Host "    type: 'DateRange'" -ForegroundColor White
        Write-Host "    date_range_days_back: 7" -ForegroundColor White
        Write-Host "  destination_config:" -ForegroundColor White
        Write-Host "    bucket_name: 'logs-backup'" -ForegroundColor White
        Write-Host "    s3_path_structure: 'date-range/{year}/{month}'" -ForegroundColor White
        Write-Host ""
        
        Write-Host "ESTRATEGIA CustomPattern (Patron personalizado):" -ForegroundColor Yellow
        Write-Host "- name: 'Reportes Mensuales'" -ForegroundColor White
        Write-Host "  description: 'Sincronizacion con patron personalizado'" -ForegroundColor White
        Write-Host "  enabled: true" -ForegroundColor White
        Write-Host "  local_base_path: 'E:\\Reportes'" -ForegroundColor White
        Write-Host "  sync_strategy:" -ForegroundColor White
        Write-Host "    type: 'CustomPattern'" -ForegroundColor White
        Write-Host "    custom_local_pattern: '{base_path}\\{year}\\{month}'" -ForegroundColor White
        Write-Host "  destination_config:" -ForegroundColor White
        Write-Host "    bucket_name: 'reportes-backup'" -ForegroundColor White
        Write-Host "    s3_path_structure: 'reportes/{year}/{month}'" -ForegroundColor White
        Write-Host ""
    }
    else {
        Write-Host "===============================================" -ForegroundColor Cyan
        Write-Host "Para ver ejemplos completos, ejecute:" -ForegroundColor Cyan
        Write-Host "  .\show-sync-strategies.ps1 -ShowExamples" -ForegroundColor White
        Write-Host ""
        Write-Host "Para configuraciones de ejemplo detalladas, vea:" -ForegroundColor Cyan
        Write-Host "  sync-config.yaml.example" -ForegroundColor White
        Write-Host "===============================================" -ForegroundColor Cyan
    }
    
    exit 0
}
catch {
    Write-Error "Error al mostrar información de estrategias: $_"
    exit 1
} 