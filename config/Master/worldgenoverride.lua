return {
  override_enabled = true,
  preset = "SURVIVAL_TOGETHER",
  overrides = {
    -- Disable maximum-health loss after resurrection. This master-controlled
    -- world setting is synchronized to the Caves shard automatically.
    healthpenalty = "none",
  },
}
