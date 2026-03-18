///|
priv struct WolfActor {}

///|
impl RoleActor for WolfActor

///|
impl RoleActor for WolfActor with team(_self) {
  Team::WOLVES
}

///|
impl RoleActor for WolfActor with can_do_action(_self, action_type, day_number) {
  (action_type == ActionType::BITE && day_number >= 1) ||
  (action_type == ActionType::VOTE && day_number >= 1)
}

///|
impl RoleActor for WolfActor with available_actions(
  self,
  village,
  creature_id,
  day_number,
) {
  let mut out = vote_actions(
    village,
    creature_id,
    self.can_do_action(ActionType::VOTE, day_number),
  )
  out = add_action(
    out,
    self.can_do_action(ActionType::BITE, day_number),
    ActionType::BITE,
    alive_non_wolf_ids(village),
  )
  out
}

///|
impl RoleActor for WolfActor with resolve_action(_self, _, action, guarded) {
  if not(action.action_type == ActionType::BITE) {
    return empty_role_effect()
  }
  match action.target {
    Some(target) =>
      if guarded == Some(target) {
        {
          logs: [
            {
              receivers: Receivers::Only([action.actor]),
              action_type: ActionType::BITE,
              actor: Some(action.actor),
              target: Some(target),
              log_result: Some(LogResult::Guarded),
            },
          ],
          deaths: [],
        }
      } else {
        {
          logs: [
            {
              receivers: Receivers::Only([action.actor]),
              action_type: ActionType::BITE,
              actor: Some(action.actor),
              target: Some(target),
              log_result: Some(LogResult::Dead),
            },
          ],
          deaths: [{ creature_id: target, cause: ActionType::BITE }],
        }
      }
    None => empty_role_effect()
  }
}

///|
priv struct MadmanActor {}

///|
impl RoleActor for MadmanActor

///|
impl RoleActor for MadmanActor with team(_self) {
  Team::WOLVES
}

///|
impl RoleActor for MadmanActor with can_do_action(
  _self,
  action_type,
  day_number,
) {
  action_type == ActionType::VOTE && day_number >= 1
}

///|
impl RoleActor for MadmanActor with available_actions(
  self,
  village,
  creature_id,
  day_number,
) {
  vote_actions(
    village,
    creature_id,
    self.can_do_action(ActionType::VOTE, day_number),
  )
}
