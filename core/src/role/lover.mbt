// Lover role module
fn lover_mod() -> RoleModule {
  {
    name: "lover",
    team: "lovers",
    choices: fn(day_number, role) {
      if day_number == 1 {
        // Lover must choose partner on first night
        // Check if already has a partner in metadata
        match role.metadata.get("partner") {
          Some(_) => [] // Already has partner
          None => []    // Can choose any target
        }
      } else {
        // Can vote
        []
      }
    },
    actions: fn(action, _village, _all_actions) {
      if action.action_type == "love" {
        match action.target {
          Some(target_id) => {
            [
              {
                receivers: [action.actor, target_id],
                action_type: "love",
                actor: Some(action.actor),
                target: Some(target_id),
                result: Some("partnered"),
              },
            ]
          }
          None => []
        }
      } else {
        []
      }
    },
  }
}
