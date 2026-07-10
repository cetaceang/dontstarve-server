return {
  override_enabled = true,
  preset = "SURVIVAL_TOGETHER",
  overrides = {
    -- Disable maximum-health loss after resurrection. This master-controlled
    -- world setting is synchronized to the Caves shard automatically.
    healthpenalty = "none",
    -- Klei's option name intentionally uses the historical "resurection"
    -- spelling. Allow ghosts to resurrect at the Florid Postern at any time.
    portalresurection = "always",
  },
}
