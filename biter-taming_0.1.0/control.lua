local CHIP_RADIUS = 32
local CONTROL_INTERVAL = 30

local TIER_WEIGHTS = {
  {name = "tamed-small-biter", tier = 1, points = {{0.0, 0.3}, {0.6, 0.0}}},
  {name = "tamed-medium-biter", tier = 2, points = {{0.2, 0.0}, {0.6, 0.3}, {0.7, 0.1}}},
  {name = "tamed-big-biter", tier = 3, points = {{0.5, 0.0}, {1.0, 0.4}}},
  {name = "tamed-behemoth-biter", tier = 4, points = {{0.9, 0.0}, {1.0, 0.3}}}
}

local TIER_RESEARCH = {
  ["biter-evolution-medium"] = 2,
  ["biter-evolution-big"] = 3,
  ["biter-evolution-behemoth"] = 4
}

local function setup_force()
  local tamed = game.forces["tamed_biters"]
  if not tamed then
    tamed = game.create_force("tamed_biters")
  end
  if not tamed then
    return nil
  end
  local player = game.forces["player"]
  local enemy = game.forces["enemy"]
  if player then
    tamed.set_friend(player, true)
    player.set_friend(tamed, true)
  end
  if enemy then
    tamed.set_friend(enemy, false)
    enemy.set_friend(tamed, false)
    tamed.set_cease_fire(enemy, false)
    enemy.set_cease_fire(tamed, false)
  end
  return tamed
end

local function init_storage()
  if storage.tamed_evolution == nil then
    storage.tamed_evolution = {
      factor = 0,
      tiers = {[1] = true}
    }
  end
  if storage.chipped_units == nil then
    storage.chipped_units = {}
  end
end

local function apply_evolution_stats()
  local tamed = game.forces["tamed_biters"]
  if not tamed then
    return
  end
  local factor = storage.tamed_evolution.factor or 0
  tamed.set_ammo_damage_modifier("melee", factor * 0.5)
end

local function on_init()
  setup_force()
  init_storage()
  apply_evolution_stats()
end

local function on_configuration_changed()
  setup_force()
  init_storage()
  apply_evolution_stats()
end

script.on_init(on_init)
script.on_configuration_changed(on_configuration_changed)

local function weight_at(points, evolution)
  if evolution <= points[1][1] then
    return points[1][2]
  end
  for i = 2, #points do
    local previous = points[i - 1]
    local current = points[i]
    if evolution <= current[1] then
      local t = (evolution - previous[1]) / (current[1] - previous[1])
      return previous[2] + t * (current[2] - previous[2])
    end
  end
  return points[#points][2]
end

local function select_tier_name()
  local evolution = storage.tamed_evolution
  local evo = evolution.factor or 0
  local total = 0
  local weights = {}
  for _, entry in ipairs(TIER_WEIGHTS) do
    local weight = 0
    if evolution.tiers[entry.tier] then
      weight = weight_at(entry.points, evo)
    end
    weights[entry] = weight
    total = total + weight
  end
  if total <= 0 then
    return "tamed-small-biter"
  end
  local roll = math.random() * total
  for entry, weight in pairs(weights) do
    roll = roll - weight
    if roll < 0 then
      return entry.name
    end
  end
  return "tamed-small-biter"
end

local function spawn_position(surface, name, position)
  local entity = surface.create_entity({name = name, position = position, force = "tamed_biters"})
  if entity then
    return entity
  end
  local fallback = surface.find_non_colliding_position(name, position, 4, 0.5)
  if fallback then
    return surface.create_entity({name = name, position = fallback, force = "tamed_biters"})
  end
  return nil
end

script.on_event(defines.events.on_script_trigger_effect, function(event)
  if event.effect_id ~= "biter-taming-hatch" and event.effect_id ~= "biter-taming-hatch-chipped" then
    return
  end
  local surface = game.surfaces[event.surface_index]
  if not surface then
    return
  end
  local position = event.source_position
  if not position and event.source_entity and event.source_entity.valid then
    position = event.source_entity.position
  end
  if not position then
    position = event.target_position
  end
  if not position then
    return
  end
  local name = select_tier_name()
  local entity = spawn_position(surface, name, position)
  if not entity then
    return
  end
  if event.effect_id == "biter-taming-hatch-chipped" then
    init_storage()
    storage.chipped_units[entity.unit_number] = {mode = "autonomous"}
  end
end)

script.on_event(defines.events.on_research_finished, function(event)
  local research = event.research
  if not research then
    return
  end
  local evolution = storage.tamed_evolution
  if not evolution then
    return
  end
  local tier = TIER_RESEARCH[research.name]
  if tier then
    evolution.tiers[tier] = true
    return
  end
  if research.name == "biter-evolution-infinite" then
    local multiplier = settings.startup["biter-taming-evolution-speed-multiplier"].value
    evolution.factor = math.min(1, (evolution.factor or 0) + 0.01 * multiplier)
    apply_evolution_stats()
  end
end)

local function distance(a, b)
  local dx = a.x - b.x
  local dy = a.y - b.y
  return math.sqrt(dx * dx + dy * dy)
end

local function release_command(entity)
  local commandable = entity.commandable
  if commandable and commandable.has_command then
    commandable.set_command({type = defines.command.stop, ticks_to_wait = 1})
  end
end

local function each_chipped_in_radius(player, callback)
  local units = storage.chipped_units
  for unit_number, data in pairs(units) do
    local entity = game.get_entity_by_unit_number(unit_number)
    if not entity or not entity.valid then
      units[unit_number] = nil
    elseif distance(entity.position, player.position) <= CHIP_RADIUS then
      callback(entity, data)
    end
  end
end

local function handle_chip_input(mode)
  return function(event)
    local player = game.get_player(event.player_index)
    if not player then
      return
    end
    if mode == "manual" and event.in_gui then
      return
    end
    init_storage()
    each_chipped_in_radius(player, function(entity, data)
      data.mode = mode
      if mode == "manual" then
        data.destination = event.cursor_position
      else
        data.destination = nil
      end
      if mode == "follow" then
        data.player_index = event.player_index
      else
        data.player_index = nil
      end
      release_command(entity)
    end)
  end
end

script.on_event("biter-taming-chip-manual", handle_chip_input("manual"))
script.on_event("biter-taming-chip-follow", handle_chip_input("follow"))
script.on_event("biter-taming-chip-autonomous", handle_chip_input("autonomous"))

script.on_nth_tick(CONTROL_INTERVAL, function()
  local units = storage.chipped_units
  if not units or next(units) == nil then
    return
  end
  for unit_number, data in pairs(units) do
    local entity = game.get_entity_by_unit_number(unit_number)
    if not entity or not entity.valid then
      units[unit_number] = nil
    else
      local commandable = entity.commandable
      if commandable then
        local mode = data.mode or "autonomous"
        if mode == "manual" and data.destination then
          if not commandable.has_command and distance(entity.position, data.destination) > 4 then
            commandable.set_command({
              type = defines.command.go_to_location,
              destination = data.destination,
              radius = 3,
              distraction = defines.distraction.by_enemy
            })
          end
        elseif mode == "follow" and data.player_index then
          local target_player = game.get_player(data.player_index)
          if target_player then
            local target_position = target_player.position
            local too_far = distance(entity.position, target_position) > 4
            local target_moved = data.last_issue and distance(data.last_issue, target_position) > 5
            local needs_command = too_far and (not commandable.has_command or target_moved)
            if needs_command and game.tick >= (data.next_issue or 0) then
              commandable.set_command({
                type = defines.command.go_to_location,
                destination = target_position,
                radius = 3,
                distraction = defines.distraction.by_enemy
              })
              data.last_issue = {x = target_position.x, y = target_position.y}
              data.next_issue = game.tick + CONTROL_INTERVAL
            end
          end
        elseif mode == "autonomous" then
          if commandable.is_script_driven then
            release_command(entity)
          end
        end
      end
    end
  end
end)
