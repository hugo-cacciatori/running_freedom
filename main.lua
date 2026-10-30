-- Running Freedom: B-button running indoors and without Running Shoes across
-- Gen 1, Gen 2, and Gen 3; on Gen 3 a B press toggles running.
-- - Gen 3 installs an idempotent Player.canDash bridge backed by an owner-scoped
--   hook so loader rollback/reset cleanly restores vanilla rules.
-- - Gen 1 and Gen 2 wrap the native movement.speed hook to halve walking step
--   frames while B is held on foot, and Gen 1 restores stepFramesCur on
--   world.stepped so NPC escort scripts stay synchronized.
-- The logic lives in the bundled `movement` lib (lib/movement/); this file only wires it.
return function(mod)
  local use = assert(load(assert(mod:read("lib/init.lua"), "missing lib/init.lua"), "@lib/init.lua"))(mod)
  use("movement").install(mod)
end
