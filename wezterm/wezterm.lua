-- WezTerm 配置文件
-- 文档: https://wezfurlong.org/wezterm/config/files.html

local wezterm = require("wezterm")
local config = wezterm.config_builder()

local palette = {
  text = "#E5DBFC",
  text_muted = "#BEB8D4",
  text_bright = "#F4EEFF",
  background = "#1F2230",
  surface = "#252A38",
  surface_active = "#31384A",
  surface_elevated = "#3A4258",
  border = "#6A7296",
  cursor = "#C09BFC",
  pink = "#FF85CF",
  cyan = "#99EAFE",
  red = "#FF6478",
  green = "#63E2A2",
  yellow = "#F4E38D",
}

local padding = {
  left = 12,
  right = 12,
  top = 12,
  bottom = 12,
}

local tab_title_min_width = 8
local tab_title_padding = " "

local function tab_title(tab_info)
  local title = tab_info.tab_title
  if title and #title > 0 then
    return title
  end

  return tab_info.active_pane.title
end

wezterm.on("format-tab-title", function(tab, tabs, panes, cfg, hover, max_width)
  local title = tab_title(tab)
  local available_width = math.max(max_width - #tab_title_padding, tab_title_min_width)

  if wezterm.column_width(title) > available_width then
    title = wezterm.truncate_left(title, available_width)
  end

  return tab_title_padding .. title
end)

config.colors = {
  foreground = palette.text,
  background = palette.background,
  cursor_bg = palette.cursor,
  cursor_fg = palette.background,
  cursor_border = palette.cursor,
  selection_bg = palette.surface_elevated,
  selection_fg = palette.text_bright,
  scrollbar_thumb = palette.surface_elevated,
  split = palette.border,
  compose_cursor = palette.pink,
  ansi = {
    "#21222C",
    palette.red,
    palette.green,
    palette.yellow,
    palette.cursor,
    palette.pink,
    palette.cyan,
    "#E6E6E1",
  },
  brights = {
    "#4D5566",
    "#FF6E6E",
    "#69FF94",
    "#FFFFA5",
    "#D6ACFF",
    "#FF92DF",
    "#A4FFFF",
    "#FFFFFF",
  },
  tab_bar = {
    background = palette.surface,
    active_tab = {
      bg_color = palette.surface_elevated,
      fg_color = palette.cursor,
      intensity = "Bold",
    },
    inactive_tab = {
      bg_color = palette.surface,
      fg_color = palette.text_muted,
    },
    inactive_tab_hover = {
      bg_color = palette.surface_active,
      fg_color = palette.text_bright,
    },
    new_tab = {
      bg_color = palette.surface,
      fg_color = palette.cyan,
    },
    new_tab_hover = {
      bg_color = palette.surface_active,
      fg_color = palette.pink,
    },
  },
}

config.font = wezterm.font_with_fallback({
  { family = "JetBrains Mono", weight = "Medium" },
  { family = "Noto Sans Mono CJK SC" },
})
config.font_size = 12.0
config.window_padding = padding
config.window_background_opacity = 1.0
config.win32_system_backdrop = "Mica"
config.window_close_confirmation = "NeverPrompt"

config.window_decorations = "INTEGRATED_BUTTONS|RESIZE"
config.window_frame = {
  font = wezterm.font({ family = "Segoe UI", weight = "Bold" }),
  font_size = 10.0,
  active_titlebar_bg = palette.surface,
  inactive_titlebar_bg = palette.background,
}

config.use_fancy_tab_bar = true
config.tab_bar_at_bottom = false
config.hide_tab_bar_if_only_one_tab = false
config.show_new_tab_button_in_tab_bar = true
config.enable_tab_bar = true
config.tab_max_width = 32

config.mouse_bindings = {
  {
    event = { Up = { streak = 1, button = "Right" } },
    mods = "NONE",
    action = wezterm.action.PasteFrom("Clipboard"),
  },
}

config.default_cursor_style = "BlinkingBar"
config.cursor_blink_rate = 530
config.default_prog = { "pwsh.exe", "-NoLogo" }
config.initial_cols = 120
config.initial_rows = 35

return config
