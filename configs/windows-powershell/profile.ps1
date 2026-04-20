# 说明：Windows PowerShell 5 的兼容 profile。
# 关键逻辑：默认仅保留与 PowerShell 7 一致的 Starship 初始化，不携带当前机器上的 Conda 绝对路径。

# 修复中文乱码：设置控制台编码为 UTF-8
chcp 65001 > $null
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (& starship init powershell)
}

# 说明：如果你需要在 Windows PowerShell 中继续使用 Conda，
# 请在目标机器上自行执行 `conda init powershell`，再把生成内容补充进这个文件。

