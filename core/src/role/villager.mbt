// Villager role module
fn villager_mod() -> RoleModule {
  {
    name: "villager",
    team: "villagers",
    choices: fn(day_number, _role) {
      if day_number >= 1 {
        // Villager can vote for anyone (handled by engine)
        [] 
      } else {
        []
      }
    },
    actions: fn(action, _village, _all_actions) {
      // Villager has no special actions, just voting handled by engine
      []
    },
  }
}
