-- tests/test_lib_loading.lua
-- Quick smoke test: run with `lua tests/test_lib_loading.lua` from config root

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

print("\n═══ Lot 1: lib/* Smoke Tests ═══\n")

test("lib.class loads", function()
  local Class = require("lib.class")
  assert(Class._VERSION, "Missing _VERSION")
  assert(type(Class.new) == "function", "Missing Class.new()")

  local Animal = Class.new("TestAnimal")
  function Animal:init(name)
    self.name = name
  end
  function Animal:speak()
    return "..."
  end

  local Dog = Class.new("TestDog", Animal)
  function Dog:speak()
    return "Woof!"
  end

  local d = Dog("Rex")
  assert(d.name == "Rex", "Inheritance failed")
  assert(d:speak() == "Woof!", "Override failed")
  assert(Dog.is_instance(d, Animal), "is_instance failed")
  Class.reset()
end)

test("lib.table_utils loads", function()
  local T = require("lib.table_utils")
  local merged = T.deep_merge({ a = 1 }, { b = 2 })
  assert(merged.a == 1 and merged.b == 2, "deep_merge failed")
  assert(T.get({ a = { b = 3 } }, "a.b") == 3, "get() failed")
  assert(T.contains({ 1, 2, 3 }, 2), "contains() failed")
end)

test("lib.string_utils loads", function()
  local S = require("lib.string_utils")
  assert(S.trim("  hello  ") == "hello", "trim failed")
  assert(S.starts_with("hello", "hel"), "starts_with failed")
  -- Default ellipsis is now "..." (3 ASCII chars)
  -- "hello world" (11 chars) truncated to max 8: "hello..." (5+3=8)
  assert(
    S.truncate("hello world", 8) == "hello...",
    "truncate failed: got '" .. S.truncate("hello world", 8) .. "'"
  )
  -- Test with custom ellipsis
  assert(S.truncate("hello world", 8, "~") == "hello w~", "truncate with custom ellipsis failed")
  -- Test no truncation needed
  assert(S.truncate("short", 10) == "short", "truncate no-op failed")
end)

test("lib.guard loads", function()
  local G = require("lib.guard")
  assert(G.is_string("test", "x") == "test", "is_string failed")
  assert(G.coalesce(nil, nil, "val") == "val", "coalesce failed")
  assert(G.default(nil, 42) == 42, "default failed")
end)

test("lib.logger loads", function()
  local Logger = require("lib.logger")
  local log = Logger.create("test", { level = "TRACE", use_colors = false })
  assert(log:get_level() == "TRACE", "Level failed")
  log:info("Test message", { key = "value" })
  assert(#log:get_buffer() >= 1, "Buffer empty")
end)

test("lib.path loads", function()
  local Path = require("lib.path")
  assert(type(Path.join) == "function", "Missing join()")
  assert(type(Path.get_home()) == "string", "get_home() failed")
  local joined = Path.join("a", "b", "c")
  assert(#joined > 0, "join() returned empty")
end)

test("lib.platform loads", function()
  local Platform = require("lib.platform")
  local info = Platform.detect()
  assert(info.os, "Missing os field")
  assert(info.arch, "Missing arch field")
  assert(type(info.hostname) == "string", "Missing hostname")
  Platform.reset()
end)

test("lib.shell loads", function()
  local Shell = require("lib.shell")
  local detector = Shell.get_detector()
  detector:detect()
  local shells = detector:list()
  assert(type(shells) == "table", "list() failed")
  Shell.reset()
end)

test("lib.cache loads", function()
  local Cache = require("lib.cache")
  local c = Cache.get("test")
  c:set("key", "value", 60)
  assert(c:get("key") == "value", "get/set failed")
  assert(c:has("key"), "has() failed")
  c:remove("key")
  assert(not c:has("key"), "remove() failed")
  Cache.reset()
end)

test("lib.process loads", function()
  local Process = require("lib.process")
  assert(type(Process.has) == "function", "Missing has()")
  assert(type(Process.version) == "function", "Missing version()")
  Process.reset()
end)

test("lib.secrets loads", function()
  local Secrets = require("lib.secrets")
  local mgr = Secrets.get_manager({ sources = { env = true, localfile = false } })
  assert(mgr, "Manager creation failed")
  mgr:set("test_key", "test_value")
  assert(mgr:get("test_key") == "test_value", "get/set failed")
  assert(mgr:has("test_key"), "has() failed")
  Secrets.reset()
end)

test("lib.validator loads", function()
  local V = require("lib.validator")
  V.register("test_schema", {
    name = { type = "string", required = true },
    age = { type = "number", min = 0, max = 150 },
  })
  local result = V.validate("test_schema", { name = "test", age = 25 })
  assert(result.valid, "Validation should pass")
  local bad = V.validate("test_schema", { age = "not a number" })
  assert(not bad.valid, "Validation should fail")
  V.reset()
end)

test("lib.event_emitter loads", function()
  local EE = require("lib.event_emitter")
  local received = false
  EE.on("test:event", function(data)
    received = data
  end)
  EE.emit("test:event", "hello")
  assert(received == "hello", "Event not received")
  EE.reset()
end)

test("lib (init) lazy loading works", function()
  package.loaded["lib"] = nil
  package.loaded["lib.init"] = nil
  local Lib = require("lib")
  assert(not Lib.is_loaded("guard"), "Should not be preloaded")
  local _ = Lib.guard
  assert(Lib.is_loaded("guard"), "Should be loaded after access")
  local avail = Lib.available()
  assert(#avail >= 13, "Should have 13+ modules, got " .. #avail)
end)

print(string.format("\n═══ Results: %d passed, %d failed ═══\n", passed, failed))

if failed > 0 then
  os.exit(1)
end
