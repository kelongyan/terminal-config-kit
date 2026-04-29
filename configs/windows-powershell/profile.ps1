# 说明：这是 Windows PowerShell 5 profile 的模板文件。
# 关键逻辑：最终安装到用户目录时会解析共享 profile 路径，并统一加载共享初始化逻辑。

$sharedProfilePath = '__TERMINAL_CONFIG_SHARED_PROFILE_PATH__'
if (Test-Path -LiteralPath $sharedProfilePath) {
    . $sharedProfilePath
} else {
    Write-Warning "未找到 terminal-config-kit 共享 profile：$sharedProfilePath"
}

# 说明：如果你需要在 Windows PowerShell 中继续使用 Conda，
# 请在目标机器上自行执行 `conda init powershell`，再把生成内容补充进这个文件。

