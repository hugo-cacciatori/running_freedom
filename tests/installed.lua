package.path = "./?.lua;./?/init.lua;" .. package.path
-- Supply data compression only; native cache access remains headless.
love = { data = {
  compress = function(_, _, bytes, level) return deflate(bytes, level) end,
  decompress = function(_, _, bytes) return inflate(bytes) end,
} }
local GameVersion = require("src.core.GameVersion")
GameVersion.set(TEST_VERSION)
assert(require("src.core.Version").engine == INSTALLED_ENGINE, "staged engine is not the installed one")
local fs, overlay = {}, {}
function fs.read(p) return overlay[p] or fs_read(p) end
function fs.getInfo(p) return overlay[p] and { type = "file" } or fs_info(p) end
function fs.getDirectoryItems(p) return fs_list(p) end
function fs.load(p)
  local bytes = fs.read(p)
  return bytes and loadstring(bytes, "@" .. p)
end
function fs.write(p, bytes) overlay[p] = bytes return true end
function fs.createDirectory() return true end
fs.root = "."
local generation = GameVersion.generation()
local Loader = require("src.mods.Loader")
local game = { data = {} }
if generation == 3 then
  local Dataset = require("src.core.game3.dataset")
  Dataset.cacheRootOverride = CACHE_ROOT
  assert(Dataset.hydrate(game), "installed dataset did not hydrate")
end
local loader = Loader.new({ fs = fs, generation = generation })
loader:load(game.data)
assert(#loader.errors == 0, table.concat(loader.errors, "\n"))
local mod = loader.mods.running_freedom
assert(mod and mod.state == "loaded", "installed mod did not load for " .. TEST_VERSION)

if generation == 1 then
  local SpriteRenderer = require("src.render.SpriteRenderer")
  SpriteRenderer.new = function(def, seed) return { def = def, seed = seed } end
  local Map = require("src.world.Map")
  local Player = require("src.world.Player")
  local Game = require("src.core.Game")
  local Runtime = require("src.mods.Runtime")
  local maps = assert(fs.load(TEST_VERSION .. "/data/generated/maps.lua"))()
  local tilesets = assert(fs.load(TEST_VERSION .. "/data/generated/tilesets.lua"))()
  local gen1Data = {
    sprites = { SPRITE_RED = { image = "x", frames = 1 } },
    field = { playerSprites = { walk = "SPRITE_RED" } },
    constants = { world = { stepFrames = 16, bikeStepFrames = 8, turnFrames = 4 } },
  }
  local bHeld = false
  Game.save = { onBike = false }
  Game.input = { isDown = function(_, key) return key == "b" and bHeld end }
  Game.overworld = { scriptMoves = {} }
  Game.state = { current = function() return Game.overworld end }

  for _, pair in ipairs({
    { kind = "indoor", id = "OAKS_LAB" },
    { kind = "outdoor", id = "PALLET_TOWN" },
  }) do
    local def = assert(maps[pair.id], "missing map " .. pair.id)
    local ts = assert(tilesets[def.tileset], "missing tileset " .. tostring(def.tileset))
    local map = Map.new(def, ts)
    local found = false
    for y = 1, map.heightCells - 3 do
      for x = 1, map.widthCells - 3 do
        if map:isWalkableCell(x, y) and map:isWalkableCell(x, y + 1) then
          local p = Player.new(gen1Data, x, y, "down")
          bHeld = false
          assert(p:tryMove("down", map, {}) == "moved" and p.stepFramesCur == 16,
            "Gen 1 walk did not use 16 frames")
          p = Player.new(gen1Data, x, y, "down")
          bHeld = true
          assert(p:tryMove("down", map, {}) == "moved" and p.stepFramesCur == 8,
            "Gen 1 B-run did not use 8 frames")
          for _ = 1, 8 do p:update() end
          assert(p.cellX == x and p.cellY == y + 1 and not p.moving,
            "Gen 1 running step did not finish in 8 frames")
          bHeld = false
          Runtime.emit("world.stepped", { player = p })
          assert(p.stepFramesCur == 16, "Gen 1 stepFramesCur did not restore after B-run")
          print("PASS installed " .. TEST_VERSION .. ": " .. pair.kind .. " " .. pair.id .. " at " .. x .. "," .. y)
          found = true
          break
        end
      end
      if found then break end
    end
    assert(found, "no walkable pair found on " .. pair.id)
  end
  bHeld = true
  loader:_rollback("running_freedom")
  local p = Player.new(gen1Data, 1, 1, "down")
  assert(p:stepLength("down") == 16, "Gen 1 B-run remained active after rollback")
  print("PASS installed " .. TEST_VERSION .. ": rollback and escort step sync")
  return
end

if generation == 2 then
  local Map = require("src.world.gen2.Map")
  local Player = require("src.world.gen2.Player")
  local World = require("src.world.gen2.World")
  local maps = assert(fs.load(TEST_VERSION .. "/data/generated/maps.lua"))()
  local tilesets = assert(fs.load(TEST_VERSION .. "/data/generated/tilesets.lua"))()
  local bHeld = false

  for _, pair in ipairs({
    { kind = "indoor", id = "PLAYERS_HOUSE_2F" },
    { kind = "outdoor", id = "NEW_BARK_TOWN" },
  }) do
    local def = assert(maps[pair.id], "missing map " .. pair.id)
    local ts = assert(tilesets[def.tileset], "missing tileset " .. tostring(def.tileset))
    local map = Map.new(def, ts)
    local found = false
    for y = 1, map.heightCells - 3 do
      for x = 1, map.widthCells - 3 do
        if map:isWalkable(x, y) and map:isWalkable(x, y + 1) then
          local p = Player.new(x, y, "down")
          local world = setmetatable({
            player = p, map = map, entities = { p }, playerState = 0,
            game = { save = {}, input = { isDown = function(_, k) return k == "b" and bHeld end } },
            downhill = function() return false end,
            cellCollisionAcross = function(_, m, cx, cy) return m:cellCollision(cx, cy) end,
            npcAt = function() return nil end,
            tryLedgeJump = function() return false end,
          }, { __index = World })
          bHeld = false
          assert(world:movePlayer("down") == "moved" and p.stepFrames == 16,
            "Gen 2 walk did not use 16 frames")
          p.cellX, p.cellY, p.moving, p.progress = x, y, false, 0
          bHeld = true
          assert(world:movePlayer("down") == "moved" and p.stepFrames == 8,
            "Gen 2 B-run did not use 8 frames")
          for _ = 1, 8 do p:update() end
          assert(p.cellX == x and p.cellY == y + 1 and not p.moving,
            "Gen 2 running step did not finish in 8 frames")
          print("PASS installed " .. TEST_VERSION .. ": " .. pair.kind .. " " .. pair.id .. " at " .. x .. "," .. y)
          found = true
          break
        end
      end
      if found then break end
    end
    assert(found, "no walkable pair found on " .. pair.id)
  end
  bHeld = true
  loader:_rollback("running_freedom")
  local def = maps.NEW_BARK_TOWN
  local map = Map.new(def, tilesets[def.tileset])
  local p = Player.new(1, 1, "down")
  local world = setmetatable({
    player = p, map = map, entities = { p }, playerState = 0,
    game = { save = {}, input = { isDown = function(_, k) return k == "b" end } },
    downhill = function() return false end,
    cellCollisionAcross = function() return 0x00 end,
    npcAt = function() return nil end,
    tryLedgeJump = function() return false end,
  }, { __index = World })
  world:movePlayer("down")
  assert(p.stepFrames == 16, "Gen 2 B-run remained active after rollback")
  print("PASS installed " .. TEST_VERSION .. ": rollback")
  return
end

local Player = require("src.core.game3.player")
local Collision = require("src.core.game3.collision")
local Space = require("src.core.game3.scripting.space")
local Flags = require("src.core.game3.scripting.flags")
local Objects = require("src.core.game3.objects")
local Json = require("src.link.Json")
local ids = {}
for id in pairs(game.data.maps) do ids[#ids + 1] = id end
table.sort(ids)
local tested = { indoor = false, outdoor = false }
local count = 0
for _, id in ipairs(ids) do
  local def = game.data.maps[id]
  local mapType = tonumber(def.mapType)
  local kind = (mapType == 4 or mapType == 8) and "indoor"
    or ((mapType == 1 or mapType == 2 or mapType == 3 or mapType == 6) and "outdoor")
  if kind and not tested[kind] and def.midLayout and
      (TEST_VERSION == "firered" or kind ~= "indoor" or tonumber(def.allowRunning) == 0) then
    Collision.bindMap(game, id, def)
    -- No save/session is read; use an empty in-memory progression store.
    Space.store = Flags.newStore()
    Space.vm, Space._pendingOnFrame = nil, nil
    Objects.loadMap(game, id, def)
    local before = Json.encode(Space.store)
    local found = false
    for y = 2, def.midLayout.height - 3 do
      for x = 2, def.midLayout.width - 3 do
        Player.reset(x, y, "down")
        if Collision.isWalkable(x, y) and Player.canDash() and
            Collision.canEnter(game, x, y + 1, { fromX = x, fromY = y, dir = "down", elevation = Player.currentElevation }) then
          local result = Player.tryMove("down", game, Player.canDash())
          if Player.moving and Player.stepFrames == 8 then
            Player.reset(x, y, "down")
            -- B toggles running: the press switches it on, the next press back off
            local input = { isDown = function(_, key) return key == "down" or key == "b" end,
                            wasPressed = function(_, key) return key == "b" end }
            require("src.mods.Runtime").call("input.step", function() end, game, 1 / 60)
            Player.update(game, input)
            assert(Player.moving and Player.stepFrames == 8, "native input failed: a B press did not switch running on")
            for frame = 1, 8 do Player.tick(game) end
            assert(Player.cellX == x and Player.cellY == y + 1 and not Player.moving,
              "running step did not finish in eight frames")
            Player.reset(x, y, "down")
            require("src.mods.Runtime").call("input.step", function() end, game, 1 / 60)
            Player.update(game, input)
            assert(Player.moving and Player.stepFrames == 16, "a second B press did not switch running off")
            Player.reset(x, y, "down")
            assert(Json.encode(Space.store) == before, "progression store changed")
            tested[kind], found = true, true
            count = count + 1
            print("PASS installed " .. TEST_VERSION .. ": " .. kind .. " " .. id .. " at " .. x .. "," .. y)
            break
          end
        end
      end
      if found then break end
    end
  end
  if tested.indoor and tested.outdoor then break end
end
assert(count == 2, "did not test both indoor and outdoor real maps")
loader:_rollback("running_freedom")
assert(not Player.canDash(), "running remained without shoes after rollback")
print("PASS installed " .. TEST_VERSION .. ": rollback and unchanged save flags")
