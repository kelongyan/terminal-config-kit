# 说明：PowerShell 7 启动时加载 Starship 提示符。
# 关键逻辑：仅在 starship 已安装时初始化，避免新机器缺少 starship 时启动报错。
if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (& starship init powershell)
}

