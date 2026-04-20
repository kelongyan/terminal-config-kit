<#
.SYNOPSIS
    修复 Windows PowerShell 控制台中文乱码问题。

.DESCRIPTION
    将当前控制台的代码页切换为 UTF-8 (65001)，并同步设置 Console 输入/输出编码
    与 PowerShell 的 $OutputEncoding，解决中文输出、错误信息显示为乱码的问题。

    支持两种模式：
    - 临时修复：仅修改当前会话的编码（默认行为）
    - 永久修复：将编码配置写入 PowerShell Profile 文件，每次启动自动生效

.PARAMETER Permanent
    开关参数。指定后将编码配置写入 Profile 文件实现永久修复。

.PARAMETER AllProfiles
    开关参数。与 -Permanent 配合使用，同时修改 PowerShell 7 和 Windows PowerShell 5 的 Profile。
    如果未指定，仅修改当前运行版本的 Profile。

.EXAMPLE
    .\Fix-ConsoleEncoding.ps1
    # 仅修复当前会话

.EXAMPLE
    .\Fix-ConsoleEncoding.ps1 -Permanent
    # 永久修复当前 PowerShell 版本的 Profile

.EXAMPLE
    .\Fix-ConsoleEncoding.ps1 -Permanent -AllProfiles
    # 永久修复 PowerShell 7 和 Windows PowerShell 5 的 Profile

.NOTES
    修复内容来源：terminal-config-kit 项目
    https://github.com/kelongyan/terminal-config-kit
#>

[CmdletBinding()]
param(
    [switch]$Permanent,
    [switch]$AllProfiles
)

Set-StrictMode -Version Latest

# 编码配置片段
$encodingBlock = @'

# 修复中文乱码：设置控制台编码为 UTF-8
chcp 65001 > $null
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

'@

function Write-Step {
    param([string]$Message)
    Write-Host "[*] $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[+] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[!] $Message" -ForegroundColor Yellow
}

# 临时修复：设置当前会话编码
function Set-SessionEncoding {
    Write-Step "设置当前会话编码为 UTF-8..."
    chcp 65001 > $null
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    [Console]::InputEncoding = [System.Text.Encoding]::UTF8
    $script:OutputEncoding = [System.Text.Encoding]::UTF8
    Write-Success "当前会话编码已设置为 UTF-8 (代码页 65001)"
}

# 永久修复：将编码配置写入 Profile 文件
function Set-ProfileEncoding {
    param(
        [string]$ProfilePath,
        [string]$ProfileLabel
    )

    $profileDir = Split-Path -Path $ProfilePath -Parent

    # 如果 Profile 文件已存在，检查是否已包含编码配置
    if (Test-Path -LiteralPath $ProfilePath) {
        $content = Get-Content -LiteralPath $ProfilePath -Raw -Encoding UTF8

        if ($content -match 'chcp 65001') {
            Write-Warning "$ProfileLabel 的 Profile 已包含 UTF-8 编码配置，跳过。"
            return
        }

        # 在文件开头插入编码配置
        $newContent = $encodingBlock + $content
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($ProfilePath, $newContent, $utf8NoBom)
        Write-Success "已在 $ProfileLabel 的 Profile 中添加 UTF-8 编码配置。"
    }
    else {
        # Profile 文件不存在，创建新文件
        if (-not (Test-Path -LiteralPath $profileDir)) {
            New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
        }

        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($ProfilePath, $encodingBlock, $utf8NoBom)
        Write-Success "已创建 $ProfileLabel 的 Profile 并写入 UTF-8 编码配置。"
    }
}

# 执行临时修复
Set-SessionEncoding

# 执行永久修复
if ($Permanent) {
    Write-Step "执行永久修复..."

    # 当前版本的 Profile
    $currentProfile = $PROFILE.CurrentUserCurrentHost
    Set-ProfileEncoding -ProfilePath $currentProfile -ProfileLabel "当前 PowerShell"

    # 如果指定 -AllProfiles，同时修复另一个版本
    if ($AllProfiles) {
        $isPwsh7 = $PSVersionTable.PSVersion.Major -ge 6

        if ($isPwsh7) {
            # 当前是 PowerShell 7，额外修复 Windows PowerShell 5
            $ps5Profile = Join-Path $HOME "Documents\WindowsPowerShell\profile.ps1"
            Set-ProfileEncoding -ProfilePath $ps5Profile -ProfileLabel "Windows PowerShell 5"
        }
        else {
            # 当前是 Windows PowerShell 5，额外修复 PowerShell 7
            $ps7Profile = Join-Path $HOME "Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
            Set-ProfileEncoding -ProfilePath $ps7Profile -ProfileLabel "PowerShell 7"
        }
    }

    Write-Host ""
    Write-Success "永久修复完成。请重新打开 PowerShell 会话以生效。"
}

# 验证结果
Write-Host ""
Write-Step "当前编码状态："
Write-Host "  代码页:              $(chcp | ForEach-Object { ($_ -split ':')[-1].Trim() })"
Write-Host "  Console.Output:      $([Console]::OutputEncoding.EncodingName)"
Write-Host "  Console.Input:       $([Console]::InputEncoding.EncodingName)"
Write-Host "  OutputEncoding:      $($OutputEncoding.EncodingName)"
