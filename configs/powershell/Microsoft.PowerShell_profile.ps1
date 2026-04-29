# 说明：这是 PowerShell 7 profile 的模板文件。
# 关键逻辑：最终安装到用户目录时会解析共享 profile 路径，并统一加载共享初始化逻辑。

$sharedProfilePath = '__TERMINAL_CONFIG_SHARED_PROFILE_PATH__'
if (Test-Path -LiteralPath $sharedProfilePath) {
    . $sharedProfilePath
} else {
    Write-Warning "未找到 terminal-config-kit 共享 profile：$sharedProfilePath"
}

