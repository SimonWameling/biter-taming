data:extend({
  {
    type = "double-setting",
    name = "biter-taming-evolution-speed-multiplier",
    setting_type = "startup",
    default_value = 1.0,
    minimum_value = 0.1,
    maximum_value = 10.0,
    order = "a"
  },
  {
    type = "int-setting",
    name = "biter-taming-egg-spoil-time",
    setting_type = "startup",
    default_value = 15,
    minimum_value = 1,
    maximum_value = 3600,
    order = "b"
  },
  {
    type = "int-setting",
    name = "biter-taming-taming-wood-cost",
    setting_type = "startup",
    default_value = 5,
    minimum_value = 0,
    maximum_value = 100,
    order = "c"
  }
})
