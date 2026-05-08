-- WezTerm 配置文件
-- 文档: https://wezfurlong.org/wezterm/config/files.html

local wezterm = require("wezterm")
local config = wezterm.config_builder()

-- ==================== Dracula 主题配置 ====================

-- 颜色方案: 使用内置 Dracula 主题
config.color_scheme = "Dracula"

-- 背景透明度 (0.0 完全透明 - 1.0 完全不透明)
config.window_background_opacity = 0.92

-- 背景模糊效果 (需要窗口管理器支持)
config.win32_system_backdrop = "Acrylic"

-- ==================== 字体配置 ====================

config.font = wezterm.font_with_fallback({
  { family = "JetBrains Mono", weight = "Medium" },
  { family = "Noto Sans Mono CJK SC" },  -- 中文回退字体
})
config.font_size = 12.0

-- ==================== 窗口外观 ====================

-- 窗口内边距
config.window_padding = {
  left = 12,
  right = 12,
  top = 12,
  bottom = 12,
}

-- 标签栏样式 (顶部显示)
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = false
config.hide_tab_bar_if_only_one_tab = false

-- Dracula 融合风格标签栏颜色
config.colors = {
  tab_bar = {
    -- 标签栏背景 (Dracula Background)
    background = "#282A36",

    -- 活动标签
    active_tab = {
      bg_color = "#44475A",
      fg_color = "#BD93F9",
      intensity = "Bold",
    },

    -- 非活动标签
    inactive_tab = {
      bg_color = "#282A36",
      fg_color = "#F8F8F2",
    },

    -- 非活动标签悬停
    inactive_tab_hover = {
      bg_color = "#44475A",
      fg_color = "#F8F8F2",
    },

    -- 新建标签按钮
    new_tab = {
      bg_color = "#282A36",
      fg_color = "#F8F8F2",
    },

    -- 新建标签按钮悬停
    new_tab_hover = {
      bg_color = "#44475A",
      fg_color = "#F8F8F2",
    },
  },
}

-- 窗口装饰 (标题栏)
config.window_decorations = "INTEGRATED_BUTTONS|RESIZE"

-- ==================== 光标配置 ====================

-- 光标样式: 竖线闪烁
config.default_cursor_style = "BlinkingBar"

-- 闪烁频率 (毫秒, 默认 800)
config.cursor_blink_rate = 530

-- ==================== 其他设置 ====================

-- 默认启动 PowerShell
config.default_prog = { "pwsh.exe", "-NoLogo" }

-- 初始窗口大小
config.initial_cols = 120
config.initial_rows = 35

-- 启用状态栏
config.enable_tab_bar = true

return config
