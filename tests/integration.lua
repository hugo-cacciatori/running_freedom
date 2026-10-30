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
  -- B toggles running (0.3.0): held B alone no longer runs; a B press while the field is free switches it.
  local function input(held, pressed)
    return {
      isDown = function(_, button) return button == "down" or (button == "b" and held) end,
      wasPressed = function(_, button) return button == "b" and pressed end,
    }
  end
  local function step(inp)
    Runtime.call("input.step", function() end, game, 1 / 60)
    Player.reset(1, 1, "down")
    Player.update(game, inp)
  end
  step(input(false, false))
  check(Player.moving and Player.stepFrames == 16, version .. ": normal walking")
  step(input(true, false))
  check(Player.moving and Player.stepFrames == 16, version .. ": holding B walks while running is off")
  step(input(true, true))
  check(Player.moving and Player.stepFrames == 8 and run.loader.exports.running_freedom.running(),
        version .. ": a B press switches running on")
  step(input(false, false))
  check(Player.moving and Player.stepFrames == 8, version .. ": running stays on without holding B")
  wall = true
  step(input(false, false))
  check(not Player.moving, version .. ": walls still block running")
  wall = false
  step(input(true, true))
  check(Player.moving and Player.stepFrames == 16, version .. ": another B press switches running off")
  Space.vm = { isRunning = function() return true end }
  step(input(true, true))
  check(not Player.moving, version .. ": script lock still blocks input")
  Space.vm = nil
  step(input(false, false))
  check(Player.stepFrames == 16, version .. ": B during a script does not toggle")
  Space.vm = { isRunning = function() return true end }
  Runtime.call("input.step", function() end, game, 1 / 60)
  Space.vm = nil
  Player.reset(1, 1, "down")
  Player.update(game, input(false, true))
  check(Player.stepFrames == 16, version .. ": the B that ends a script or menu does not toggle")
  -- another mod's run intent (mouse_keyboard_play's click to walk) wins over the toggle while it is set
  Player.modRunIntent = true
  step(input(false, false))
  check(Player.moving and Player.stepFrames == 8, version .. ": a run intent runs while the toggle is off")
  Player.modRunIntent = nil
  step(input(true, true))
  check(Player.stepFrames == 8, version .. ": toggle on")
  Player.modRunIntent = false
  step(input(false, false))
  check(Player.moving and Player.stepFrames == 16, version .. ": a walk intent walks while the toggle is on")
  Player.modRunIntent = nil
  step(input(true, true))
  check(Player.stepFrames == 16, version .. ": toggle off again")
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

-- Gen 1: Red, Blue, Yellow via native src.world.Player + movement.speed hook
local SpriteRenderer = require("src.render.SpriteRenderer")
local origSpriteNew = SpriteRenderer.new
SpriteRenderer.new = function(def, seed)
  return { def = def, seed = seed }
end
local Gen1Player = require("src.world.Player")
local Gen1Game = require("src.core.Game")
local gen1Data = {
  sprites = { SPRITE_RED = { image = "x", frames = 1 } },
  field = { playerSprites = { walk = "SPRITE_RED" } },
  constants = { world = { stepFrames = 16, bikeStepFrames = 8, turnFrames = 4 } },
}
for _, version in ipairs({ "red", "blue", "yellow" }) do
  GameVersion.set(version)
  Runtime.reset()
  local run = Sdk.loadMod(MOD_PATH, { generation = 1 })
  check(#run.errors == 0, table.concat(run.errors, "\n"))
  check(run.mod and run.mod.state == "loaded", version .. ": real loader")
  check(not run.loader.optionSchemas.running_freedom, version .. ": no settings schema")

  local wall = false
  local map = {
    widthCells = 10, heightCells = 10,
    inBounds = function(_, cx, cy) return cx >= 0 and cy >= 0 and cx < 10 and cy < 10 end,
    isWalkableCell = function() return not wall end,
    isWaterCell = function() return false end,
    cellTile = function() return 0 end,
  }
  local bHeld = false
  Gen1Game.save = { onBike = false }
  Gen1Game.input = { isDown = function(_, btn) return btn == "b" and bHeld end }
  local overworld = { scriptMoves = {} }
  Gen1Game.state = { current = function() return overworld end }
  Gen1Game.overworld = overworld

  local p = Gen1Player.new(gen1Data, 2, 2, "down")
  check(p:stepLength("down") == 16, version .. ": 16-frame walk without B")
  check(p:tryMove("down", map, {}) == "moved" and p.stepFramesCur == 16, version .. ": walk step starts at 16 frames")
  for _ = 1, 16 do p:update() end
  check(not p.moving and p.cellY == 3, version .. ": walk step finishes in 16 frames")

  bHeld = true
  check(p:stepLength("down") == 8, version .. ": 8-frame run with B held")
  check(p:tryMove("down", map, {}) == "moved" and p.stepFramesCur == 8, version .. ": B-run step starts at 8 frames")
  for _ = 1, 8 do p:update() end
  check(not p.moving and p.cellY == 4, version .. ": B-run step finishes in 8 frames")

  -- Releasing B and firing world.stepped restores stepFramesCur to 16 for escort scripts.
  bHeld = false
  Runtime.emit("world.stepped", { player = p })
  check(p.stepFramesCur == 16, version .. ": world.stepped restores stepFramesCur when idle")

  -- Preserved constraints while holding B: bike, surf, ledgeHop, spinning, scripted walk, walls.
  bHeld = true
  Gen1Game.save.onBike = true
  check(p:stepLength("down") == 8, version .. ": bike speed not quartered to 4")
  Gen1Game.save.onBike = false
  p.surfing = true
  check(p:stepLength("down") == 16, version .. ": surfing speed unchanged")
  p.surfing = false
  p.ledgeHop = true
  check(p:stepLength("down") == 16, version .. ": ledge hop speed unchanged")
  p.ledgeHop = false
  overworld.scriptMoves = { { entity = p } }
  check(p:stepLength("down") == 16, version .. ": scripted walk speed unchanged")
  overworld.scriptMoves = {}
  wall = true
  check(p:tryMove("down", map, {}) == "blocked" and not p.moving, version .. ": walls still block running")
  wall = false

  run.loader:_rollback("running_freedom")
  check(p:stepLength("down") == 16, version .. ": rollback restores 16-frame walk")
  run.release()
  Runtime.reset()
  print("PASS " .. version)
end
SpriteRenderer.new = origSpriteNew

-- Gen 2: Gold, Silver, Crystal via native src.world.gen2.World:movePlayer + src.world.gen2.Player
local Gen2World = require("src.world.gen2.World")
local Gen2Player = require("src.world.gen2.Player")
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  GameVersion.set(version)
  Runtime.reset()
  local run = Sdk.loadMod(MOD_PATH, { generation = 2 })
  check(#run.errors == 0, table.concat(run.errors, "\n"))
  check(run.mod and run.mod.state == "loaded", version .. ": real loader")
  check(not run.loader.optionSchemas.running_freedom, version .. ": no settings schema")

  local wall = false
  local map = {
    widthCells = 10, heightCells = 10,
    inBounds = function(_, cx, cy) return cx >= 0 and cy >= 0 and cx < 10 and cy < 10 end,
    isWalkable = function() return not wall end,
    cellCollision = function() return wall and 0x07 or 0x00 end,
  }
  local bHeld = false
  local p = Gen2Player.new(2, 2, "down")
  local world = setmetatable({
    player = p,
    map = map,
    entities = { p },
    playerState = 0,
    game = {
      save = {},
      input = { isDown = function(_, btn) return btn == "b" and bHeld end },
    },
    downhill = function() return false end,
    cellCollisionAcross = function(_, m, x, y) return m:cellCollision(x, y) end,
    npcAt = function() return nil end,
    tryLedgeJump = function() return false end,
  }, { __index = Gen2World })

  check(world:movePlayer("down") == "moved" and p.stepFrames == 16, version .. ": 16-frame walk without B")
  for _ = 1, 16 do p:update() end
  check(not p.moving and p.cellY == 3, version .. ": walk step finishes in 16 frames")

  bHeld = true
  check(world:movePlayer("down") == "moved" and p.stepFrames == 8, version .. ": 8-frame B-run with B held")
  for _ = 1, 8 do p:update() end
  check(not p.moving and p.cellY == 4, version .. ": B-run step finishes in 8 frames")

  -- Preserved constraints: bike (state 1), surf (state 4), downhill, scripted step, walls.
  world.playerState = 1 -- PLAYER_BIKE
  check(world:movePlayer("down") == "moved" and p.stepFrames == 8, version .. ": bike speed not quartered to 4")
  for _ = 1, 8 do p:update() end
  world.playerState = 0
  p:scriptStep("down")
  check(p.stepFrames == 16, version .. ": scriptStep retains 16-frame walking speed")
  for _ = 1, 16 do p:update() end
  wall = true
  check(world:movePlayer("down") == "blocked" and not p.moving, version .. ": walls still block running")
  wall = false

  run.loader:_rollback("running_freedom")
  check(world:movePlayer("down") == "moved" and p.stepFrames == 16, version .. ": rollback restores 16-frame walk")
  run.release()
  Runtime.reset()
  print("PASS " .. version)
end

print("PASS " .. total .. " assertions; native loader and player across Gen 1-3; no windows")

