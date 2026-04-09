[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$BackupRoot = (Join-Path $HOME ".terminal-config-backups"),
    [string]$WindowsTerminalSettingsPath,
    [switch]$SetPowerShellAsDefault,
    [switch]$SkipPowerShell,
    [switch]$SkipStarship,
    [switch]$SkipWindowsTerminal,
    [switch]$SkipLegacyWindowsPowerShell
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# 函数：输出带颜色的步骤日志，便于观察安装进度。
function Write-Step {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    Write-Host "[*] $Message" -ForegroundColor Cyan
}

# 函数：确保目标目录存在，不存在时自动创建。
function Ensure-Directory {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

# 函数：读取 JSON 文件并转换为 PowerShell 可操作对象。
function Read-JsonData {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "未找到 JSON 文件：$Path"
    }

    $content = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    if ([string]::IsNullOrWhiteSpace($content)) {
        return $null
    }

    return ConvertFrom-Json -InputObject $content -AsHashtable
}

# 函数：将对象以 UTF-8 编码写入 JSON 文件。
function Write-JsonData {
    param(
        [Parameter(Mandatory)]
        [object]$Data,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    $json = $Data | ConvertTo-Json -Depth 64
    [System.IO.File]::WriteAllText($Path, $json, $utf8NoBom)
}

# 函数：判断字典对象中是否存在指定键。
function Test-MapHasKey {
    param(
        [Parameter(Mandatory)]
        [object]$Map,

        [Parameter(Mandatory)]
        [string]$Key
    )

    return ($Map -is [System.Collections.IDictionary]) -and ($Map.Keys -contains $Key)
}

# 函数：递归合并字典，保留未覆盖的现有配置。
function Merge-Map {
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Base,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Overlay
    )

    foreach ($key in $Overlay.Keys) {
        # 关键逻辑：如果两边都是字典，则递归合并；否则以仓库配置覆盖目标配置。
        if ((Test-MapHasKey -Map $Base -Key $key) -and
            ($Base[$key] -is [System.Collections.IDictionary]) -and
            ($Overlay[$key] -is [System.Collections.IDictionary])) {
            $Base[$key] = Merge-Map -Base $Base[$key] -Overlay $Overlay[$key]
        } else {
            $Base[$key] = $Overlay[$key]
        }
    }

    return $Base
}

# 函数：为本次安装创建一个独立备份目录。
function New-BackupSessionDirectory {
    param(
        [Parameter(Mandatory)]
        [string]$RootPath
    )

    Ensure-Directory -Path $RootPath
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $sessionPath = Join-Path $RootPath $timestamp
    Ensure-Directory -Path $sessionPath
    return $sessionPath
}

# 函数：将目标文件备份到本次安装目录中。
function Backup-File {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$BackupSessionPath
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    $relativePath = $Path.Replace(":", "")
    $relativePath = $relativePath.TrimStart("\")
    $backupPath = Join-Path $BackupSessionPath $relativePath
    $backupDirectory = Split-Path -Path $backupPath -Parent

    Ensure-Directory -Path $backupDirectory
    Copy-Item -LiteralPath $Path -Destination $backupPath -Force
}

# 函数：复制普通配置文件，并在覆盖前先备份旧文件。
function Install-PlainFile {
    param(
        [Parameter(Mandatory)]
        [string]$SourcePath,

        [Parameter(Mandatory)]
        [string]$DestinationPath,

        [Parameter(Mandatory)]
        [string]$BackupSessionPath
    )

    Ensure-Directory -Path (Split-Path -Path $DestinationPath -Parent)
    Backup-File -Path $DestinationPath -BackupSessionPath $BackupSessionPath

    if ($PSCmdlet.ShouldProcess($DestinationPath, "复制配置文件")) {
        Copy-Item -LiteralPath $SourcePath -Destination $DestinationPath -Force
    }
}

# 函数：按唯一键合并对象数组，用于 actions、keybindings、schemes 与 profiles。
function Upsert-ArrayItemsByKey {
    param(
        [Parameter(Mandatory)]
        [object[]]$Items,

        [Parameter(Mandatory)]
        [object[]]$NewItems,

        [Parameter(Mandatory)]
        [string]$KeyName
    )

    $result = [System.Collections.Generic.List[object]]::new()
    foreach ($item in @($Items)) {
        $result.Add($item)
    }

    foreach ($newItem in @($NewItems)) {
        if (-not ($newItem -is [System.Collections.IDictionary])) {
            $result.Add($newItem)
            continue
        }

        $matchedIndex = -1
        for ($index = 0; $index -lt $result.Count; $index++) {
            $existingItem = $result[$index]
            if (($existingItem -is [System.Collections.IDictionary]) -and
                (Test-MapHasKey -Map $existingItem -Key $KeyName) -and
                (Test-MapHasKey -Map $newItem -Key $KeyName) -and
                $existingItem[$KeyName] -eq $newItem[$KeyName]) {
                $matchedIndex = $index
                break
            }
        }

        # 关键逻辑：同键对象递归合并，不同键对象追加，尽量保留目标机器已有的其它配置。
        if ($matchedIndex -ge 0) {
            $result[$matchedIndex] = Merge-Map -Base $result[$matchedIndex] -Overlay $newItem
        } else {
            $result.Add($newItem)
        }
    }

    return $result.ToArray()
}

# 函数：定位 Windows Terminal 的 settings.json。
function Get-WindowsTerminalSettingsJsonPath {
    param(
        [string]$CustomPath
    )

    if ($CustomPath) {
        return $CustomPath
    }

    $candidates = @(
        (Join-Path $env:LOCALAPPDATA "Packages\\Microsoft.WindowsTerminal_8wekyb3d8bbwe\\LocalState\\settings.json"),
        (Join-Path $env:LOCALAPPDATA "Packages\\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\\LocalState\\settings.json")
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    throw "未找到 Windows Terminal 的 settings.json，请先安装并启动一次 Windows Terminal。"
}

# 函数：把指定 profile 设置为默认 profile。
function Set-DefaultProfileGuidByName {
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Settings,

        [Parameter(Mandatory)]
        [string]$ProfileName
    )

    if (-not (Test-MapHasKey -Map $Settings -Key "profiles")) {
        return
    }

    if (-not (Test-MapHasKey -Map $Settings["profiles"] -Key "list")) {
        return
    }

    foreach ($profile in @($Settings["profiles"]["list"])) {
        if (($profile -is [System.Collections.IDictionary]) -and
            (Test-MapHasKey -Map $profile -Key "name") -and
            (Test-MapHasKey -Map $profile -Key "guid") -and
            $profile["name"] -eq $ProfileName) {
            $Settings["defaultProfile"] = $profile["guid"]
            return
        }
    }
}

# 函数：合并并安装 Windows Terminal 配置。
function Install-WindowsTerminalConfiguration {
    param(
        [Parameter(Mandatory)]
        [string]$ConfigRoot,

        [Parameter(Mandatory)]
        [string]$BackupSessionPath,

        [string]$SettingsPath,

        [switch]$SetPowerShellDefault
    )

    $settingsJsonPath = Get-WindowsTerminalSettingsJsonPath -CustomPath $SettingsPath
    $settings = Read-JsonData -Path $settingsJsonPath
    if ($null -eq $settings) {
        $settings = [ordered]@{}
    }

    $baseSettingsPath = Join-Path $ConfigRoot "windows-terminal\\base-settings.json"
    $actionsPath = Join-Path $ConfigRoot "windows-terminal\\actions.json"
    $keybindingsPath = Join-Path $ConfigRoot "windows-terminal\\keybindings.json"
    $newTabMenuPath = Join-Path $ConfigRoot "windows-terminal\\new-tab-menu.json"
    $defaultsPath = Join-Path $ConfigRoot "windows-terminal\\profiles\\defaults.json"
    $powerShellProfilePath = Join-Path $ConfigRoot "windows-terminal\\profiles\\powershell.json"
    $windowsPowerShellProfilePath = Join-Path $ConfigRoot "windows-terminal\\profiles\\windows-powershell.json"
    $schemeDirectoryPath = Join-Path $ConfigRoot "windows-terminal\\schemes"

    $settings = Merge-Map -Base $settings -Overlay (Read-JsonData -Path $baseSettingsPath)

    if (-not (Test-MapHasKey -Map $settings -Key "profiles")) {
        $settings["profiles"] = [ordered]@{}
    }

    if (-not (Test-MapHasKey -Map $settings["profiles"] -Key "defaults")) {
        $settings["profiles"]["defaults"] = [ordered]@{}
    }

    if (-not (Test-MapHasKey -Map $settings["profiles"] -Key "list")) {
        $settings["profiles"]["list"] = @()
    }

    if (-not (Test-MapHasKey -Map $settings -Key "schemes")) {
        $settings["schemes"] = @()
    }

    if (-not (Test-MapHasKey -Map $settings -Key "actions")) {
        $settings["actions"] = @()
    }

    if (-not (Test-MapHasKey -Map $settings -Key "keybindings")) {
        $settings["keybindings"] = @()
    }

    $settings["profiles"]["defaults"] = Merge-Map -Base $settings["profiles"]["defaults"] -Overlay (Read-JsonData -Path $defaultsPath)

    # 关键逻辑：自动收集 schemes 目录下的所有主题文件，避免每新增一套主题都要重复修改安装脚本。
    $schemeItems = Get-ChildItem -LiteralPath $schemeDirectoryPath -Filter "*.json" -File | Sort-Object Name | ForEach-Object {
        Read-JsonData -Path $_.FullName
    }
    $settings["schemes"] = Upsert-ArrayItemsByKey -Items @($settings["schemes"]) -NewItems @($schemeItems) -KeyName "name"
    $settings["profiles"]["list"] = Upsert-ArrayItemsByKey -Items @($settings["profiles"]["list"]) -NewItems @(
        (Read-JsonData -Path $powerShellProfilePath),
        (Read-JsonData -Path $windowsPowerShellProfilePath)
    ) -KeyName "name"
    $settings["actions"] = Upsert-ArrayItemsByKey -Items @($settings["actions"]) -NewItems @(Read-JsonData -Path $actionsPath) -KeyName "id"
    $settings["keybindings"] = Upsert-ArrayItemsByKey -Items @($settings["keybindings"]) -NewItems @(Read-JsonData -Path $keybindingsPath) -KeyName "id"
    $settings["newTabMenu"] = @(Read-JsonData -Path $newTabMenuPath)

    if ($SetPowerShellDefault) {
        Set-DefaultProfileGuidByName -Settings $settings -ProfileName "PowerShell"
    }

    Backup-File -Path $settingsJsonPath -BackupSessionPath $BackupSessionPath

    if ($PSCmdlet.ShouldProcess($settingsJsonPath, "写入 Windows Terminal 配置")) {
        Write-JsonData -Data $settings -Path $settingsJsonPath
    }
}

$configRoot = Join-Path $RepoRoot "configs"
$backupSessionPath = New-BackupSessionDirectory -RootPath $BackupRoot

Write-Step "本次安装备份目录：$backupSessionPath"

if (-not $SkipPowerShell) {
    Write-Step "安装 PowerShell 7 配置"
    Install-PlainFile -SourcePath (Join-Path $configRoot "powershell\\Microsoft.PowerShell_profile.ps1") -DestinationPath (Join-Path $HOME "Documents\\PowerShell\\Microsoft.PowerShell_profile.ps1") -BackupSessionPath $backupSessionPath
    Install-PlainFile -SourcePath (Join-Path $configRoot "powershell\\powershell.config.json") -DestinationPath (Join-Path $HOME "Documents\\PowerShell\\powershell.config.json") -BackupSessionPath $backupSessionPath
}

if (-not $SkipStarship) {
    Write-Step "安装 Starship 配置"
    Install-PlainFile -SourcePath (Join-Path $configRoot "starship\\starship.toml") -DestinationPath (Join-Path $HOME ".config\\starship.toml") -BackupSessionPath $backupSessionPath
}

if (-not $SkipLegacyWindowsPowerShell) {
    Write-Step "安装 Windows PowerShell 5 兼容 profile"
    Install-PlainFile -SourcePath (Join-Path $configRoot "windows-powershell\\profile.ps1") -DestinationPath (Join-Path $HOME "Documents\\WindowsPowerShell\\profile.ps1") -BackupSessionPath $backupSessionPath
}

if (-not $SkipWindowsTerminal) {
    Write-Step "合并 Windows Terminal 配置"
    Install-WindowsTerminalConfiguration -ConfigRoot $configRoot -BackupSessionPath $backupSessionPath -SettingsPath $WindowsTerminalSettingsPath -SetPowerShellDefault:$SetPowerShellAsDefault
}

Write-Step "完成。请重启 Windows Terminal 以加载新配置。"
