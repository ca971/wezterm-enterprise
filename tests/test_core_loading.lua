-- tests/test_core_loading.lua
-- Smoke tests for core/* modules
-- Run: cd ~/.config/wezterm && lua tests/test_core_loading.lua

package.path = package.path .. ";./?.lua;./?/init.lua"

local passed = 0
local failed = 0

local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    passed = passed + 1
    print(string.format("  ✓ %s", name))
  else
    failed = failed + 1
    print(string.format("  ✗ %s: %s", name, tostring(err)))
  end
end

print("\n═══ Lot 2: core/* Smoke Tests ═══\n")

test("core.colors loads and provides palette", function()
  local Colors = require("core.colors")
  assert(Colors._VERSION, "Missing _VERSION")

  -- Test base colors
  local text = Colors.base("text")
  assert(type(text) == "string", "base() should return string")
  assert(text:match("^#%x+"), "Should be hex color, got: " .. text)

  -- Test accent colors
  local blue = Colors.accent("blue")
  assert(blue:match("^#%x+"), "accent() should return hex")

  -- Test semantic colors
  local err = Colors.semantic("error")
  assert(err:match("^#%x+"), "semantic() should return hex")

  -- Test UI colors
  local bar_bg = Colors.ui("bar_bg")
  assert(bar_bg:match("^#%x+"), "ui() should return hex")

  -- Test ANSI arrays
  local ansi = Colors.ansi()
  assert(#ansi == 8, "Should have 8 ANSI colors, got " .. #ansi)

  local brights = Colors.brights()
  assert(#brights == 8, "Should have 8 bright colors")

  -- Test color manipulation
  local lighter = Colors.lighten("#000000", 50)
  assert(lighter:match("^#%x+"), "lighten() should return hex")

  local darker = Colors.darken("#ffffff", 50)
  assert(darker:match("^#%x+"), "darken() should return hex")

  local alpha = Colors.with_alpha("#ff0000", 0.5)
  assert(alpha:match("^rgba"), "with_alpha() should return rgba()")

  -- Test hex conversion roundtrip
  local r, g, b = Colors.hex_to_rgb("#ff8040")
  assert(r == 255 and g == 128 and b == 64, "hex_to_rgb failed")
  local hex = Colors.rgb_to_hex(255, 128, 64)
  assert(hex == "#ff8040", "rgb_to_hex failed, got: " .. hex)

  -- Test dot-path access
  local val = Colors.get("base.text")
  assert(val:match("^#%x+"), "get() dot path failed")

  -- Test scheme generation
  local scheme = Colors.to_wezterm_scheme()
  assert(scheme.foreground, "Scheme missing foreground")
  assert(scheme.background, "Scheme missing background")
  assert(scheme.ansi, "Scheme missing ansi")
  assert(scheme.tab_bar, "Scheme missing tab_bar")

  -- Test reset
  Colors.reset()
end)

test("core.icons loads and provides glyphs", function()
  local Icons = require("core.icons")
  assert(Icons._VERSION, "Missing _VERSION")

  -- Test OS icons
  local linux = Icons.os("linux")
  assert(type(linux) == "string" and #linux > 0, "os() failed")

  -- Test shell icons
  local zsh = Icons.shell("zsh")
  assert(type(zsh) == "string" and #zsh > 0, "shell() failed")

  -- Test runtime icons
  local node = Icons.runtime("node")
  assert(type(node) == "string" and #node > 0, "runtime() failed")

  -- Test devops icons
  local docker = Icons.devops("docker")
  assert(type(docker) == "string" and #docker > 0, "devops() failed")

  -- Test UI icons
  local folder = Icons.ui("folder")
  assert(type(folder) == "string" and #folder > 0, "ui() failed")

  -- Test separator
  local sep = Icons.separator("left_hard")
  assert(type(sep) == "string", "separator() failed")

  -- Test battery
  local bat = Icons.battery(75, false)
  assert(type(bat) == "string" and #bat > 0, "battery() failed")

  -- Test fallback mode
  Icons.set_nerd_fonts(false)
  local fallback = Icons.os("linux")
  assert(fallback == "LNX", "Fallback should be 'LNX', got: " .. fallback)
  Icons.set_nerd_fonts(true) -- Restore

  -- Test categories
  local cats = Icons.list_categories()
  assert(#cats >= 8, "Should have 8+ categories, got " .. #cats)

  -- Test custom registration
  Icons.register("custom", {
    test = { nerd = "T", fallback = "t" },
  })
  assert(Icons.get("custom", "test") == "T", "Custom icon registration failed")
end)

test("core.settings loads with defaults", function()
  local Settings = require("core.settings")
  assert(Settings._VERSION, "Missing _VERSION")

  -- Test get with defaults
  local font_size = Settings.get("font.size")
  assert(type(font_size) == "number", "font.size should be number")
  assert(font_size >= 6 and font_size <= 72, "font.size out of range")

  local theme = Settings.get("theme.name")
  assert(type(theme) == "string" and #theme > 0, "theme.name missing")

  local opacity = Settings.get("window.opacity")
  assert(type(opacity) == "number", "window.opacity should be number")

  -- Test nested access
  local leader = Settings.get("keys.leader")
  assert(type(leader) == "table", "keys.leader should be table")
  assert(leader.key, "leader missing key field")

  -- Test set
  Settings.set("test.custom_value", 42)
  assert(Settings.get("test.custom_value") == 42, "set/get failed")

  -- Test missing key with default
  local missing = Settings.get("nonexistent.path", "fallback")
  assert(missing == "fallback", "Default fallback failed")

  -- Test validation
  local result = Settings.validate()
  assert(type(result) == "table", "validate() should return table")
  assert(type(result.valid) == "boolean", "validate().valid should be boolean")
  assert(
    result.valid,
    "Default settings should validate: " .. table.concat(result.errors or {}, "; ")
  )

  -- Test get_all
  local all = Settings.get_all()
  assert(type(all) == "table", "get_all() should return table")
  assert(all.font, "get_all() missing font section")

  Settings.reset()
end)

test("core.fonts loads", function()
  local Fonts = require("core.fonts")
  assert(Fonts._VERSION, "Missing _VERSION")

  -- Test presets
  local presets = Fonts.list_presets()
  assert(#presets >= 5, "Should have 5+ presets, got " .. #presets)

  -- Test preset lookup
  local jb = Fonts.get_preset("JetBrains Mono")
  assert(jb, "JetBrains Mono preset missing")
  assert(jb.harfbuzz_features, "Preset missing harfbuzz_features")

  -- Can't fully test build() without wezterm module
  -- but we can verify the module structure
  assert(type(Fonts.build) == "function", "Missing build()")
end)

test("core.keybindings loads", function()
  local Keybindings = require("core.keybindings")
  assert(Keybindings._VERSION, "Missing _VERSION")
  assert(type(Keybindings.build) == "function", "Missing build()")
end)

test("core.launch loads", function()
  local Launch = require("core.launch")
  assert(Launch._VERSION, "Missing _VERSION")
  assert(type(Launch.build) == "function", "Missing build()")
end)

test("core.appearance loads", function()
  local Appearance = require("core.appearance")
  assert(Appearance._VERSION, "Missing _VERSION")
  assert(type(Appearance.build) == "function", "Missing build()")
end)

test("core.tabs loads", function()
  local Tabs = require("core.tabs")
  assert(Tabs._VERSION, "Missing _VERSION")

  -- Test process icon mapping
  local icon = Tabs.get_process_icon("zsh")
  assert(type(icon) == "string" and #icon > 0, "get_process_icon failed")

  local nvim_icon = Tabs.get_process_icon("nvim")
  assert(type(nvim_icon) == "string" and #nvim_icon > 0, "nvim icon failed")

  -- Test with path
  local path_icon = Tabs.get_process_icon("/usr/bin/zsh")
  assert(type(path_icon) == "string" and #path_icon > 0, "path icon failed")

  assert(type(Tabs.build) == "function", "Missing build()")
end)

test("core.multiplexer loads", function()
  local Multiplexer = require("core.multiplexer")
  assert(Multiplexer._VERSION, "Missing _VERSION")
  assert(type(Multiplexer.build) == "function", "Missing build()")

  -- Test with empty settings (no domains configured)
  local config = Multiplexer.build({})
  assert(type(config.ssh_domains) == "table", "Missing ssh_domains")
  assert(type(config.unix_domains) == "table", "Missing unix_domains")
  assert(type(config.tls_domains) == "table", "Missing tls_domains")
end)

test("core (init) loads", function()
  local Core = require("core")
  assert(Core._VERSION, "Missing _VERSION")
  assert(type(Core.build) == "function", "Missing build()")
  -- Full build requires wezterm module, tested in integration
end)

print(string.format("\n═══ Results: %d passed, %d failed ═══\n", passed, failed))

if failed > 0 then
  os.exit(1)
end
