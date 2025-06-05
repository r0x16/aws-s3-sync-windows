# Mochok - Technical Documentation

[🇪🇸 Versión en Español](README-ES.md)

## Table of Contents

1. [Project Overview](#project-overview)
2. [System Architecture](#system-architecture)
3. [Project Structure](#project-structure)
4. [Core Components](#core-components)
5. [Synchronization Strategies](#synchronization-strategies)
6. [Configuration System](#configuration-system)
7. [State Management](#state-management)
8. [Command System](#command-system)
9. [Development Guidelines](#development-guidelines)
10. [Technical Implementation Details](#technical-implementation-details)

---

## Project Overview

**Mochok** is a comprehensive PowerShell-based AWS S3 synchronization system designed for enterprise environments. It provides a modular, configurable, and extensible framework for automating file synchronization tasks between local directories and AWS S3 buckets.

### Key Features
- **Multi-configuration support**: Execute multiple synchronization tasks in sequence
- **Flexible strategies**: Different synchronization patterns (DateFolder, FullDirectory, DateRange, CustomPattern)
- **State persistence**: Comprehensive execution tracking and reporting
- **Enterprise logging**: Structured logging with automatic cleanup
- **Command-line interface**: Intuitive CLI with multiple commands
- **Error handling**: Robust error detection and reporting
- **AWS integration**: Full AWS CLI integration with profile support

### Technology Stack
- **Language**: PowerShell 5.1+
- **Cloud Provider**: AWS S3
- **Configuration**: YAML
- **State Storage**: JSON
- **Dependencies**: AWS CLI, powershell-yaml module

---

## System Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Mochok System                        │
├─────────────────────────────────────────────────────────────┤
│  Entry Point: mochok.ps1                                   │
│  ├── Command Router                                        │
│  └── Parameter Validation                                  │
├─────────────────────────────────────────────────────────────┤
│  Commands Layer (src/commands/)                            │
│  ├── sync.ps1         - Main synchronization             │
│  ├── status.ps1       - System status reporting          │
│  ├── strategies.ps1   - Strategy documentation           │
│  ├── install.ps1      - Prerequisites installation       │
│  └── clear-logs.ps1   - Log cleanup                      │
├─────────────────────────────────────────────────────────────┤
│  Core Services Layer (src/)                               │
│  ├── sync-service.ps1 - Synchronization orchestration    │
│  ├── config.ps1       - Configuration management         │
│  ├── state-manager.ps1- State persistence               │
│  ├── utils.ps1        - Utility functions               │
│  └── logging.ps1      - Logging system                   │
├─────────────────────────────────────────────────────────────┤
│  External Dependencies                                     │
│  ├── AWS CLI          - S3 operations                    │
│  ├── powershell-yaml  - YAML parsing                     │
│  └── File System      - Local file operations            │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow

1. **Configuration Loading**: YAML configuration is parsed and validated
2. **Strategy Resolution**: Each sync configuration is mapped to its strategy
3. **Path Calculation**: Local and S3 paths are computed based on strategy
4. **Execution**: Synchronization tasks are executed sequentially
5. **State Persistence**: Results are recorded in state.json
6. **Logging**: All operations are logged with structured output

---

## Project Structure

```
aws-s3-sync/
├── 📄 mochok.ps1                    # Main entry point and command router
├── 📄 sync-config.yaml              # Active configuration file
├── 📄 sync-config.yaml.example      # Comprehensive configuration examples
├── 📄 state.json                    # Execution state persistence
├── 📄 .gitignore                    # Git ignore rules
├── 📄 README.md                     # User documentation
├── 📄 README-ES.md                  # Spanish user documentation
├── 📁 src/                          # Source code directory
│   ├── 📄 README.md                 # Technical documentation (this file)
│   ├── 📄 README-ES.md              # Spanish technical documentation
│   ├── 📄 sync-service.ps1          # Core synchronization service
│   ├── 📄 config.ps1                # Configuration management
│   ├── 📄 utils.ps1                 # Utility functions and strategies
│   ├── 📄 state-manager.ps1         # State persistence management
│   ├── 📄 logging.ps1               # Logging system
│   ├── 📄 log-cleaner.ps1           # Log cleanup functionality
│   └── 📁 commands/                 # CLI commands implementation
│       ├── 📄 sync.ps1              # Main sync command
│       ├── 📄 status.ps1            # Status reporting command
│       ├── 📄 strategies.ps1        # Strategy information command
│       ├── 📄 install.ps1           # Installation command
│       └── 📄 clear-logs.ps1        # Log cleanup command
├── 📁 log/                          # Log files directory
│   └── 📄 sync_YYYY-MM.log          # Monthly log files
└── 📁 tests/                        # Test files directory
    ├── 📄 README.md                 # Testing documentation
    └── 📄 Get-SyncPaths.tests.ps1   # Unit tests for path functions
```

---

## Core Components

### 1. Main Entry Point (`mochok.ps1`)

**Purpose**: Command router and parameter validation
**Key Features**:
- Command normalization and validation
- Parameter passing to appropriate command modules
- Unified help system and error handling
- Visual branding and user experience

**Architecture Pattern**: Command Pattern with router implementation

```powershell
# Command execution pattern
switch ($normalizedCommand) {
    "sync" { & (Join-Path $PSScriptRoot "src\commands\sync.ps1") -TargetDate $TargetDate }
    "status" { & (Join-Path $PSScriptRoot "src\commands\status.ps1") @statusParams }
    # ... other commands
}
```

### 2. Configuration System (`src/config.ps1`)

**Purpose**: YAML-based configuration management
**Key Components**:
- `SyncConfiguration` class for configuration state
- YAML parsing with `powershell-yaml` integration
- Configuration validation and defaults
- Environment-specific configuration loading

**Configuration Structure**:
```yaml
global:
  log_retention_months: 12
  log_directory: "log"
  state_file: "state.json"

sync_configurations:
- name: "Configuration Name"
  description: "Description"
  enabled: true|false
  local_base_path: "C:\\Path\\To\\Source"
  sync_strategy:
    type: "DateFolder|FullDirectory|DateRange|CustomPattern"
    # Strategy-specific options
  destination_config:
    bucket_name: "s3-bucket-name"
    aws_profile: "aws-profile-name"
    aws_region: "aws-region"
    s3_path_structure: "path/structure/{placeholders}"
  sync_options:
    - "--option1"
    - "--option2"
```

### 3. Synchronization Service (`src/sync-service.ps1`)

**Purpose**: Core synchronization orchestration
**Key Functions**:

#### `Start-SyncProcess`
- Executes synchronization for a single configuration
- Handles path validation, AWS CLI verification
- Manages S3 bucket creation/verification
- Performs file counting and transfer execution
- Records execution results and metrics

#### `Start-AllSyncProcesses`
- Orchestrates multiple configuration executions
- Provides progress tracking and summary reporting
- Handles error accumulation and final status determination
- Integrates with state management for persistence

**Error Handling Strategy**:
- Graceful degradation: failed configurations don't stop execution
- Detailed error logging with context
- Status categorization: Success, Failure, Skipped

### 4. State Management (`src/state-manager.ps1`)

**Purpose**: Execution state persistence and tracking
**State Structure**:

```json
{
  "lastExecution": {
    "timestamp": "ISO8601",
    "success": boolean,
    "totalConfigurations": number,
    "successfulConfigurations": number,
    "failedConfigurations": number,
    "targetDate": "YYYY-MM-DD",
    "duration": "HH:MM:SS"
  },
  "configurationResults": {
    "ConfigName": {
      "lastStatus": "Success|Failure|Skipped",
      "lastMessage": "Detailed message",
      "lastTimestamp": "ISO8601",
      "lastDate": "YYYY-MM-DD",
      "localPath": "full/path",
      "s3Path": "s3://bucket/path",
      "filesTransferred": number,
      "duration": "HH:MM:SS",
      "consecutiveFailures": number
    }
  },
  "lastSuccessfulSync": {
    "ConfigName": {
      "timestamp": "ISO8601",
      "date": "YYYY-MM-DD",
      "localPath": "full/path",
      "s3Path": "s3://bucket/path",
      "message": "Success message",
      "filesTransferred": number,
      "duration": "HH:MM:SS"
    }
  },
  "statistics": {
    "totalExecutions": number,
    "lastSuccessDate": "ISO8601",
    "consecutiveFailures": number
  }
}
```

**Key Functions**:
- `Get-State`: Load and validate state structure
- `Set-State`: Persist state with error handling
- `Start-StateExecution`: Initialize execution tracking
- `Complete-StateExecution`: Finalize execution metrics
- `Set-ConfigurationResult`: Record individual configuration results

### 5. Utility Functions (`src/utils.ps1`)

**Purpose**: Strategy implementations and helper functions
**Core Strategy Functions**:

#### Path Resolution Strategies
- `Get-SyncPaths`: Strategy dispatcher based on configuration
- `Get-DateFolderSyncPaths`: Date-based folder synchronization
- `Get-FullDirectorySyncPaths`: Complete directory synchronization
- `Get-DateRangeSyncPaths`: Date range-based synchronization
- `Get-CustomPatternSyncPaths`: Custom pattern synchronization

#### AWS Integration Functions
- `Test-AwsCli`: AWS CLI availability verification
- `Confirm-S3Bucket`: Bucket existence verification and creation
- `Invoke-S3Sync`: AWS S3 sync execution with error handling

#### System Utilities
- `Test-AndCreateFolder`: Directory creation with error handling
- `Test-SystemPrerequisites`: System requirements validation
- `Format-FileSize`: Human-readable file size formatting

### 6. Logging System (`src/logging.ps1`)

**Purpose**: Structured logging with automatic management
**Features**:
- Monthly log file rotation
- Timestamped entries with severity levels
- Console and file output coordination
- Automatic log cleanup based on retention policy

**Log Structure**:
```
[2025-01-15 14:30:25] [INFO] === Starting AWS S3 sync process ===
[2025-01-15 14:30:26] [INFO] [ConfigName] Processing configuration
[2025-01-15 14:30:27] [ERROR] [ConfigName] AWS CLI not found
```

---

## Synchronization Strategies

### 1. DateFolder Strategy
**Use Case**: Daily organized directories (e.g., `2025-01-15/`)
**Path Pattern**: `{base_path}\{date_format}` → `s3://bucket/{structure}`
**Configuration**:
```yaml
sync_strategy:
  type: "DateFolder"
  date_folder_format: "yyyy-MM-dd"  # Configurable date format
```

**Implementation**: `Get-DateFolderSyncPaths` in `utils.ps1`

### 2. FullDirectory Strategy
**Use Case**: Complete directory backups
**Path Pattern**: `{base_path}` (entire directory) → `s3://bucket/{structure}`
**Configuration**:
```yaml
sync_strategy:
  type: "FullDirectory"
```

**Implementation**: `Get-FullDirectorySyncPaths` in `utils.ps1`

### 3. DateRange Strategy
**Use Case**: Files within a date range (e.g., last 7 days)
**Path Pattern**: `{base_path}` with date filtering → `s3://bucket/{structure}`
**Configuration**:
```yaml
sync_strategy:
  type: "DateRange"
  date_range_days_back: 7  # Days to look back
```

**Implementation**: `Get-DateRangeSyncPaths` in `utils.ps1`

### 4. CustomPattern Strategy
**Use Case**: Custom directory patterns with placeholders
**Path Pattern**: User-defined with `{base_path}`, `{year}`, `{month}`, `{day}`
**Configuration**:
```yaml
sync_strategy:
  type: "CustomPattern"
  custom_local_pattern: "{base_path}\\{year}\\{month}"
```

**Implementation**: `Get-CustomPatternSyncPaths` in `utils.ps1`

---

## Configuration System

### Configuration Loading Process

1. **File Location**: `sync-config.yaml` in project root
2. **Module Import**: `powershell-yaml` automatic installation if missing
3. **Structure Validation**: Schema validation with defaults
4. **Configuration Caching**: Singleton pattern for performance

### Configuration Class Structure

```powershell
class SyncConfiguration {
    [string]$ConfigFile     # Path to YAML configuration
    [int]$LogRetentionMonths # Log retention period
    [string]$LogDir         # Log directory path
    [string]$StateFile      # State file path
    [array]$SyncConfigurations # Enabled configurations array
}
```

### Global Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `log_retention_months` | int | 12 | Months to retain log files |
| `log_directory` | string | "log" | Relative path to log directory |
| `state_file` | string | "state.json" | Relative path to state file |

### Sync Configuration Schema

| Section | Required | Type | Description |
|---------|----------|------|-------------|
| `name` | ✅ | string | Unique configuration identifier |
| `description` | ✅ | string | Human-readable description |
| `enabled` | ✅ | boolean | Whether to execute this configuration |
| `local_base_path` | ✅ | string | Source directory path |
| `sync_strategy` | ✅ | object | Strategy configuration |
| `destination_config` | ✅ | object | AWS S3 destination settings |
| `sync_options` | ❌ | array | Additional AWS CLI options |

---

## State Management

### State File Architecture

The state management system uses a JSON file to persist execution information across runs. This enables:

- **Historical tracking**: Complete execution history
- **Resume capability**: Understanding of last successful operations
- **Error tracking**: Consecutive failure counting
- **Performance metrics**: Duration and transfer statistics

### State Initialization Process

1. **File Existence Check**: Verify `state.json` exists
2. **Structure Validation**: Ensure all required sections exist
3. **Schema Migration**: Add missing fields for backward compatibility
4. **Default Values**: Initialize empty state if file is missing/corrupted

### State Update Lifecycle

1. **Execution Start**: `Start-StateExecution` initializes current run
2. **Configuration Processing**: `Set-ConfigurationResult` records individual results
3. **Execution Completion**: `Complete-StateExecution` finalizes run metrics
4. **Persistence**: `Set-State` writes updated state to disk

---

## Command System

### Command Architecture

The command system follows a modular architecture where each command is implemented as a separate PowerShell script in `src/commands/`. This design enables:

- **Separation of concerns**: Each command handles specific functionality
- **Parameter isolation**: Command-specific parameters and validation
- **Independent testing**: Each command can be tested separately
- **Extensibility**: New commands can be added easily

### Available Commands

#### 1. `sync` Command (`src/commands/sync.ps1`)
**Purpose**: Execute main synchronization process
**Parameters**:
- `TargetDate`: Date to synchronize (default: yesterday)

**Workflow**:
1. Load and validate configuration
2. Display configuration summary
3. Verify system prerequisites
4. Execute all enabled synchronization configurations
5. Report final results

#### 2. `status` Command (`src/commands/status.ps1`)
**Purpose**: Display comprehensive system status
**Parameters**:
- `OnlyLastExecution`: Show only last execution information
- `JsonOutput`: Output in JSON format for automation

**Output Sections**:
- Last execution summary
- General statistics
- Per-configuration details
- Last successful synchronizations

#### 3. `strategies` Command (`src/commands/strategies.ps1`)
**Purpose**: Display available synchronization strategies
**Parameters**:
- `ShowExamples`: Include detailed configuration examples

**Information Provided**:
- Strategy descriptions and use cases
- Configuration syntax
- Placeholder explanations
- Real-world examples

#### 4. `install` Command (`src/commands/install.ps1`)
**Purpose**: Install system prerequisites
**Features**:
- AWS CLI installation verification
- PowerShell module dependency management
- System capability verification
- Configuration guidance

#### 5. `clear-logs` Command (`src/commands/clear-logs.ps1`)
**Purpose**: Clean up log files based on retention policy
**Parameters**:
- `RemoveDirectory`: Also remove log directory if empty
- `KeepLastDays`: Override retention policy for recent logs

---

## Development Guidelines

### Code Organization Principles

1. **Modular Design**: Each file has a specific responsibility
2. **Function Naming**: Verb-Noun pattern following PowerShell conventions
3. **Error Handling**: Consistent error handling with logging
4. **Documentation**: Comprehensive inline documentation and examples

### PowerShell Best Practices

#### Function Structure
```powershell
function Verb-Noun {
    <#
    .SYNOPSIS
        Brief description
    .DESCRIPTION
        Detailed description
    .PARAMETER ParameterName
        Parameter description
    .EXAMPLE
        Example usage
    #>
    param(
        [Parameter(Mandatory)]
        [Type] $RequiredParameter,
        
        [Type] $OptionalParameter = "DefaultValue"
    )
    
    try {
        # Implementation
        Write-Log -Message "Function execution details"
        return $result
    }
    catch {
        Write-Log -Message "Error details: $_" -Level "ERROR"
        throw
    }
}
```

#### Error Handling Pattern
```powershell
# Graceful error handling with logging
try {
    $result = Invoke-Operation
    Write-Log -Message "Operation successful"
    return @{ Success = $true; Data = $result }
}
catch {
    $errorMsg = "Operation failed: $_"
    Write-Log -Message $errorMsg -Level "ERROR"
    return @{ Success = $false; Message = $errorMsg }
}
```

### Adding New Synchronization Strategies

1. **Implement Strategy Function**:
   ```powershell
   function Get-CustomStrategySyncPaths {
       param([datetime] $Date, [PSCustomObject] $SyncConfig)
       # Strategy implementation
       return @{
           LocalPath = $localPath
           S3Path = $s3Path
           DayFolder = $dayFolder
           ConfigName = $SyncConfig.name
           StrategyType = "CustomStrategy"
       }
   }
   ```

2. **Add to Strategy Dispatcher**:
   ```powershell
   # In Get-SyncPaths function
   "CustomStrategy" {
       return Get-CustomStrategySyncPaths -Date $Date -SyncConfig $SyncConfig
   }
   ```

3. **Update Documentation**:
   - Add strategy description to `src/commands/strategies.ps1`
   - Include examples in `sync-config.yaml.example`
   - Update this technical documentation

### Adding New Commands

1. **Create Command File**: `src/commands/new-command.ps1`
2. **Implement Command Logic**: Follow existing command patterns
3. **Add to Router**: Update `mochok.ps1` switch statement
4. **Add Help**: Include command in help system
5. **Update Documentation**: Add to README files

### Testing Guidelines

- **Unit Tests**: Create tests in `tests/` directory
- **Integration Tests**: Test complete workflows
- **Error Scenarios**: Test failure conditions
- **Performance Tests**: Verify performance with large datasets

---

## Technical Implementation Details

### AWS CLI Integration

The system integrates with AWS CLI for S3 operations, providing:

- **Profile Support**: Multiple AWS profiles for different environments
- **Region Management**: Automatic region detection and bucket creation
- **Error Handling**: Comprehensive AWS CLI error parsing
- **Option Passthrough**: Direct AWS CLI option support

#### S3 Sync Execution
```powershell
function Invoke-S3Sync {
    param($LocalPath, $S3Path, $SyncOptions, $AwsProfile)
    
    # Build AWS CLI command
    $awsCommand = @("aws", "s3", "sync", $LocalPath, $S3Path)
    if ($AwsProfile -ne "default") {
        $awsCommand += @("--profile", $AwsProfile)
    }
    $awsCommand += $SyncOptions
    
    # Execute with comprehensive error handling
    $process = Start-Process -FilePath "aws" -ArgumentList $awsCommand
    # Process output and return structured result
}
```

### YAML Configuration Processing

Configuration processing involves:

1. **Module Detection**: Automatic `powershell-yaml` installation
2. **YAML Parsing**: Convert YAML to PowerShell objects
3. **Schema Validation**: Ensure required fields exist
4. **Default Application**: Apply default values for optional fields

### Performance Optimization

#### File Counting Optimization
```powershell
# Optimized file counting with error handling
try {
    $filesCount = (Get-ChildItem -LiteralPath $path -File -Recurse -ErrorAction SilentlyContinue | Measure-Object).Count
}
catch {
    Write-Log -Message "Could not count files: $_" -Level "WARNING"
    $filesCount = 0
}
```

#### Parallel Processing Considerations
- Currently sequential for simplicity and error handling
- Future enhancement: parallel configuration processing
- State management designed for concurrent access

### Security Considerations

1. **Credential Management**: Relies on AWS CLI credential chain
2. **Path Validation**: Prevents directory traversal attacks
3. **Error Information**: Sanitized error messages in logs
4. **File Permissions**: Respects file system permissions

### Extensibility Points

1. **Strategy System**: Easily add new synchronization patterns
2. **Command System**: Modular command addition
3. **Configuration Schema**: Backward-compatible extensions
4. **Logging System**: Pluggable output destinations
5. **State Management**: Extensible state structure

---

## Troubleshooting and Maintenance

### Common Issues and Solutions

1. **AWS CLI Not Found**
   - Install AWS CLI v2
   - Verify PATH environment variable
   - Test with `aws --version`

2. **PowerShell Module Missing**
   - System will auto-install `powershell-yaml`
   - Manual install: `Install-Module powershell-yaml -Force`

3. **Permission Errors**
   - Verify file system permissions
   - Check AWS credentials and S3 permissions
   - Ensure bucket write access

4. **Configuration Errors**
   - Validate YAML syntax
   - Check required fields
   - Verify path existence

### Monitoring and Alerting

- **Log Files**: Monitor `log/sync_YYYY-MM.log` for errors
- **State File**: Check `state.json` for consecutive failures
- **Exit Codes**: Use command exit codes for automation
- **JSON Output**: Parse status command JSON for monitoring

### Backup and Recovery

- **Configuration**: Version control `sync-config.yaml`
- **State**: Regular backup of `state.json`
- **Logs**: Archive important log files before cleanup
- **S3 Data**: Implement S3 versioning and backup policies

---

This technical documentation provides a comprehensive understanding of the Mochok system architecture, implementation details, and development guidelines. For user-oriented documentation, refer to the main [README.md](../README.md) file.