-- Running Freedom: B-button running indoors and without Running Shoes across
-- Gen 1, Gen 2, and Gen 3.
-- - Gen 3 installs an idempotent Player.canDash bridge backed by an owner-scoped
--   hook so loader rollback/reset cleanly restores vanilla rules.
-- - Gen 1 and Gen 2 wrap the native movement.speed hook to halve walking step
--   frames while B is held on foot, and Gen 1 restores stepFramesCur on
--   world.stepped so NPC escort scripts stay synchronized.
return function(mod)
  local GameVersion = require("src.core.GameVersion")
  local Runtime = require("src.mods.Runtime")
  local generation = tonumber(mod and mod.generation)
    or tonumber(mod and mod.game and mod.game.generation)
    or tonumber(GameVersion.generation())

  if generation == 3 then
    local Player = require("src.core.game3.player")
    local Profile = require("src.core.game3.profile")
    local Collision = require("src.core.game3.collision")
    local Space = require("src.core.game3.scripting.space")
    local MB = require("src.core.game3.mb")
    assert(type(Player.canDash) == "function", "Running Freedom: missing canDash")
    assert(type(Profile.forSession) == "function", "Running Freedom: missing profile")
    assert(type(Collision.behavior) == "function", "Running Freedom: missing terrain")
    assert(type(Space.getStore) == "function", "Running Freedom: missing script store")
    assert(type(MB.id) == "function", "Running Freedom: missing terrain IDs")

    local hook = "running_freedom.can_dash"
    if not Player._runningFreedomBridge then
      local original = Player.canDash
      local function bridge(...)
        return Runtime.call(hook, original, ...)
      end
      Player.canDash = bridge
      Player._runningFreedomBridge = bridge
    end

    mod.hooks:wrap(hook, function(next, ...)
      -- Preserve successful native or earlier-mod decisions.
      if next(...) then return true end
      if not Space.getStore() or Player.underwater or Player.biking then return false end

      local profile = Profile.forSession()
      local rules = profile.field and profile.field.running
      if rules then
        local behavior = Collision.behavior(Player.cellX, Player.cellY)
        for _, name in ipairs(rules.behaviors or {}) do
          if behavior ~= nil and behavior == MB.id(name) then return false end
        end
        for _, name in ipairs(rules.evenElevation or {}) do
          if behavior ~= nil and behavior == MB.id(name)
              and (tonumber(Player.currentElevation) or 0) % 2 == 0 then
            return false
          end
        end
      end
      -- Only the shoe flag and map header are bypassed. No state is written.
      return true
    end)
    return
  end

  assert(generation == 1 or generation == 2,
    "Running Freedom: unsupported generation " .. tostring(generation))

  local Gen1Game = generation == 1 and require("src.core.Game") or nil

  local function isScriptWalkingPlayer(ctx)
    local player = ctx and ctx.player
    if not player then return false end
    local ow = ctx.overworld
      or (mod.world and mod.world.overworld and mod.world:overworld())
      or (Gen1Game and Gen1Game.overworld)
    local moves = ow and ow.scriptMoves
    if type(moves) ~= "table" then return false end
    for i = 1, #moves do
      local mv = moves[i]
      if mv and mv.entity == player then return true end
    end
    return false
  end

  mod.hooks:wrap("movement.speed", function(next, frames, ctx)
    local base = next(frames, ctx)
    if type(base) ~= "number" or base <= 1 or type(ctx) ~= "table" then
      return base
    end
    if ctx.onBike or ctx.surfing or ctx.downhill then
      return base
    end
    local player = ctx.player
    if player and (player.ledgeHop or player.spinning or player.jumping) then
      return base
    end
    if isScriptWalkingPlayer(ctx) then
      return base
    end
    local input = ctx.input
    if not (input and type(input.isDown) == "function" and input:isDown("b")) then
      return base
    end
    return math.max(1, math.floor(base / 2))
  end)

  if generation == 1 then
    local repairing = false
    mod.events:on("world.stepped", function(payload)
      if repairing then return end
      local player = (type(payload) == "table" and payload.player)
        or (mod.world and mod.world.player and mod.world:player())
      if not player or player.moving or type(player.stepLength) ~= "function" then
        return
      end
      repairing = true
      local ok, len = pcall(player.stepLength, player)
      repairing = false
      if ok and type(len) == "number" then
        player.stepFramesCur = len
      end
    end)
  end
end

