-- tests/test_lot3_loading.lua
-- Smoke tests for bar/*, events/*, highlights/*, themes/*, wezterm.lua
-- Run: cd ~/.config/wezterm && lua tests/test_lot3_loading.lua

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

print("\n═══ Lot 3: bar/*, events/*, highlights/*, themes/* Smoke Tests ═══\n")

-- ── Separators ──
test("bar.separators loads and provides styles", function()
  local Sep = require("bar.separators")
  assert(Sep._VERSION, "Missing _VERSION")
  local styles = Sep.list_styles()
  assert(#styles >= 5, "Should have 5+ styles, got " .. #styles)
  Sep.set_style("powerline")
  assert(Sep.get_style() == "powerline", "Style not set")
  local left = Sep.get("left", "hard")
  assert(type(left) == "string", "get() should return string")
  Sep.set_style("round")
  local round = Sep.get("left", "hard")
  assert(type(round) == "string", "round get() failed")
  Sep.set_style("powerline") -- restore
end)

-- ── Builder ──
test("bar.builder loads and builds segments", function()
  local BarBuilder = require("bar.builder")
  local builder = BarBuilder({ side = "left" })
  assert(builder:count() == 0, "Should start empty")
  builder:add({
    text = "test",
    fg = "#ffffff",
    bg = "#000000",
    icon = "T",
  })
  assert(builder:count() == 1, "Should have 1 segment")
  builder:add({ text = "", visible = false })
  assert(builder:count() == 1, "Empty text should be skipped")
  builder:add({ text = "two", fg = "#ffffff", bg = "#333333" })
  assert(builder:count() == 2, "Should have 2 segments")
  builder:clear()
  assert(builder:count() == 0, "Should be empty after clear")
end)

-- ── Segments registry ──
test("bar.segments registry loads", function()
  local Segments = require("bar.segments")
  assert(Segments._VERSION, "Missing _VERSION")
  local list = Segments.list()
  assert(#list >= 10, "Should have 10+ segments, got " .. #list)
  -- Verify each segment module can be loaded
  for _, name in ipairs(list) do
    local mod = Segments.get(name)
    assert(mod ~= nil, "Failed to load segment: " .. name)
    assert(type(mod.render) == "function", "Segment '" .. name .. "' missing render()")
  end
end)

-- ── Individual segments (without wezterm) ──
test("bar.segments.hostname renders", function()
  local mod = require("bar.segments.hostname")
  local result = mod.render({}, { platform_info = { hostname = "testhost.local" } })
  assert(result, "Should return segment")
  assert(result.text == "testhost", "Should shorten FQDN, got: " .. result.text)
end)

test("bar.segments.username renders", function()
  local mod = require("bar.segments.username")
  local result = mod.render({}, {})
  assert(result, "Should return segment")
  assert(#result.text > 0, "Username should not be empty")
end)

test("bar.segments.environment renders", function()
  local mod = require("bar.segments.environment")
  -- Test with no environment flags (should show "Local")
  local result = mod.render({}, {
    platform_info = {
      is_docker = false,
      is_podman = false,
      is_kubernetes = false,
      is_proxmox = false,
      is_opnsense = false,
      is_remote = false,
      is_vps = false,
      is_wsl = false,
      is_mosh = false,
    },
  })
  assert(result, "Should return segment")
  assert(result.text == "Local", "Should show 'Local', got: " .. result.text)

  -- Test with Docker
  local docker_result = mod.render({}, {
    platform_info = {
      is_docker = true,
      is_podman = false,
      is_kubernetes = false,
      is_proxmox = false,
      is_opnsense = false,
      is_remote = false,
      is_vps = false,
      is_wsl = false,
      is_mosh = false,
    },
  })
  assert(docker_result, "Docker should return segment")
  assert(docker_result.text:find("Docker"), "Should contain 'Docker'")
end)

test("bar.segments.platform renders", function()
  local mod = require("bar.segments.platform")
  local result = mod.render({}, { platform_info = { os = "linux", is_wsl = false } })
  assert(result, "Should return segment")
  assert(result.text == "linux", "Should show OS name")
end)

-- ── Bar orchestrator ──
test("bar (init) loads", function()
  local Bar = require("bar")
  assert(Bar._VERSION, "Missing _VERSION")
  assert(type(Bar.render_left) == "function", "Missing render_left()")
  assert(type(Bar.render_right) == "function", "Missing render_right()")
  assert(type(Bar.setup) == "function", "Missing setup()")
end)

-- ── Highlights ──
test("highlights loads and builds rules", function()
  local Highlights = require("highlights")
  assert(Highlights._VERSION, "Missing _VERSION")
  local config = Highlights.build()
  assert(config.hyperlink_rules, "Missing hyperlink_rules")
  assert(#config.hyperlink_rules >= 4, "Should have 4+ rules, got " .. #config.hyperlink_rules)
  for _, rule in ipairs(config.hyperlink_rules) do
    assert(rule.regex, "Rule missing regex")
    assert(rule.format, "Rule missing format")
  end
end)

test("highlights.urls loads", function()
  local mod = require("highlights.urls")
  local rules = mod.get_rules()
  assert(#rules >= 1, "Should have URL rules")
end)

test("highlights.ips loads", function()
  local mod = require("highlights.ips")
  local rules = mod.get_rules()
  assert(#rules >= 1, "Should have IP rules")
end)

test("highlights.hashes loads", function()
  local mod = require("highlights.hashes")
  local rules = mod.get_rules()
  assert(#rules >= 1, "Should have hash rules")
end)

-- ── Theme Engine ──
test("themes (init) loads and lists themes", function()
  local ThemeEngine = require("themes")
  assert(ThemeEngine._VERSION, "Missing _VERSION")
  local themes = ThemeEngine.list()
  assert(#themes >= 10, "Should have 10 themes, got " .. #themes)
  -- Verify all themes can be loaded
  for _, name in ipairs(themes) do
    local palette = ThemeEngine.load(name)
    assert(palette, "Failed to load theme: " .. name)
    assert(palette.base, "Theme '" .. name .. "' missing base colors")
    assert(palette.accent, "Theme '" .. name .. "' missing accent colors")
    assert(palette.ansi, "Theme '" .. name .. "' missing ansi colors")
    assert(palette.brights, "Theme '" .. name .. "' missing bright colors")
    assert(palette.ui, "Theme '" .. name .. "' missing ui colors")
    assert(palette.semantic, "Theme '" .. name .. "' missing semantic colors")
    assert(#palette.ansi == 8, "Theme '" .. name .. "' should have 8 ANSI colors")
    assert(#palette.brights == 8, "Theme '" .. name .. "' should have 8 bright colors")
  end
end)

test("themes apply/switch works", function()
  local ThemeEngine = require("themes")
  local Colors = require("core.colors")

  -- Apply catppuccin_mocha
  assert(ThemeEngine.apply("catppuccin_mocha"), "Should apply catppuccin_mocha")
  assert(ThemeEngine.get_active() == "catppuccin_mocha", "Active should be catppuccin_mocha")
  local mocha_bg = Colors.base("base")
  assert(mocha_bg == "#1e1e2e", "Mocha base should be #1e1e2e, got: " .. mocha_bg)

  -- Switch to tokyo_night
  assert(ThemeEngine.apply("tokyo_night"), "Should apply tokyo_night")
  assert(ThemeEngine.get_active() == "tokyo_night", "Active should be tokyo_night")
  local tn_bg = Colors.base("base")
  assert(tn_bg == "#1a1b26", "Tokyo Night base should be #1a1b26, got: " .. tn_bg)

  -- Switch to dracula
  assert(ThemeEngine.apply("dracula"), "Should apply dracula")
  local drac_bg = Colors.base("base")
  assert(drac_bg == "#282a36", "Dracula base should be #282a36, got: " .. drac_bg)

  -- Invalid theme
  assert(not ThemeEngine.apply("nonexistent"), "Should fail for unknown theme")

  -- Custom theme registration
  ThemeEngine.register("custom_test", {
    base = {
      base = "#000000",
      text = "#ffffff",
      crust = "#000000",
      mantle = "#111111",
      surface0 = "#222222",
      surface1 = "#333333",
      surface2 = "#444444",
      overlay0 = "#555555",
      overlay1 = "#666666",
      overlay2 = "#777777",
      subtext0 = "#888888",
      subtext1 = "#999999",
    },
    accent = {
      blue = "#0000ff",
      red = "#ff0000",
      green = "#00ff00",
      yellow = "#ffff00",
      pink = "#ff00ff",
      mauve = "#800080",
      peach = "#ff8000",
      teal = "#008080",
      sky = "#87ceeb",
      sapphire = "#0f52ba",
      lavender = "#b57edc",
      rosewater = "#f5e0dc",
      flamingo = "#f2cdcd",
      maroon = "#800000",
    },
    semantic = {
      success = "#00ff00",
      warning = "#ffff00",
      error = "#ff0000",
      info = "#0000ff",
      hint = "#008080",
      debug = "#800080",
      muted = "#555555",
      highlight = "#ff00ff",
      active = "#0000ff",
      inactive = "#222222",
      border = "#222222",
    },
    ui = {
      bar_bg = "#000000",
      bar_fg = "#ffffff",
      bar_active_bg = "#222222",
      bar_active_fg = "#ffffff",
      bar_inactive_bg = "#111111",
      bar_inactive_fg = "#555555",
      tab_bg = "#111111",
      tab_fg = "#ffffff",
      tab_active_bg = "#222222",
      tab_active_fg = "#ffffff",
      tab_hover_bg = "#333333",
      tab_new_bg = "#111111",
      tab_new_fg = "#555555",
      cursor_bg = "#ffffff",
      cursor_fg = "#000000",
      selection_bg = "#333333",
      selection_fg = "#ffffff",
      split = "#222222",
      scrollbar = "#333333",
      visual_bell = "#222222",
    },
    ansi = {
      "#000000",
      "#ff0000",
      "#00ff00",
      "#ffff00",
      "#0000ff",
      "#ff00ff",
      "#00ffff",
      "#ffffff",
    },
    brights = {
      "#555555",
      "#ff0000",
      "#00ff00",
      "#ffff00",
      "#0000ff",
      "#ff00ff",
      "#00ffff",
      "#ffffff",
    },
  })
  assert(ThemeEngine.apply("custom_test"), "Should apply custom theme")

  -- Restore default
  Colors.reset()
end)

-- ── Events ──
test("events (init) loads", function()
  local Events = require("events")
  assert(Events._VERSION, "Missing _VERSION")
  assert(type(Events.register) == "function", "Missing register()")
end)

test("events.toggle_opacity loads", function()
  local mod = require("events.toggle_opacity")
  assert(type(mod.register) == "function", "Missing register()")
end)

test("events.theme_switcher loads", function()
  local mod = require("events.theme_switcher")
  assert(type(mod.register) == "function", "Missing register()")
end)

test("events.augment_command_palette loads", function()
  local mod = require("events.augment_command_palette")
  assert(type(mod.register) == "function", "Missing register()")
end)

test("events.tab_title loads", function()
  local mod = require("events.tab_title")
  assert(type(mod.register) == "function", "Missing register()")
end)

test("events.window_title loads", function()
  local mod = require("events.window_title")
  assert(type(mod.register) == "function", "Missing register()")
end)

test("events.startup loads", function()
  local mod = require("events.startup")
  assert(type(mod.register) == "function", "Missing register()")
end)

print(string.format("\n═══ Results: %d passed, %d failed ═══\n", passed, failed))

if failed > 0 then
  os.exit(1)
end
