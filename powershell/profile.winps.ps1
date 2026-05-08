# 说明：Windows PowerShell 5 的兼容 profile。
# 关键逻辑：默认仅保留与 PowerShell 7 一致的 Starship 初始化，不携带当前机器上的 Conda 绝对路径。
if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (& starship init powershell)
}

# 说明：如果你需要在 Windows PowerShell 中继续使用 Conda，
# 请在目标机器上自行执行 `conda init powershell`，再把生成内容补充进这个文件。

