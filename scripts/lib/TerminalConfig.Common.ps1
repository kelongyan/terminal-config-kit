# 函数：读取 UTF-8 JSON 文件并转换为 PowerShell 可操作对象。
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

# 函数：将对象以 UTF-8 无 BOM 编码写入 JSON 文件。
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

# 函数：将纯文本以 UTF-8 无 BOM 编码写入文件。
function Write-TextData {
    param(
        [Parameter(Mandatory)]
        [string]$Content,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
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

# 函数：递归合并字典，后者的值覆盖前者对应键。
function Merge-Map {
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Base,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Overlay
    )

    foreach ($key in $Overlay.Keys) {
        # 关键逻辑：两边同为字典时递归合并，其余场景直接使用覆盖值。
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

# 函数：按唯一键合并对象数组，用于 Windows Terminal 的 actions、profiles、schemes 与 themes。
function Upsert-ArrayItemsByKey {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Items,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
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

        # 关键逻辑：同键对象递归合并，不同键对象直接追加，尽量保留目标机器上的其它项目。
        if ($matchedIndex -ge 0) {
            $result[$matchedIndex] = Merge-Map -Base $result[$matchedIndex] -Overlay $newItem
        } else {
            $result.Add($newItem)
        }
    }

    return ,($result.ToArray())
}

# 函数：读取默认主题选择，作为多个配置模板的唯一真相源。
function Get-ThemeSelection {
    param(
        [Parameter(Mandatory)]
        [string]$ConfigRoot
    )

    $selectionPath = Join-Path $ConfigRoot "shared\\theme-selection.json"
    $selection = Read-JsonData -Path $selectionPath
    $requiredKeys = @("windowsTerminalTheme", "windowsTerminalColorScheme", "starshipPalette")

    foreach ($requiredKey in $requiredKeys) {
        if (-not (Test-MapHasKey -Map $selection -Key $requiredKey) -or
            [string]::IsNullOrWhiteSpace([string]$selection[$requiredKey])) {
            throw "主题选择文件缺少必填键：$requiredKey"
        }
    }

    return $selection
}

# 函数：构造模板占位符与实际默认值的映射关系。
function Get-ThemePlaceholderMap {
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$ThemeSelection
    )

    return [ordered]@{
        "__TERMINAL_CONFIG_THEME__" = [string]$ThemeSelection["windowsTerminalTheme"]
        "__TERMINAL_CONFIG_COLOR_SCHEME__" = [string]$ThemeSelection["windowsTerminalColorScheme"]
        "__TERMINAL_CONFIG_STARSHIP_PALETTE__" = [string]$ThemeSelection["starshipPalette"]
    }
}

# 函数：在纯文本模板中替换占位符。
function Resolve-TextPlaceholders {
    param(
        [Parameter(Mandatory)]
        [string]$Content,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Replacements
    )

    $resolvedContent = $Content
    foreach ($key in $Replacements.Keys) {
        $resolvedContent = $resolvedContent.Replace([string]$key, [string]$Replacements[$key])
    }

    return $resolvedContent
}

# 函数：在 JSON 解析后的对象中递归替换占位符。
function Resolve-ObjectPlaceholders {
    param(
        [Parameter(Mandatory)]
        [object]$Data,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Replacements
    )

    if ($Data -is [string]) {
        if ($Replacements.Keys -contains $Data) {
            return $Replacements[$Data]
        }

        return $Data
    }

    if ($Data -is [System.Collections.IDictionary]) {
        $resolvedMap = [ordered]@{}
        foreach ($key in $Data.Keys) {
            $resolvedMap[$key] = Resolve-ObjectPlaceholders -Data $Data[$key] -Replacements $Replacements
        }

        return $resolvedMap
    }

    if (($Data -is [System.Collections.IEnumerable]) -and -not ($Data -is [string])) {
        $resolvedItems = [System.Collections.Generic.List[object]]::new()
        foreach ($item in $Data) {
            $resolvedItems.Add((Resolve-ObjectPlaceholders -Data $item -Replacements $Replacements))
        }

        return $resolvedItems.ToArray()
    }

    return $Data
}

# 函数：读取目录中的全部 JSON 文件，按文件名排序后返回数组。
function Get-JsonItemsFromDirectory {
    param(
        [Parameter(Mandatory)]
        [string]$DirectoryPath
    )

    if (-not (Test-Path -LiteralPath $DirectoryPath)) {
        return ,@()
    }

    return ,@(Get-ChildItem -LiteralPath $DirectoryPath -Filter "*.json" -File |
        Sort-Object Name |
        ForEach-Object {
            Read-JsonData -Path $_.FullName
        })
}

# 函数：读取并解析 Windows Terminal 的应用级基础设置。
function Get-ResolvedWindowsTerminalBaseSettings {
    param(
        [Parameter(Mandatory)]
        [string]$ConfigRoot,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$ThemeSelection
    )

    $baseSettingsPath = Join-Path $ConfigRoot "windows-terminal\\base-settings.json"
    $baseSettings = Read-JsonData -Path $baseSettingsPath
    return Resolve-ObjectPlaceholders -Data $baseSettings -Replacements (Get-ThemePlaceholderMap -ThemeSelection $ThemeSelection)
}

# 函数：读取并解析 Windows Terminal 的全局默认 profile 设置。
function Get-ResolvedWindowsTerminalProfileDefaults {
    param(
        [Parameter(Mandatory)]
        [string]$ConfigRoot,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$ThemeSelection
    )

    $defaultsPath = Join-Path $ConfigRoot "windows-terminal\\profiles\\defaults.json"
    $defaults = Read-JsonData -Path $defaultsPath
    return Resolve-ObjectPlaceholders -Data $defaults -Replacements (Get-ThemePlaceholderMap -ThemeSelection $ThemeSelection)
}

# 函数：组装仓库托管的 Windows Terminal PowerShell profiles，避免在 profile 文件里重复维护共享字段。
function Get-ManagedWindowsTerminalProfiles {
    param(
        [Parameter(Mandatory)]
        [string]$ConfigRoot,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$ThemeSelection
    )

    $profileRoot = Join-Path $ConfigRoot "windows-terminal\\profiles"
    $replacements = Get-ThemePlaceholderMap -ThemeSelection $ThemeSelection
    $sharedProfile = Resolve-ObjectPlaceholders -Data (Read-JsonData -Path (Join-Path $profileRoot "shared-powershell.json")) -Replacements $replacements
    $profileFiles = @("powershell.json", "windows-powershell.json")
    $profiles = [System.Collections.Generic.List[object]]::new()

    foreach ($profileFile in $profileFiles) {
        $profileData = Resolve-ObjectPlaceholders -Data (Read-JsonData -Path (Join-Path $profileRoot $profileFile)) -Replacements $replacements
        $managedProfile = [ordered]@{}
        $managedProfile = Merge-Map -Base $managedProfile -Overlay $sharedProfile
        $managedProfile = Merge-Map -Base $managedProfile -Overlay $profileData
        $profiles.Add($managedProfile)
    }

    return ,($profiles.ToArray())
}

# 函数：返回共享 PowerShell profile 安装到用户目录后的统一路径。
function Get-SharedPowerShellProfileInstallPath {
    param(
        [Parameter(Mandatory)]
        [string]$HomePath
    )

    return Join-Path $HomePath "Documents\\terminal-config-kit\\common-profile.ps1"
}

# 函数：将文件路径转义为可安全写入 PowerShell 单引号字符串字面量的内容。
function Convert-ToPowerShellSingleQuotedLiteralValue {
    param(
        [Parameter(Mandatory)]
        [string]$Value
    )

    return $Value.Replace("'", "''")
}

# 函数：根据模板生成最终写入用户目录的 PowerShell profile 内容。
function Get-GeneratedPowerShellProfileContent {
    param(
        [Parameter(Mandatory)]
        [string]$TemplatePath,

        [Parameter(Mandatory)]
        [string]$SharedProfileInstallPath
    )

    if (-not (Test-Path -LiteralPath $TemplatePath)) {
        throw "未找到 PowerShell profile 模板：$TemplatePath"
    }

    $templateContent = Get-Content -LiteralPath $TemplatePath -Raw -Encoding UTF8
    $escapedSharedProfilePath = Convert-ToPowerShellSingleQuotedLiteralValue -Value $SharedProfileInstallPath
    return $templateContent.Replace("__TERMINAL_CONFIG_SHARED_PROFILE_PATH__", $escapedSharedProfilePath)
}

# 函数：根据默认主题选择生成最终的 Starship 配置文本。
function Get-ResolvedStarshipContent {
    param(
        [Parameter(Mandatory)]
        [string]$ConfigRoot,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$ThemeSelection
    )

    $starshipPath = Join-Path $ConfigRoot "starship\\starship.toml"
    $starshipContent = Get-Content -LiteralPath $starshipPath -Raw -Encoding UTF8
    return Resolve-TextPlaceholders -Content $starshipContent -Replacements (Get-ThemePlaceholderMap -ThemeSelection $ThemeSelection)
}

# 函数：校验默认主题选择引用的 scheme、theme 与 starship palette 均已在仓库中定义。
function Assert-ThemeSelectionMatchesConfig {
    param(
        [Parameter(Mandatory)]
        [string]$ConfigRoot,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$ThemeSelection
    )

    $schemeItems = Get-JsonItemsFromDirectory -DirectoryPath (Join-Path $ConfigRoot "windows-terminal\\schemes")
    $themeItems = Get-JsonItemsFromDirectory -DirectoryPath (Join-Path $ConfigRoot "windows-terminal\\themes")
    $schemeNames = @($schemeItems | ForEach-Object { $_["name"] })
    $themeNames = @($themeItems | ForEach-Object { $_["name"] })
    $starshipTemplatePath = Join-Path $ConfigRoot "starship\\starship.toml"
    $starshipTemplateContent = Get-Content -LiteralPath $starshipTemplatePath -Raw -Encoding UTF8
    $paletteName = [string]$ThemeSelection["starshipPalette"]
    $paletteSectionPattern = "(?m)^\[palettes\." + [regex]::Escape($paletteName) + "\]$"

    if ($schemeNames -notcontains $ThemeSelection["windowsTerminalColorScheme"]) {
        throw "默认 colorScheme 未在 schemes 中定义：$($ThemeSelection["windowsTerminalColorScheme"])"
    }

    if ($themeNames -notcontains $ThemeSelection["windowsTerminalTheme"]) {
        throw "默认 theme 未在 themes 中定义：$($ThemeSelection["windowsTerminalTheme"])"
    }

    if (-not [regex]::IsMatch($starshipTemplateContent, $paletteSectionPattern)) {
        throw "默认 Starship palette 未在 starship.toml 中定义：$paletteName"
    }
}
