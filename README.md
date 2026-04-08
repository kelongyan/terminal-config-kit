# Terminal Config Kit

<div align="center">

一个面向 Windows 的终端配置仓库，用来沉淀并迁移你的 `PowerShell`、`Starship`、`Windows Terminal` 与主题风格。

<p>
  <img src="https://img.shields.io/badge/Platform-Windows-0F6CBD?style=for-the-badge" alt="Platform Windows">
  <img src="https://img.shields.io/badge/Shell-PowerShell%207-2C7BE5?style=for-the-badge" alt="Shell PowerShell 7">
  <img src="https://img.shields.io/badge/Prompt-Starship-111827?style=for-the-badge" alt="Prompt Starship">
  <img src="https://img.shields.io/badge/Terminal-Windows%20Terminal-4B5563?style=for-the-badge" alt="Terminal Windows Terminal">
  <img src="https://img.shields.io/badge/Theme-Dracula%20Pro%20Variant-C026D3?style=for-the-badge" alt="Theme Dracula Pro Variant">
</p>

</div>

> ◈ 这不是一份“整机镜像配置”。
>
> 它更像一套可迁移的终端风格源代码：只保留真正应该跨机器复用的部分，把 SSH、WSL、Conda 绝对路径这类机器专属信息剥离出来。

## ▍Overview

这套配置当前覆盖以下内容：

| 模块 | 作用 | 当前策略 |
| --- | --- | --- |
| `PowerShell 7 profile` | Shell 启动入口 | 保留最小初始化逻辑，负责接入 `starship` |
| `Windows PowerShell profile` | 旧版兼容入口 | 提供一致的提示符体验，不强绑本机 Conda 路径 |
| `starship.toml` | 提示符外观 | 双行布局，压缩命令间距，完整路径显示 |
| `Windows Terminal scheme` | 终端色板 | 基于 `Dracula Pro` 调整出的柔和冷白版本 |
| `Windows Terminal profiles` | PowerShell 外观 | 统一字体、透明度、padding、默认行为 |
| `Install-TerminalConfig.ps1` | 迁移脚本 | 备份本机配置，定向合并 Windows Terminal 配置 |

## ▍Style Snapshot

| 项目 | 当前值 |
| --- | --- |
| 终端主题 | `Dracula Pro` 变体 |
| 默认前景色 | 更柔和的冷白色，弱化纯白刺眼感 |
| 提示符引擎 | `starship` |
| 提示符布局 | 首行路径与 Git，次行提示符 |
| 命令间距 | 已关闭额外空行 |
| 推荐字体 | `0xProto` |

## ▍Design Principles

### ◆ Clone style, not machine

迁移的是终端风格与核心行为，不是当前电脑的一次性状态。

### ◆ Merge, don’t overwrite

Windows Terminal 不会被整份覆盖，而是通过脚本做定向合并，尽量保留目标机器已有的 profile 与习惯配置。

### ◆ Keep machine-specific fragments out

默认不把以下内容强塞进仓库：

- 远程 SSH profile
- 自定义 WSL profile
- Conda 的绝对安装路径
- 当前机器临时测试用的 profile 条目

## ▍Repository Layout

```text
terminal-config-kit/
|-- configs/
|   |-- powershell/
|   |   |-- Microsoft.PowerShell_profile.ps1
|   |   `-- powershell.config.json
|   |-- starship/
|   |   `-- starship.toml
|   |-- windows-powershell/
|   |   `-- profile.ps1
|   `-- windows-terminal/
|       |-- actions.json
|       |-- base-settings.json
|       |-- keybindings.json
|       |-- new-tab-menu.json
|       |-- profiles/
|       |   |-- defaults.json
|       |   |-- powershell.json
|       |   `-- windows-powershell.json
|       `-- schemes/
|           `-- dracula-pro.json
|-- scripts/
|   `-- Install-TerminalConfig.ps1
|-- .gitattributes
|-- .gitignore
`-- README.md
```

## ▍Dependencies

在新机器上使用前，建议先准备：

1. `Windows Terminal`
2. `PowerShell 7`
3. `starship`
4. 推荐字体 `0xProto`

如果目标机器尚未安装 `starship`，PowerShell 依然可以启动；因为 `profile` 内做了存在性判断，只是不会显示 `starship` 提示符。

## ▍Quick Start

### ◆ Clone

```powershell
git clone https://github.com/kelongyan/terminal-config-kit.git
cd .\terminal-config-kit
```

### ◆ Install

```powershell
pwsh -ExecutionPolicy Bypass -File .\scripts\Install-TerminalConfig.ps1 -SetPowerShellAsDefault
```

### ◆ Reload

```text
1. 关闭所有 Windows Terminal 窗口
2. 重新打开 Windows Terminal
3. 如未安装 0xProto，请先安装字体后再观察最终效果
```

## ▍What The Installer Does

安装脚本默认会执行以下操作：

1. 备份当前机器已有配置到 `%USERPROFILE%\.terminal-config-backups\<时间戳>\`
2. 复制 PowerShell 与 `starship` 配置文件
3. 合并 Windows Terminal 的：
   `base settings`、`actions`、`keybindings`、`profiles`、`scheme`
4. 可选地将 `PowerShell` 设为默认 profile

## ▍Installer Options

```powershell
pwsh -ExecutionPolicy Bypass -File .\scripts\Install-TerminalConfig.ps1 `
  -SetPowerShellAsDefault `
  -SkipWindowsTerminal `
  -SkipStarship `
  -SkipPowerShell `
  -SkipLegacyWindowsPowerShell
```

| 参数 | 作用 |
| --- | --- |
| `-SetPowerShellAsDefault` | 将 Windows Terminal 默认 profile 设为仓库中的 `PowerShell` |
| `-SkipWindowsTerminal` | 跳过 Windows Terminal 合并 |
| `-SkipStarship` | 跳过 `starship.toml` 安装 |
| `-SkipPowerShell` | 跳过 PowerShell 7 配置安装 |
| `-SkipLegacyWindowsPowerShell` | 跳过 Windows PowerShell 5 兼容配置安装 |

## ▍Customization Map

### ◆ 字体

相关文件：

- `configs/windows-terminal/profiles/defaults.json`
- `configs/windows-terminal/profiles/powershell.json`
- `configs/windows-terminal/profiles/windows-powershell.json`

你以后如果要改字体，只需要改 `font.face` 与 `font.size`。

### ◆ 配色

相关文件：

- `configs/windows-terminal/schemes/dracula-pro.json`
- `configs/starship/starship.toml`

其中：

- Windows Terminal 的默认文字颜色由 `foreground`、`white`、`brightWhite` 控制
- `starship` 的路径、Git 分支、错误提示符颜色由 `starship.toml` 控制

### ◆ 提示符布局

相关文件：

- `configs/starship/starship.toml`

如果想把双行提示符改成单行，只需要调整最上方的 `format`。

## ▍Not Included By Default

以下内容当前不会自动纳入仓库：

- 远程 SSH profile
- 自定义 WSL Server profile
- 本机 Conda 初始化片段

如果后续确认这些内容也需要同步，建议把它们拆成单独的 `profile fragment` 再加入 `configs/windows-terminal/profiles/`。

## ▍Recommended Workflow

建议把这个仓库当作“配置源”来维护，而不是把本机运行状态直接塞进 Git。

推荐流程如下：

1. 先修改仓库内 `configs/` 中的源文件
2. 再执行安装脚本，把配置应用回当前机器
3. 检查视觉效果与行为
4. 执行 `git add` / `git commit` / `git push`

## ▍GitHub Sync

如果你要在另一台电脑上继续同步，只需要：

```powershell
git pull
pwsh -ExecutionPolicy Bypass -File .\scripts\Install-TerminalConfig.ps1 -SetPowerShellAsDefault
```

## ▍Files Worth Opening First

如果你想快速理解这套配置，从这几个文件开始看最省时间：

- [`scripts/Install-TerminalConfig.ps1`](./scripts/Install-TerminalConfig.ps1)
- [`configs/starship/starship.toml`](./configs/starship/starship.toml)
- [`configs/windows-terminal/schemes/dracula-pro.json`](./configs/windows-terminal/schemes/dracula-pro.json)
- [`configs/powershell/Microsoft.PowerShell_profile.ps1`](./configs/powershell/Microsoft.PowerShell_profile.ps1)

## ▍License

当前仓库尚未添加 `LICENSE`。如果你打算公开长期维护，建议后续补上。
