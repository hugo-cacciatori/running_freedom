-- The engine has no native dash-eligibility hook in 0.3.96. Install a single
-- bridge and let the loader own its behavior through a normal hook subscription.
-- On rollback/reset the bridge is inert, even if another mod wraps it later.
return function(mod)
  local Player = require("src.core.game3.player")
  local Profile = require("src.core.game3.profile")
  local Collision = require("src.core.game3.collision")
  local Space = require("src.core.game3.scripting.space")
  local MB = require("src.core.game3.mb")
  local Runtime = require("src.mods.Runtime")
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
end
