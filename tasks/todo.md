# Terminal Config Optimization

## Tasks

- [x] 完成现状分析、优化目标与风险决策 Spec，并取得用户确认
- [x] 新增共享配置，收敛默认主题与 PowerShell 共享逻辑
- [x] 收缩 Windows Terminal `defaults` 与具体 profile 的职责边界
- [x] 重构 `scripts/Install-TerminalConfig.ps1`，保持现有安装命令兼容
- [x] 新增 `scripts/Test-TerminalConfig.ps1` 校验入口
- [x] 执行脚本验证并记录可核验证据
- [x] 提交变更并推送到 GitHub

## Review

- 已新增 `configs/shared/theme-selection.json` 作为默认 theme、color scheme 与 Starship palette 的唯一真相源。
- 已将 PowerShell 共用逻辑抽到 `configs/shared/powershell/common-profile.ps1`，两个 profile 改为模板 bootstrap，由安装脚本解析共享路径后生成。
- 已新增 `configs/windows-terminal/profiles/shared-powershell.json`，把 PowerShell 专属但跨 profile 共享的字段从具体 profile 中收口。
- 已新增 `scripts/lib/TerminalConfig.Common.ps1`，统一 JSON 读写、占位符解析、数组 upsert、主题校验与 profile 生成逻辑。
- 验证证据：`pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-TerminalConfig.ps1` 通过。
- 验证证据：`pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\Install-TerminalConfig.ps1 -SkipPowerShell -SkipStarship -SkipLegacyWindowsPowerShell -BackupRoot .\tasks\tmp\backups -WindowsTerminalSettingsPath .\tasks\tmp\settings.json -SetPowerShellAsDefault` 通过。
- 验证证据：临时 `settings.json` 校验结果显示 `theme = Catppuccin Mocha`、`defaultColorScheme = Catppuccin Mocha`、`themes` 类型为 `System.Object[]`、默认 profile 为 `PowerShell`。
- 执行中修复了两个真实问题：空数组初次合并失败，以及单元素数组被 PowerShell 自动展开后写成对象。
- 已提交并推送到 `origin/feat/catppuccin-mocha-theme`，最新提交包含 `b2819fe`。
