# 🌟 Mochok - AWS S3 Sync System

> **[🇪🇸 Leer en Español](README-ES.md)** | English

Mochok is a modular system for synchronizing files with AWS S3, designed to be easy to use and highly configurable.

## 🚀 Quick Start

1. **Install prerequisites**:
   ```powershell
   .\mochok.ps1 install
   ```

2. **Configure AWS CLI**:
   ```bash
   aws configure
   ```

3. **Configure synchronization**:
   - Copy `sync-config.yaml.example` to `sync-config.yaml`
   - Edit with your paths, buckets and profiles

4. **Run synchronization**:
   ```powershell
   .\mochok.ps1 sync
   ```

## 📋 Commands

### `sync` - Main Synchronization
```powershell
.\mochok.ps1 sync
.\mochok.ps1 sync -TargetDate (Get-Date "2025-01-15")
```

### `status` - System Status
```powershell
.\mochok.ps1 status
.\mochok.ps1 status -OnlyLastExecution
.\mochok.ps1 status -JsonOutput
```

### `strategies` - Sync Strategies
```powershell
.\mochok.ps1 strategies
.\mochok.ps1 strategies -ShowExamples
```

### `install` - Install Prerequisites
```powershell
.\mochok.ps1 install
```

### `"clear logs"` - Clean Logs
```powershell
.\mochok.ps1 "clear logs"
.\mochok.ps1 "clear logs" -KeepLastDays 30
.\mochok.ps1 "clear logs" -RemoveDirectory
```

### `help` - Help
```powershell
.\mochok.ps1 help
```

## ⚙️ Configuration

Edit the `sync-config.yaml` file:

```yaml
global:
  log_retention_months: 12

sync_configurations:
  - name: "Daily Documents"
    description: "Daily document backup"
    enabled: true
    local_base_path: "C:\\MyFolders"
    
    sync_strategy:
      type: "DateFolder"
      date_folder_format: "yyyy-MM-dd"
    
    destination_config:
      bucket_name: "my-s3-bucket"
      aws_profile: "default"
      s3_path_structure: "{year}/{month}/{day}"
    
    sync_options:
      - "--exclude=*.tmp"
```

### Configuration Parameters

- **`local_base_path`**: Base folder for synchronization
- **`sync_strategy`**: Strategy configuration
  - **`type`**: Strategy type (`DateFolder`, `FullDirectory`, `DateRange`, `CustomPattern`)
  - **`date_folder_format`**: Date folder format (DateFolder strategy only)
  - **`custom_local_pattern`**: Custom pattern (CustomPattern strategy only)
  - **`date_range_days_back`**: Days back (DateRange strategy only)
- **`destination_config`**: AWS S3 destination configuration
  - **`bucket_name`**: S3 bucket name (created automatically if it doesn't exist)
  - **`aws_profile`**: AWS profile to use
  - **`aws_region`**: AWS region (optional, auto-detected)
  - **`s3_path_structure`**: S3 organization structure using `{year}`, `{month}`, `{day}`
- **`sync_options`**: Additional AWS CLI options

## 🎯 Sync Strategies

### 1. DateFolder (Default)
Syncs specific day folder with configurable date format.
```yaml
sync_strategy:
  type: "DateFolder"
  date_folder_format: "yyyy-MM-dd"
```

### 2. FullDirectory
Syncs entire base folder.
```yaml
sync_strategy:
  type: "FullDirectory"
```

### 3. DateRange
Syncs files from a date range.
```yaml
sync_strategy:
  type: "DateRange"
  date_range_days_back: 7
```

### 4. CustomPattern
Uses custom patterns for sync paths.
```yaml
sync_strategy:
  type: "CustomPattern"
  custom_local_pattern: "{base_path}\\{year}\\{month}"
```

## ⏰ Automatic Scheduling

To run automatically every day, use Windows Task Scheduler:

1. Open **Task Scheduler**
2. Create new basic task
3. Configure:
   - **Program**: `powershell.exe`
   - **Arguments**: `-File "C:\full\path\mochok.ps1" sync`
   - **Start in**: `C:\full\path\`

## 📁 File Structure

```
├── mochok.ps1                    # Main application file
├── sync-config.yaml              # Your configuration
├── sync-config.yaml.example      # Configuration examples
├── state.json                    # Sync state
├── log/                          # Automatic logs
└── src/                          # System source code
```

## 📋 Logs and State

- **Logs**: `log/sync_YYYY-MM.log` (one file per month)
- **State**: `state.json` (last sync execution information)
- **Retention**: Logs are automatically cleaned

## 🚨 Troubleshooting

### Execution Policy Error
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### AWS CLI Not Configured
```bash
aws configure
```

### Verify Prerequisites
```powershell
.\mochok.ps1 install
```