// Bodyguard role module
fn bodyguard_mod() -> RoleModule {
  {
    name: "bodyguard",
    team: "villagers",
    choices: fn(day_number, _role) {
      if day_number >= 1 {
        // Bodyguard can guard someone each night
        []
      } else {
        []
      }
    },
    actions: fn(action, _village, _all_actions) {
      if action.action_type == "guard" {
        // Guard action - result is determined by engine based on wolf bite
        [
          {
            receivers: [action.actor],
            action_type: "guard",
            actor: Some(action.actor),
            target: action.target,
            result: Some("guarded"),
          },
        ]
      } else {
        []
      }
    },
  }
}
