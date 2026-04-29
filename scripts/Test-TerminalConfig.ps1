[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "lib\\TerminalConfig.Common.ps1")

# 函数：输出校验步骤，便于阅读执行过程。
function Write-Step {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    Write-Host "[*] $Message" -ForegroundColor Cyan
}

# 函数：输出单项校验通过结果。
function Write-Success {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    Write-Host "[+] $Message" -ForegroundColor Green
}

# 函数：断言条件成立，不成立时立即中止并返回可读错误。
function Assert-Condition {
    param(
        [Parameter(Mandatory)]
        [bool]$Condition,

        [Parameter(Mandatory)]
        [string]$ErrorMessage
    )

    if (-not $Condition) {
        throw $ErrorMessage
    }
}

# 函数：检查给定配置对象中不存在指定键，确保共享字段没有重新散落到具体 profile 中。
function Assert-MapMissingKeys {
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Map,

        [Parameter(Mandatory)]
        [string[]]$Keys,

        [Parameter(Mandatory)]
        [string]$Label
    )

    foreach ($key in $Keys) {
        Assert-Condition -Condition (-not (Test-MapHasKey -Map $Map -Key $key)) -ErrorMessage "$Label 不应再直接定义共享字段：$key"
    }
}

$configRoot = Join-Path $RepoRoot "configs"
$themeSelection = Get-ThemeSelection -ConfigRoot $configRoot

Write-Step "校验主题选择与模板资源一致性"
Assert-ThemeSelectionMatchesConfig -ConfigRoot $configRoot -ThemeSelection $themeSelection
Write-Success "默认 theme、color scheme 与 starship palette 均可解析"

Write-Step "校验 Windows Terminal JSON 模板"
$baseSettings = Get-ResolvedWindowsTerminalBaseSettings -ConfigRoot $configRoot -ThemeSelection $themeSelection
$profileDefaults = Get-ResolvedWindowsTerminalProfileDefaults -ConfigRoot $configRoot -ThemeSelection $themeSelection
$managedProfiles = Get-ManagedWindowsTerminalProfiles -ConfigRoot $configRoot -ThemeSelection $themeSelection
$schemes = Get-JsonItemsFromDirectory -DirectoryPath (Join-Path $configRoot "windows-terminal\\schemes")
$themes = Get-JsonItemsFromDirectory -DirectoryPath (Join-Path $configRoot "windows-terminal\\themes")
$actions = Read-JsonData -Path (Join-Path $configRoot "windows-terminal\\actions.json")
$keybindings = Read-JsonData -Path (Join-Path $configRoot "windows-terminal\\keybindings.json")
$newTabMenu = Read-JsonData -Path (Join-Path $configRoot "windows-terminal\\new-tab-menu.json")

Assert-Condition -Condition ($baseSettings["theme"] -eq $themeSelection["windowsTerminalTheme"]) -ErrorMessage "base-settings.json 中的默认 theme 解析结果不正确"
Assert-Condition -Condition ($profileDefaults["colorScheme"] -eq $themeSelection["windowsTerminalColorScheme"]) -ErrorMessage "defaults.json 中的默认 colorScheme 解析结果不正确"
Assert-Condition -Condition ($managedProfiles.Count -eq 2) -ErrorMessage "托管 PowerShell profiles 数量异常，应为 2"
Assert-Condition -Condition ($schemes.Count -ge 1) -ErrorMessage "schemes 目录不能为空"
Assert-Condition -Condition ($themes.Count -ge 1) -ErrorMessage "themes 目录不能为空"
Assert-Condition -Condition ($actions.Count -ge 1) -ErrorMessage "actions.json 至少应包含一个命令"
Assert-Condition -Condition ($keybindings.Count -ge 1) -ErrorMessage "keybindings.json 至少应包含一个快捷键"
Assert-Condition -Condition ($newTabMenu.Count -ge 1) -ErrorMessage "new-tab-menu.json 至少应包含一个项"
Write-Success "Windows Terminal 基础模板均可解析"

Write-Step "校验具体 profile 与共享 profile 片段的职责边界"
$sharedPowerShellKeys = @("antialiasingMode", "cursorShape", "padding", "startingDirectory")
$specificPowerShellKeys = @("font", "opacity", "useAcrylic", "colorScheme")
$powerShellProfileSource = Read-JsonData -Path (Join-Path $configRoot "windows-terminal\\profiles\\powershell.json")
$windowsPowerShellProfileSource = Read-JsonData -Path (Join-Path $configRoot "windows-terminal\\profiles\\windows-powershell.json")

Assert-MapMissingKeys -Map $powerShellProfileSource -Keys ($sharedPowerShellKeys + $specificPowerShellKeys) -Label "powershell.json"
Assert-MapMissingKeys -Map $windowsPowerShellProfileSource -Keys ($sharedPowerShellKeys + $specificPowerShellKeys) -Label "windows-powershell.json"
Assert-Condition -Condition ($managedProfiles[0]["name"] -eq "PowerShell") -ErrorMessage "第一个托管 profile 应为 PowerShell"
Assert-Condition -Condition ($managedProfiles[1]["name"] -eq "Windows PowerShell") -ErrorMessage "第二个托管 profile 应为 Windows PowerShell"
foreach ($profile in $managedProfiles) {
    foreach ($sharedKey in $sharedPowerShellKeys) {
        Assert-Condition -Condition (Test-MapHasKey -Map $profile -Key $sharedKey) -ErrorMessage "托管 profile 缺少共享字段：$sharedKey"
    }
}
Write-Success "PowerShell profile 共享字段已集中到 shared-powershell.json"

Write-Step "校验 Starship 配置模板"
$resolvedStarshipContent = Get-ResolvedStarshipContent -ConfigRoot $configRoot -ThemeSelection $themeSelection
$expectedPaletteLine = 'palette = "' + $themeSelection["starshipPalette"] + '"'
Assert-Condition -Condition ($resolvedStarshipContent.Contains($expectedPaletteLine)) -ErrorMessage "starship.toml 的默认 palette 未正确解析"
Assert-Condition -Condition ($resolvedStarshipContent.Contains("[palettes." + $themeSelection["starshipPalette"] + "]")) -ErrorMessage "starship.toml 缺少默认 palette 的定义段"
Write-Success "Starship 模板可按主题选择生成最终配置"

Write-Step "校验 PowerShell profile 模板与共享 profile"
$sharedInstallPath = Get-SharedPowerShellProfileInstallPath -HomePath $HOME
$generatedPowerShell7Profile = Get-GeneratedPowerShellProfileContent -TemplatePath (Join-Path $configRoot "powershell\\Microsoft.PowerShell_profile.ps1") -SharedProfileInstallPath $sharedInstallPath
$generatedWindowsPowerShellProfile = Get-GeneratedPowerShellProfileContent -TemplatePath (Join-Path $configRoot "windows-powershell\\profile.ps1") -SharedProfileInstallPath $sharedInstallPath
$commonProfileContent = Get-Content -LiteralPath (Join-Path $configRoot "shared\\powershell\\common-profile.ps1") -Raw -Encoding UTF8

Assert-Condition -Condition ($generatedPowerShell7Profile.Contains($sharedInstallPath)) -ErrorMessage "PowerShell 7 profile 未正确注入共享 profile 路径"
Assert-Condition -Condition ($generatedWindowsPowerShellProfile.Contains($sharedInstallPath)) -ErrorMessage "Windows PowerShell profile 未正确注入共享 profile 路径"
Assert-Condition -Condition ($generatedPowerShell7Profile.Contains('. $sharedProfilePath')) -ErrorMessage "PowerShell 7 profile 缺少共享 profile 加载逻辑"
Assert-Condition -Condition ($generatedWindowsPowerShellProfile.Contains('. $sharedProfilePath')) -ErrorMessage "Windows PowerShell profile 缺少共享 profile 加载逻辑"
Assert-Condition -Condition ($commonProfileContent.Contains("Set-TerminalUtf8Encoding")) -ErrorMessage "common-profile.ps1 缺少 UTF-8 编码初始化函数"
Assert-Condition -Condition ($commonProfileContent.Contains("Initialize-StarshipPrompt")) -ErrorMessage "common-profile.ps1 缺少 Starship 初始化函数"
Write-Success "PowerShell profile 模板与共享逻辑组装正常"

Write-Host ""
Write-Success "全部配置校验通过。"
