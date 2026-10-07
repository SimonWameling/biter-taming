local CYAN = {r = 0.3, g = 1.0, b = 1.0}
local GREEN = {r = 0.4, g = 1.0, b = 0.4}

local function combined_tint(base, mul)
  if base == nil then
    return {r = mul.r, g = mul.g, b = mul.b, a = mul.a}
  end
  local result = {r = base.r * mul.r, g = base.g * mul.g, b = base.b * mul.b}
  result.a = (base.a or 1) * (mul.a or 1)
  return result
end

local function tint_animation(animation, tint)
  if not animation then return end
  local layers = animation.layers or {animation}
  for _, layer in ipairs(layers) do
    if layer.filename or layer.stripes then
      layer.tint = combined_tint(layer.tint, tint)
      if type(layer.hr_version) == "table" then
        layer.hr_version.tint = combined_tint(layer.hr_version.tint, tint)
      end
    end
  end
end

local function make_tamed_biter(name, source_name, tint)
  local unit = table.deepcopy(data.raw.unit[source_name])
  if not unit then
    error("biter-taming: source unit not found: " .. source_name)
  end
  unit.name = name
  unit.icons = {
    {
      icon = unit.icon or ("__base__/graphics/icons/" .. source_name .. ".png"),
      icon_size = unit.icon_size or 64,
      tint = tint
    }
  }
  unit.icon = nil
  unit.icon_size = nil
  unit.flags = unit.flags or {}
  table.insert(unit.flags, "get-by-unit-number")
  tint_animation(unit.run_animation, tint)
  if unit.attack_parameters then
    tint_animation(unit.attack_parameters.animation, tint)
  end
  return unit
end

data:extend({
  make_tamed_biter("tamed-small-biter", "small-biter", CYAN),
  make_tamed_biter("tamed-medium-biter", "medium-biter", CYAN),
  make_tamed_biter("tamed-big-biter", "big-biter", CYAN),
  make_tamed_biter("tamed-behemoth-biter", "behemoth-biter", CYAN)
})

local spoil_seconds = settings.startup["biter-taming-egg-spoil-time"].value
local wood_cost = settings.startup["biter-taming-taming-wood-cost"].value

local function make_tamed_egg(name, tint, effect_id, order)
  local egg = table.deepcopy(data.raw.item["biter-egg"])
  if not egg then
    error("biter-taming: biter-egg item not found")
  end
  egg.name = name
  egg.icons = {
    {
      icon = "__space-age__/graphics/icons/biter-egg.png",
      icon_size = 64,
      tint = tint
    }
  }
  egg.icon = nil
  egg.icon_size = nil
  egg.order = order
  egg.spoil_ticks = spoil_seconds * 60
  egg.spoil_result = nil
  egg.spoil_to_trigger_result = {
    items_per_trigger = 1,
    trigger = {
      type = "direct",
      action_delivery = {
        type = "instant",
        source_effects = {
          {
            type = "script",
            effect_id = effect_id
          }
        }
      }
    }
  }
  if egg.pictures then
    for _, picture in ipairs(egg.pictures) do
      picture.tint = combined_tint(picture.tint, tint)
    end
  end
  return egg
end

data:extend({
  make_tamed_egg("tamed-biter-egg", CYAN, "biter-taming-hatch", "c[eggs]-b[tamed-biter-egg]"),
  make_tamed_egg("chipped-tamed-biter-egg", GREEN, "biter-taming-hatch-chipped", "c[eggs]-c[chipped-tamed-biter-egg]")
})

data:extend({
  {
    type = "recipe",
    name = "tame-biter-egg",
    category = "crafting",
    enabled = false,
    energy_required = 5,
    ingredients = {
      {type = "item", name = "biter-egg", amount = 1},
      {type = "item", name = "wood", amount = wood_cost}
    },
    results = {{type = "item", name = "tamed-biter-egg", amount = 1}},
    subgroup = "agriculture-products",
    order = "c[eggs]-b[tamed-biter-egg]"
  },
  {
    type = "recipe",
    name = "chip-tamed-biter-egg",
    category = "crafting",
    enabled = false,
    energy_required = 3,
    ingredients = {
      {type = "item", name = "tamed-biter-egg", amount = 1},
      {type = "item", name = "electronic-circuit", amount = 1}
    },
    results = {{type = "item", name = "chipped-tamed-biter-egg", amount = 1}},
    subgroup = "agriculture-products",
    order = "c[eggs]-c[chipped-tamed-biter-egg]"
  }
})

local function tier_technology(name, icon, prerequisite, effect_key)
  return {
    type = "technology",
    name = name,
    icon = icon,
    icon_size = 256,
    prerequisites = {prerequisite},
    effects = {
      {type = "nothing", effect_description = {"biter-taming-effect." .. effect_key}}
    },
    unit = {
      count = 200,
      time = 30,
      ingredients = {
        {"automation-science-pack", 1},
        {"military-science-pack", 1}
      }
    }
  }
end

data:extend({
  {
    type = "technology",
    name = "biter-taming-basics",
    icon = "__base__/graphics/technology/defender.png",
    icon_size = 256,
    prerequisites = {"biter-egg-handling"},
    effects = {
      {type = "unlock-recipe", recipe = "tame-biter-egg"}
    },
    unit = {
      count = 100,
      time = 15,
      ingredients = {{"automation-science-pack", 1}}
    }
  },
  tier_technology("biter-evolution-medium", "__base__/graphics/technology/physical-projectile-damage-1.png", "biter-taming-basics", "unlocked-medium"),
  tier_technology("biter-evolution-big", "__base__/graphics/technology/physical-projectile-damage-2.png", "biter-evolution-medium", "unlocked-big"),
  tier_technology("biter-evolution-behemoth", "__base__/graphics/technology/stronger-explosives-1.png", "biter-evolution-big", "unlocked-behemoth"),
  {
    type = "technology",
    name = "biter-evolution-infinite",
    icon = "__base__/graphics/technology/stronger-explosives-2.png",
    icon_size = 256,
    prerequisites = {"biter-evolution-behemoth"},
    upgrade = true,
    max_level = "infinite",
    effects = {
      {type = "nothing", effect_description = {"biter-taming-effect.evolve"}}
    },
    unit = {
      count_formula = "2^(L-1)*200",
      time = 60,
      ingredients = {
        {"automation-science-pack", 1},
        {"military-science-pack", 1}
      }
    }
  },
  {
    type = "technology",
    name = "biter-chip-control",
    icon = "__base__/graphics/technology/circuit-network.png",
    icon_size = 256,
    prerequisites = {"biter-taming-basics"},
    effects = {
      {type = "unlock-recipe", recipe = "chip-tamed-biter-egg"}
    },
    unit = {
      count = 150,
      time = 20,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1}
      }
    }
  },
  {
    type = "custom-input",
    name = "biter-taming-chip-manual",
    key_sequence = "ALT + M",
    action = "lua"
  },
  {
    type = "custom-input",
    name = "biter-taming-chip-follow",
    key_sequence = "ALT + F",
    action = "lua"
  },
  {
    type = "custom-input",
    name = "biter-taming-chip-autonomous",
    key_sequence = "ALT + A",
    action = "lua"
  }
})
