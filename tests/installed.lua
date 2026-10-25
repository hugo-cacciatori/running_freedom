package.path = "./?.lua;./?/init.lua;" .. package.path
-- Supply data compression only; native cache access remains headless.
love = { data = {
  compress = function(_, _, bytes, level) return deflate(bytes, level) end,
  decompress = function(_, _, bytes) return inflate(bytes) end,
} }
local GameVersion = require("src.core.GameVersion")
GameVersion.set(TEST_VERSION)
assert(require("src.core.Version").engine == "0.3.96", "wrong installed engine")
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
if generation ~= 3 then
  assert(mod and mod.state ~= "loaded", "unsupported game loaded mod")
  print("PASS installed " .. TEST_VERSION .. ": mod excluded")
  return
end
assert(mod and mod.state == "loaded", "installed mod did not load")
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
            local input = { isDown = function(_, key) return key == "down" or key == "b" end }
            Player.update(game, input)
            assert(Player.moving and Player.stepFrames == 8, "native input failed")
            for frame = 1, 8 do Player.tick(game) end
            assert(Player.cellX == x and Player.cellY == y + 1 and not Player.moving,
              "running step did not finish in eight frames")
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
