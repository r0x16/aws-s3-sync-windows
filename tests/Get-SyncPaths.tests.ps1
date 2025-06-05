# Pruebas Pester para la función Get-SyncPaths
# Requiere importar el módulo utils.ps1 que contiene la función

# Importar el módulo que contiene la función Get-SyncPaths
. "$PSScriptRoot\..\src\utils.ps1"

Describe "Get-SyncPaths" {
    
    Context "Configuración básica con estructura S3 por defecto" {
        It "Debería generar rutas correctas con fecha conocida" {
            # Arrange - Crear un objeto SyncConfig mock simple
            $mockSyncConfig = [PSCustomObject]@{
                name = "Test Config"
                local_base_path = "C:\TestData"
                bucket_name = "test-bucket"
                date_folder_format = "yyyy-MM-dd"
                s3_path_structure = "{year}/{month}/{day}"
            }
            
            # Fecha de prueba conocida: 15 de marzo de 2024
            $testDate = Get-Date "2024-03-15"
            
            # Act - Llamar a la función
            $result = Get-SyncPaths -Date $testDate -SyncConfig $mockSyncConfig
            
            # Assert - Verificar los valores esperados
            $result.LocalPath | Should Be "C:\TestData\2024-03-15"
            $result.S3Path | Should Be "s3://test-bucket/2024/03/2024-03-15"
            $result.DayFolder | Should Be "2024-03-15"
            $result.ConfigName | Should Be "Test Config"
        }
    }
    
    Context "Configuración con estructura S3 personalizada" {
        It "Debería generar rutas S3 con estructura personalizada" {
            # Arrange
            $mockSyncConfig = [PSCustomObject]@{
                name = "Custom Structure Config"
                local_base_path = "C:\Documents"
                bucket_name = "documents-backup"
                date_folder_format = "yyyy-MM-dd"
                s3_path_structure = "backups/{year}/{month}/{day}/docs"
            }
            
            $testDate = Get-Date "2024-12-25"
            
            # Act
            $result = Get-SyncPaths -Date $testDate -SyncConfig $mockSyncConfig
            
            # Assert
            $result.LocalPath | Should Be "C:\Documents\2024-12-25"
            $result.S3Path | Should Be "s3://documents-backup/backups/2024/12/2024-12-25/docs"
            $result.DayFolder | Should Be "2024-12-25"
            $result.ConfigName | Should Be "Custom Structure Config"
        }
    }
    
    Context "Configuración con formato de fecha personalizado" {
        It "Debería usar formato de fecha personalizado para carpetas locales" {
            # Arrange
            $mockSyncConfig = [PSCustomObject]@{
                name = "Custom Date Format Config"
                local_base_path = "C:\Photos"
                bucket_name = "photos-bucket"
                date_folder_format = "yyyyMMdd"
                s3_path_structure = "photos/{year}/{month}/{day}"
            }
            
            $testDate = Get-Date "2024-07-04"
            
            # Act
            $result = Get-SyncPaths -Date $testDate -SyncConfig $mockSyncConfig
            
            # Assert
            $result.LocalPath | Should Be "C:\Photos\20240704"
            $result.S3Path | Should Be "s3://photos-bucket/photos/2024/07/20240704"
            $result.DayFolder | Should Be "20240704"
            $result.ConfigName | Should Be "Custom Date Format Config"
        }
    }
    
    Context "Configuración con valores por defecto" {
        It "Debería usar valores por defecto cuando no se especifican propiedades opcionales" {
            # Arrange - SyncConfig mínimo sin propiedades opcionales
            $mockSyncConfig = [PSCustomObject]@{
                name = "Minimal Config"
                local_base_path = "C:\MinimalTest"
                bucket_name = "minimal-bucket"
            }
            
            $testDate = Get-Date "2024-01-01"
            
            # Act
            $result = Get-SyncPaths -Date $testDate -SyncConfig $mockSyncConfig
            
            # Assert - Debería usar valores por defecto
            $result.LocalPath | Should Be "C:\MinimalTest\2024-01-01"
            $result.S3Path | Should Be "s3://minimal-bucket/2024/01/2024-01-01"
            $result.DayFolder | Should Be "2024-01-01"
            $result.ConfigName | Should Be "Minimal Config"
        }
    }
    
    Context "Fechas con diferentes meses y años" {
        It "Debería manejar correctamente fechas en diferentes meses/años" {
            # Arrange
            $mockSyncConfig = [PSCustomObject]@{
                name = "Date Test Config"
                local_base_path = "C:\DateTests"
                bucket_name = "date-test-bucket"
                date_folder_format = "yyyy-MM-dd"
                s3_path_structure = "{year}/{month}/{day}"
            }
            
            # Casos de prueba con diferentes fechas
            $testCases = @(
                @{ Date = "2023-01-31"; ExpectedMonth = "01"; ExpectedYear = "2023" },
                @{ Date = "2024-12-01"; ExpectedMonth = "12"; ExpectedYear = "2024" },
                @{ Date = "2025-06-15"; ExpectedMonth = "06"; ExpectedYear = "2025" }
            )
            
            foreach ($testCase in $testCases) {
                # Act
                $testDate = Get-Date $testCase.Date
                $result = Get-SyncPaths -Date $testDate -SyncConfig $mockSyncConfig
                
                # Assert
                $expectedLocalPath = "C:\DateTests\$($testCase.Date)"
                $expectedS3Path = "s3://date-test-bucket/$($testCase.ExpectedYear)/$($testCase.ExpectedMonth)/$($testCase.Date)"
                
                $result.LocalPath | Should Be $expectedLocalPath
                $result.S3Path | Should Be $expectedS3Path
                $result.DayFolder | Should Be $testCase.Date
            }
        }
    }
} 