# Terminal Config Kit

这是一套可直接放进 GitHub 的 Windows 终端配置仓库，用于统一管理并迁移以下内容：

- PowerShell 7 `profile`
- Windows PowerShell 5 兼容 `profile`
- `starship` 提示符主题
- Windows Terminal 配色方案
- Windows Terminal 的 PowerShell 默认外观与常用按键配置

这份仓库的目标不是“完整克隆整台机器的终端状态”，而是把真正需要跨机器复用的部分拆出来，避免把当前电脑特有的 SSH、WSL、磁盘路径等信息硬编码进去。

## 当前风格概览

- 终端主题：`Dracula Pro` 变体
- 默认前景色：更柔和的冷白色，弱化纯白刺眼感
- PowerShell 提示符：`starship`
- 提示符布局：双行布局，首行路径与 Git 信息，次行仅显示提示符
- 命令间距：已关闭 `starship` 默认额外空行
- 推荐字体：`0xProto`

## 仓库结构

```text
terminal-config-kit/
├─ configs/
│  ├─ powershell/
│  │  ├─ Microsoft.PowerShell_profile.ps1
│  │  └─ powershell.config.json
│  ├─ starship/
│  │  └─ starship.toml
│  ├─ windows-powershell/
│  │  └─ profile.ps1
│  └─ windows-terminal/
│     ├─ actions.json
│     ├─ base-settings.json
│     ├─ keybindings.json
│     ├─ new-tab-menu.json
│     ├─ profiles/
│     │  ├─ defaults.json
│     │  ├─ powershell.json
│     │  └─ windows-powershell.json
│     └─ schemes/
│        └─ dracula-pro.json
└─ scripts/
   └─ Install-TerminalConfig.ps1
```

## 设计原则

- `starship` 与 PowerShell `profile` 直接复制，确保行为一致。
- Windows Terminal 不直接覆盖整份 `settings.json`，而是用安装脚本做“定向合并”。
- 机器专属配置默认保留，例如：
  - 自定义 SSH profile
  - 自定义 WSL profile
  - 你在别的电脑上新增的 profile
- 仓库内只保留通用且可迁移的终端风格与核心行为。

## 依赖项

迁移到新电脑前，请先准备以下软件：

1. Windows Terminal
2. PowerShell 7
3. `starship`
4. 推荐字体 `0xProto`

如果目标机器缺少 `starship`，PowerShell 依然能启动，只是不会显示 `starship` 提示符，因为 `profile` 内做了存在性检查。

## 快速迁移

在新电脑上执行：

```powershell
git clone <你的仓库地址>
cd .\terminal-config-kit
pwsh -ExecutionPolicy Bypass -File .\scripts\Install-TerminalConfig.ps1 -SetPowerShellAsDefault
```

执行完成后：

1. 关闭所有 Windows Terminal 窗口
2. 重新打开 Windows Terminal
3. 如果字体尚未安装，先安装 `0xProto`，否则会回退到系统默认字体

## 安装脚本会做什么

安装脚本默认会：

1. 备份当前机器已有配置到 `%USERPROFILE%\.terminal-config-backups\<时间戳>\`
2. 复制以下文件：
   - `PowerShell 7 profile`
   - `PowerShell 7 powershell.config.json`
   - `starship.toml`
   - `Windows PowerShell 5 profile`
3. 合并 Windows Terminal 配置：
   - 基础行为设置
   - `Dracula Pro` 配色方案
   - PowerShell profile 外观
   - Windows PowerShell profile 外观
   - 常用 actions / keybindings

## 安装脚本可选参数

```powershell
pwsh -ExecutionPolicy Bypass -File .\scripts\Install-TerminalConfig.ps1 `
  -SetPowerShellAsDefault `
  -SkipWindowsTerminal `
  -SkipStarship `
  -SkipPowerShell `
  -SkipLegacyWindowsPowerShell
```

参数说明：

- `-SetPowerShellAsDefault`
  - 将 Windows Terminal 默认 profile 设为仓库中的 `PowerShell`
- `-SkipWindowsTerminal`
  - 不修改 Windows Terminal
- `-SkipStarship`
  - 不安装 `starship.toml`
- `-SkipPowerShell`
  - 不安装 PowerShell 7 配置
- `-SkipLegacyWindowsPowerShell`
  - 不安装 Windows PowerShell 5 配置

## 迁移后你最可能会改的内容

### 1. 字体

文件：

- `configs/windows-terminal/profiles/defaults.json`
- `configs/windows-terminal/profiles/powershell.json`
- `configs/windows-terminal/profiles/windows-powershell.json`

如果你以后换字体，只需要改这几个文件里的 `font.face` 与 `font.size`。

### 2. 配色

文件：

- `configs/windows-terminal/schemes/dracula-pro.json`
- `configs/starship/starship.toml`

Windows Terminal 的默认文字颜色由 `foreground`、`white`、`brightWhite` 控制；`starship` 的路径、Git 分支、错误提示符颜色则在 `starship.toml` 中单独控制。

### 3. 提示符布局

文件：

- `configs/starship/starship.toml`

如果想把双行提示符改成单行，只需要改最上面的 `format`。

## 当前没有直接纳入仓库的内容

以下内容目前不自动纳入仓库，因为它们偏机器相关：

- 你的远程 SSH profile
- 你的 WSL Server profile
- Conda 的绝对安装路径

如果你以后确认这些也要同步，可以继续把它们单独拆成 fragment 再加进 `configs/windows-terminal/profiles/`。

## 建议的 GitHub 使用方式

初始化本地仓库：

```powershell
git init -b main
git add .
git commit -m "chore: add terminal config kit"
```

关联 GitHub 远程仓库：

```powershell
git remote add origin <你的 GitHub 仓库地址>
git push -u origin main
```

## 更新工作流

以后你每次在本机调整主题后，建议这样维护：

1. 先修改仓库内 `configs/` 中的源文件
2. 再执行安装脚本，把修改应用回当前机器
3. 确认效果
4. `git add` / `git commit` / `git push`

这样 GitHub 中保存的永远都是“配置源”，而不是一次性的终端运行状态。

