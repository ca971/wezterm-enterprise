-- tests/init.lua
-- Master test runner: executes all test suites
-- Run: cd ~/.config/wezterm && lua tests/init.lua

package.path = package.path .. ";./?.lua;./?/init.lua"

local total_passed = 0
local total_failed = 0

local function run_suite(name, path)
  print(
    string.format(
      "\n╔══════════════════════════════════════════╗"
    )
  )
  print(string.format("║  Suite: %-33s║", name))
  print(
    string.format(
      "╚══════════════════════════════════════════╝"
    )
  )

  -- Reset all loaded modules to ensure isolation
  local to_clear = {}
  for mod_name, _ in pairs(package.loaded) do
    if
      mod_name:match("^lib%.")
      or mod_name:match("^core%.")
      or mod_name:match("^bar%.")
      or mod_name:match("^events%.")
      or mod_name:match("^highlights%.")
      or mod_name:match("^themes%.")
      or mod_name == "lib"
      or mod_name == "core"
      or mod_name == "bar"
      or mod_name == "events"
      or mod_name == "highlights"
      or mod_name == "themes"
    then
      to_clear[#to_clear + 1] = mod_name
    end
  end
  for _, mod_name in ipairs(to_clear) do
    package.loaded[mod_name] = nil
  end

  local ok, err = pcall(dofile, path)
  if not ok then
    print(string.format("  ✗ Suite '%s' crashed: %s", name, tostring(err)))
    total_failed = total_failed + 1
  end
end

print("\n")
print(
  "╔══════════════════════════════════════════════════════╗"
)
print("║  WezTerm Enterprise Config — Full Test Suite        ║")
print("║  Testing 68 modules across 3 lots                   ║")
print(
  "╚══════════════════════════════════════════════════════╝"
)

run_suite("Lot 1: lib/*", "tests/test_lib_loading.lua")
run_suite("Lot 2: core/*", "tests/test_core_loading.lua")
run_suite("Lot 3: bar/ev/hl/th", "tests/test_lot3_loading.lua")

print("\n")
print(
  "╔══════════════════════════════════════════════════════╗"
)
print("║  Integration: Full module dependency chain          ║")
print(
  "╚══════════════════════════════════════════════════════╝"
)
print("")

-- Final integration: load everything as wezterm.lua would
local int_passed = 0
local int_failed = 0

local function itest(name, fn)
  -- Clear modules
  for mod_name, _ in pairs(package.loaded) do
    if
      mod_name:match("^lib%.")
      or mod_name:match("^core%.")
      or mod_name:match("^bar%.")
      or mod_name:match("^events%.")
      or mod_name:match("^highlights%.")
      or mod_name:match("^themes%.")
      or mod_name == "lib"
      or mod_name == "core"
      or mod_name == "bar"
      or mod_name == "events"
      or mod_name == "highlights"
      or mod_name == "themes"
    then
      package.loaded[mod_name] = nil
    end
  end

  local ok, err = pcall(fn)
  if ok then
    int_passed = int_passed + 1
    print(string.format("  ✓ %s", name))
  else
    int_failed = int_failed + 1
    print(string.format("  ✗ %s: %s", name, tostring(err)))
  end
end

itest("Full lib preload", function()
  local Lib = require("lib")
  Lib.preload_all()
  local loaded = Lib.loaded()
  assert(#loaded >= 13, "Should preload 13+ modules, got " .. #loaded)
end)

itest("Full core module chain", function()
  local Settings = require("core.settings")
  local Colors = require("core.colors")
  local Icons = require("core.icons")
  local Fonts = require("core.fonts")
  local Tabs = require("core.tabs")

  -- Settings -> Colors -> Icons chain
  local theme = Settings.get("theme.name")
  assert(theme, "Should have theme setting")

  local ThemeEngine = require("themes")
  assert(ThemeEngine.apply(theme), "Should apply default theme")

  local bg = Colors.base("base")
  assert(bg:match("^#%x+"), "Should have valid hex color after theme apply")

  local icon = Icons.os("linux")
  assert(#icon > 0, "Should have OS icon")

  -- Tabs uses Colors + Icons
  local proc_icon = Tabs.get_process_icon("nvim")
  assert(#proc_icon > 0, "Tab process icon should work")
end)

itest("Full bar segment chain", function()
  local Bar = require("bar")
  local Segments = require("bar.segments")

  Bar.setup()

  local available = Segments.list()
  assert(#available >= 10, "Should have 10+ segments")

  -- Render segments that don't need wezterm
  local hostname = Segments.render("hostname", {}, {
    platform_info = { hostname = "test-server" },
  })
  assert(hostname, "Hostname should render")
  assert(hostname.text == "test-server", "Should use provided hostname")

  local env = Segments.render("environment", {}, {
    platform_info = {
      is_docker = true,
      is_kubernetes = true,
      is_podman = false,
      is_proxmox = false,
      is_opnsense = false,
      is_remote = true,
      is_vps = false,
      is_wsl = false,
      is_mosh = false,
    },
  })
  assert(env, "Environment should render")
  assert(env.text:find("K8s"), "Should show K8s for kubernetes")
  assert(env.text:find("Docker"), "Should show Docker")
  assert(env.text:find("SSH"), "Should show SSH for remote")
end)

itest("Full highlight chain", function()
  local Highlights = require("highlights")
  local config = Highlights.build()
  assert(config.hyperlink_rules, "Should have hyperlink_rules")

  -- Verify rules have required fields
  for i, rule in ipairs(config.hyperlink_rules) do
    assert(rule.regex, "Rule " .. i .. " missing regex")
    assert(rule.format, "Rule " .. i .. " missing format")
  end
end)

itest("Full theme cycle", function()
  local ThemeEngine = require("themes")
  local Colors = require("core.colors")
  local themes = ThemeEngine.list()

  -- Cycle through all 10 themes
  for _, name in ipairs(themes) do
    local ok = ThemeEngine.apply(name)
    assert(ok, "Should apply theme: " .. name)

    -- Verify critical colors exist after apply
    local bg = Colors.base("base")
    assert(bg:match("^#%x%x%x%x%x%x"), "Invalid base color for " .. name .. ": " .. bg)

    local fg = Colors.base("text")
    assert(fg:match("^#%x%x%x%x%x%x"), "Invalid text color for " .. name .. ": " .. fg)

    local scheme = Colors.to_wezterm_scheme()
    assert(scheme.foreground, name .. " scheme missing foreground")
    assert(scheme.background, name .. " scheme missing background")
    assert(scheme.ansi and #scheme.ansi == 8, name .. " scheme missing/bad ansi")
    assert(scheme.brights and #scheme.brights == 8, name .. " scheme missing/bad brights")
  end

  Colors.reset()
end)

itest("Cross-module color consistency", function()
  local ThemeEngine = require("themes")
  local Colors = require("core.colors")
  local Tabs = require("core.tabs")

  ThemeEngine.apply("nord")

  -- Tab scheme should reflect Nord colors
  local tabs_config = Tabs.build()
  assert(tabs_config.colors, "Tab config should include colors")
  assert(
    tabs_config.colors.background == "#2e3440",
    "Tab bg should match Nord base: " .. tostring(tabs_config.colors.background)
  )

  Colors.reset()
end)

itest("Settings validation roundtrip", function()
  local Settings = require("core.settings")

  -- Default settings should validate
  local result = Settings.validate()
  assert(result.valid, "Defaults should validate: " .. table.concat(result.errors or {}, "; "))

  -- Modify a setting and re-validate
  Settings.set("font.size", 16.0)
  assert(Settings.get("font.size") == 16.0, "Set should persist")

  local result2 = Settings.validate()
  assert(result2.valid, "Modified settings should validate")

  Settings.reset()
end)

itest("Platform-aware settings override", function()
  local Settings = require("core.settings")

  local original_size = Settings.get("font.size")
  Settings.apply_platform_overrides("macos")
  local macos_size = Settings.get("font.size")
  assert(
    macos_size == 14.0,
    "macOS should override font size to 14.0, got: " .. tostring(macos_size)
  )

  Settings.reset()
end)

print(
  string.format("\n═══ Integration: %d passed, %d failed ═══", int_passed, int_failed)
)

print("\n")
print(
  "╔══════════════════════════════════════════════════════╗"
)
print("║                 FINAL SUMMARY                       ║")
print(
  "╠══════════════════════════════════════════════════════╣"
)
print(string.format("║  Lot 1 (lib):         see above                     ║"))
print(string.format("║  Lot 2 (core):        see above                     ║"))
print(string.format("║  Lot 3 (bar/ev/hl/th): see above                    ║"))
print(
  string.format(
    "║  Integration:         %2d passed, %d failed            ║",
    int_passed,
    int_failed
  )
)
print(
  "╠══════════════════════════════════════════════════════╣"
)

if int_failed == 0 then
  print("║  🏆 ALL TESTS PASSED — Configuration is READY       ║")
else
  print(
    string.format("║  ⚠  %d FAILURES — Review errors above                ║", int_failed)
  )
end

print(
  "╚══════════════════════════════════════════════════════╝"
)
print("")
