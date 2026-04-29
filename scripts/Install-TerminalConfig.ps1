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

. (Join-Path $PSScriptRoot "lib\\TerminalConfig.Common.ps1")

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

# 函数：写入动态生成的文本文件，并在覆盖前先备份旧文件。
function Install-GeneratedFile {
    param(
        [Parameter(Mandatory)]
        [string]$Content,

        [Parameter(Mandatory)]
        [string]$DestinationPath,

        [Parameter(Mandatory)]
        [string]$BackupSessionPath
    )

    Ensure-Directory -Path (Split-Path -Path $DestinationPath -Parent)
    Backup-File -Path $DestinationPath -BackupSessionPath $BackupSessionPath

    if ($PSCmdlet.ShouldProcess($DestinationPath, "写入生成文件")) {
        Write-TextData -Content $Content -Path $DestinationPath
    }
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

# 函数：安装由模板和主题选择共同生成的 Starship 配置。
function Install-StarshipConfiguration {
    param(
        [Parameter(Mandatory)]
        [string]$ConfigRoot,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$ThemeSelection,

        [Parameter(Mandatory)]
        [string]$BackupSessionPath
    )

    $starshipContent = Get-ResolvedStarshipContent -ConfigRoot $ConfigRoot -ThemeSelection $ThemeSelection
    Install-GeneratedFile -Content $starshipContent -DestinationPath (Join-Path $HOME ".config\\starship.toml") -BackupSessionPath $BackupSessionPath
}

# 函数：安装共享 PowerShell profile，并为两个 PowerShell 版本生成最终 bootstrap profile。
function Install-PowerShellProfiles {
    param(
        [Parameter(Mandatory)]
        [string]$ConfigRoot,

        [Parameter(Mandatory)]
        [string]$BackupSessionPath,

        [switch]$InstallPowerShell7Profile,

        [switch]$InstallWindowsPowerShellProfile
    )

    if (-not $InstallPowerShell7Profile -and -not $InstallWindowsPowerShellProfile) {
        return
    }

    $sharedProfileSourcePath = Join-Path $ConfigRoot "shared\\powershell\\common-profile.ps1"
    $sharedProfileInstallPath = Get-SharedPowerShellProfileInstallPath -HomePath $HOME
    Install-PlainFile -SourcePath $sharedProfileSourcePath -DestinationPath $sharedProfileInstallPath -BackupSessionPath $BackupSessionPath

    if ($InstallPowerShell7Profile) {
        $powerShell7TemplatePath = Join-Path $ConfigRoot "powershell\\Microsoft.PowerShell_profile.ps1"
        $powerShell7Content = Get-GeneratedPowerShellProfileContent -TemplatePath $powerShell7TemplatePath -SharedProfileInstallPath $sharedProfileInstallPath
        Install-GeneratedFile -Content $powerShell7Content -DestinationPath (Join-Path $HOME "Documents\\PowerShell\\Microsoft.PowerShell_profile.ps1") -BackupSessionPath $BackupSessionPath
        Install-PlainFile -SourcePath (Join-Path $ConfigRoot "powershell\\powershell.config.json") -DestinationPath (Join-Path $HOME "Documents\\PowerShell\\powershell.config.json") -BackupSessionPath $BackupSessionPath
    }

    if ($InstallWindowsPowerShellProfile) {
        $windowsPowerShellTemplatePath = Join-Path $ConfigRoot "windows-powershell\\profile.ps1"
        $windowsPowerShellContent = Get-GeneratedPowerShellProfileContent -TemplatePath $windowsPowerShellTemplatePath -SharedProfileInstallPath $sharedProfileInstallPath
        Install-GeneratedFile -Content $windowsPowerShellContent -DestinationPath (Join-Path $HOME "Documents\\WindowsPowerShell\\profile.ps1") -BackupSessionPath $BackupSessionPath
    }
}

# 函数：合并并安装 Windows Terminal 配置。
function Install-WindowsTerminalConfiguration {
    param(
        [Parameter(Mandatory)]
        [string]$ConfigRoot,

        [Parameter(Mandatory)]
        [string]$BackupSessionPath,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$ThemeSelection,

        [string]$SettingsPath,

        [switch]$SetPowerShellDefault
    )

    $settingsJsonPath = Get-WindowsTerminalSettingsJsonPath -CustomPath $SettingsPath
    $settings = if (Test-Path -LiteralPath $settingsJsonPath) {
        Read-JsonData -Path $settingsJsonPath
    } else {
        [ordered]@{}
    }

    if ($null -eq $settings) {
        $settings = [ordered]@{}
    }

    $baseSettings = Get-ResolvedWindowsTerminalBaseSettings -ConfigRoot $ConfigRoot -ThemeSelection $ThemeSelection
    $profileDefaults = Get-ResolvedWindowsTerminalProfileDefaults -ConfigRoot $ConfigRoot -ThemeSelection $ThemeSelection
    $managedProfiles = Get-ManagedWindowsTerminalProfiles -ConfigRoot $ConfigRoot -ThemeSelection $ThemeSelection
    $schemeItems = Get-JsonItemsFromDirectory -DirectoryPath (Join-Path $ConfigRoot "windows-terminal\\schemes")
    $themeItems = Get-JsonItemsFromDirectory -DirectoryPath (Join-Path $ConfigRoot "windows-terminal\\themes")
    $actions = Read-JsonData -Path (Join-Path $ConfigRoot "windows-terminal\\actions.json")
    $keybindings = Read-JsonData -Path (Join-Path $ConfigRoot "windows-terminal\\keybindings.json")
    $newTabMenu = Read-JsonData -Path (Join-Path $ConfigRoot "windows-terminal\\new-tab-menu.json")

    $settings = Merge-Map -Base $settings -Overlay $baseSettings

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

    if (-not (Test-MapHasKey -Map $settings -Key "themes")) {
        $settings["themes"] = @()
    }

    $settings["profiles"]["defaults"] = Merge-Map -Base $settings["profiles"]["defaults"] -Overlay $profileDefaults
    $settings["profiles"]["list"] = Upsert-ArrayItemsByKey -Items @($settings["profiles"]["list"]) -NewItems $managedProfiles -KeyName "name"
    $settings["schemes"] = Upsert-ArrayItemsByKey -Items @($settings["schemes"]) -NewItems $schemeItems -KeyName "name"
    $settings["themes"] = Upsert-ArrayItemsByKey -Items @($settings["themes"]) -NewItems $themeItems -KeyName "name"
    $settings["actions"] = Upsert-ArrayItemsByKey -Items @($settings["actions"]) -NewItems @($actions) -KeyName "id"
    $settings["keybindings"] = Upsert-ArrayItemsByKey -Items @($settings["keybindings"]) -NewItems @($keybindings) -KeyName "id"
    $settings["newTabMenu"] = @($newTabMenu)

    if ($SetPowerShellDefault) {
        Set-DefaultProfileGuidByName -Settings $settings -ProfileName "PowerShell"
    }

    Backup-File -Path $settingsJsonPath -BackupSessionPath $BackupSessionPath

    if ($PSCmdlet.ShouldProcess($settingsJsonPath, "写入 Windows Terminal 配置")) {
        Write-JsonData -Data $settings -Path $settingsJsonPath
    }
}

$configRoot = Join-Path $RepoRoot "configs"
$themeSelection = Get-ThemeSelection -ConfigRoot $configRoot
Assert-ThemeSelectionMatchesConfig -ConfigRoot $configRoot -ThemeSelection $themeSelection

$backupSessionPath = New-BackupSessionDirectory -RootPath $BackupRoot
Write-Step "本次安装备份目录：$backupSessionPath"

if (-not $SkipPowerShell -or -not $SkipLegacyWindowsPowerShell) {
    Write-Step "安装共享 PowerShell profile 与 bootstrap profile"
    Install-PowerShellProfiles -ConfigRoot $configRoot -BackupSessionPath $backupSessionPath -InstallPowerShell7Profile:(-not $SkipPowerShell) -InstallWindowsPowerShellProfile:(-not $SkipLegacyWindowsPowerShell)
}

if (-not $SkipStarship) {
    Write-Step "安装 Starship 配置"
    Install-StarshipConfiguration -ConfigRoot $configRoot -ThemeSelection $themeSelection -BackupSessionPath $backupSessionPath
}

if (-not $SkipWindowsTerminal) {
    Write-Step "合并 Windows Terminal 配置"
    Install-WindowsTerminalConfiguration -ConfigRoot $configRoot -BackupSessionPath $backupSessionPath -ThemeSelection $themeSelection -SettingsPath $WindowsTerminalSettingsPath -SetPowerShellDefault:$SetPowerShellAsDefault
}

Write-Step "完成。请重启 Windows Terminal 以加载新配置。"
