// Wolf role module
fn wolf_mod() -> RoleModule {
  {
    name: "wolf",
    team: "wolves",
    choices: fn(day_number, _role) {
      if day_number >= 1 {
        // Wolf can bite someone each night
        []
      } else {
        []
      }
    },
    actions: fn(action, village, all_actions) {
      if action.action_type == "bite" {
        match action.target {
          Some(target_id) => {
            // Check if target is guarded
            let is_guarded = all_actions |> Array::exists(fn(a) {
              a.action_type == "guard" && a.target == Some(target_id)
            })
            if is_guarded {
              [
                {
                  receivers: [action.actor],
                  action_type: "bite",
                  actor: Some(action.actor),
                  target: Some(target_id),
                  result: Some("guarded"),
                },
              ]
            } else {
              [
                {
                  receivers: "all",
                  action_type: "bite",
                  actor: Some(action.actor),
                  target: Some(target_id),
                  result: Some("dead"),
                },
              ]
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
