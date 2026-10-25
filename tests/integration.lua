package.path = "./?.lua;./?/init.lua;" .. package.path
local Sdk = require("tests.modkit.sdk")
local GameVersion = require("src.core.GameVersion")
local Player = require("src.core.game3.player")
local Profile = require("src.core.game3.profile")
local Flags = require("src.core.game3.scripting.flags")
local Space = require("src.core.game3.scripting.space")
local Collision = require("src.core.game3.collision")
local MB = require("src.core.game3.mb")
local Runtime = require("src.mods.Runtime")
local Json = require("src.link.Json")
local total = 0
local function check(value, message)
  total = total + 1
  assert(value, message)
end

for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  GameVersion.set(version)
  Runtime.reset()
  Player.reset(1, 1, "down")
  Space.store = Flags.newStore()
  local store = Space.store
  local before = Json.encode(store)
  local terrain = MB.id("NORMAL") or 0
  Collision.behavior = function() return terrain end
  Collision._mapDef = { allowRunning = 0 }
  check(not Player.canDash(), version .. ": no shoes before mod")

  local run = Sdk.loadMod(MOD_PATH, { generation = 3, data = Sdk.gen3Data() })
  check(#run.errors == 0, table.concat(run.errors, "\n"))
  check(run.mod and run.mod.state == "loaded", version .. ": real loader")
  check(not run.loader.optionSchemas.running_freedom, "no settings schema")
  check(Player.canDash(), version .. ": runs indoors without shoes")
  Collision._mapDef.allowRunning = 1
  check(Player.canDash(), version .. ": runs outdoors without shoes")
  local profile = Profile.forSession()
  local rules = profile.field and profile.field.running
  if rules then
    for _, name in ipairs(rules.behaviors) do
      terrain = MB.id(name)
      check(terrain ~= nil and not Player.canDash(), version .. ": preserves " .. name)
    end
    terrain = MB.id("FORTREE_BRIDGE")
    Player.currentElevation = 2
    check(not Player.canDash(), version .. ": even bridge blocked")
    Player.currentElevation = 3
    check(Player.canDash(), version .. ": odd bridge allowed")
  end
  terrain = MB.id("NORMAL") or 0
  Player.underwater = true
  check(not Player.canDash(), version .. ": no new underwater running")
  Player.underwater = false
  Player.biking = true
  check(not Player.canDash(), version .. ": no new cycling behavior")
  Player.biking = false
  Space.store = nil
  check(not Player.canDash(), version .. ": no running without script store")
  Space.store = store
  check(Json.encode(store) == before, version .. ": save unchanged")
  -- Simulate a save/load by restoring a serialized copy of the flag store.
  Space.store = Json.decode(before)
  local reloaded = Json.encode(Space.store)
  check(Player.canDash(), version .. ": running after store reload")
  check(Json.encode(Space.store) == reloaded, version .. ": reload did not grant shoes")

  -- Use the engine's real movement/input paths against a tiny walkable map.
  Collision._grid = nil
  local wall = false
  local game = { overworld = { map = {
    inBounds = function() return true end,
    isWalkable = function() return not wall end,
  } } }
  local function input(runButton)
    return { isDown = function(_, button)
      return button == "down" or (button == "b" and runButton)
    end }
  end
  Player.reset(1, 1, "down")
  Player.update(game, input(false))
  check(Player.moving and Player.stepFrames == 16, version .. ": normal walking")
  Player.reset(1, 1, "down")
  Player.update(game, input(true))
  check(Player.moving and Player.stepFrames == 8, version .. ": native B-run speed")
  Player.reset(1, 1, "down")
  wall = true
  Player.update(game, input(true))
  check(not Player.moving, version .. ": walls still block running")
  wall = false
  Player.reset(1, 1, "down")
  Space.vm = { isRunning = function() return true end }
  Player.update(game, input(true))
  check(not Player.moving, version .. ": script lock still blocks input")
  Space.vm = nil
  Player.reset(1, 1, "down")
  Player.forceStep("down")
  check(Player.stepFrames == 16, version .. ": scripted step retains walking speed")
  Player.reset(1, 1, "down")

  local bridge = Player.canDash
  -- A later mod may retain our bridge. Removing our hook must still work.
  Player.canDash = function(...) return bridge(...) end
  run.loader:_rollback("running_freedom")
  check(not Player.canDash(), version .. ": rollback removes effect")
  Player.canDash = bridge
  run.release()
  local again = Sdk.loadMod(MOD_PATH, { generation = 3, data = Sdk.gen3Data() })
  check(#again.errors == 0 and Player.canDash(), version .. ": reload works")
  check(Player.canDash == bridge, version .. ": reload does not stack patches")
  Runtime.reset()
  check(not Player.canDash(), version .. ": reset restores vanilla behavior")
  local shoeFlag = rules and Flags.forVersion(version).IDS[rules.flag] or Flags.IDS.SYS_B_DASH
  Flags.setFlag(Space.store, nil, shoeFlag, true)
  check(Player.canDash(), version .. ": earned shoes still work without mod")
  Collision._mapDef.allowRunning = 0
  check(Player.canDash() == (rules == nil), version .. ": native indoor rule restored")
  again.release()
  Runtime.reset()
  print("PASS " .. version)
end
GameVersion.set("red")
local unsupported = Sdk.loadMod(MOD_PATH, { generation = 1 })
check(not unsupported.mod or unsupported.mod.state ~= "loaded", "Gen 1 not advertised or loaded")
unsupported.release()
print("PASS " .. total .. " assertions; native loader and player; no windows")
