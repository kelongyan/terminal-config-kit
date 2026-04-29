# 说明：此文件保存 PowerShell 7 与 Windows PowerShell 5 共用的初始化逻辑。
# 关键逻辑：统一维护 UTF-8 编码修复与 Starship 初始化，避免两个 profile 重复拷贝同一段代码。

# 函数：将当前控制台输入输出编码统一切换到 UTF-8。
function Set-TerminalUtf8Encoding {
    chcp 65001 > $null
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    [Console]::InputEncoding = [System.Text.Encoding]::UTF8
    $script:OutputEncoding = [System.Text.Encoding]::UTF8
}

# 函数：仅在 starship 已安装时初始化提示符，避免新机器缺少依赖时启动报错。
function Initialize-StarshipPrompt {
    if (Get-Command starship -ErrorAction SilentlyContinue) {
        Invoke-Expression (& starship init powershell)
    }
}

Set-TerminalUtf8Encoding
Initialize-StarshipPrompt
