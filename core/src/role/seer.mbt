// Seer role module
fn seer_mod() -> RoleModule {
  {
    name: "seer",
    team: "villagers",
    choices: fn(day_number, _role) {
      if day_number == 1 {
        // Seer can divine on first night
        []
      } else if day_number >= 2 {
        // Can vote
        []
      } else {
        []
      }
    },
    actions: fn(action, village, _all_actions) {
      if action.action_type == "divine" {
        match action.target {
          Some(target_id) => {
            // Find the target's role
            let target_creature = village.creatures |> Array::find(fn(c) { c.id == target_id })
            match target_creature {
              Some(creature) => {
                let result = creature.role.role_type
                [
                  {
                    receivers: [action.actor],
                    action_type: "divine",
                    actor: Some(action.actor),
                    target: Some(target_id),
                    result: Some(result),
                  },
                ]
              }
              None => []
            }
          }
          None => []
        }
      } else {
        []
      }
    },
  }
}
