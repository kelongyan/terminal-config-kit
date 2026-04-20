# 说明：PowerShell 7 启动时加载 Starship 提示符。
# 关键逻辑：仅在 starship 已安装时初始化，避免新机器缺少 starship 时启动报错。

# 修复中文乱码：设置控制台编码为 UTF-8
chcp 65001 > $null
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (& starship init powershell)
}

