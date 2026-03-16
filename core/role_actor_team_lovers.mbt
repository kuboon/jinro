///|
priv struct LoverActor {}
impl RoleActor for LoverActor

///|
impl RoleActor for LoverActor with team(_self) {
  Team::Lovers
}

///|
impl RoleActor for LoverActor with can_do_action(_self, action_type, day_number) {
  (action_type == ActionType::Love && day_number == 1) ||
  (action_type == ActionType::Vote && day_number >= 1)
}

///|
impl RoleActor for LoverActor with available_actions(self, village, creature_id, day_number) {
  let mut out = vote_actions(
    village,
    creature_id,
    self.can_do_action(ActionType::Vote, day_number),
  )
  out = add_action(
    out,
    self.can_do_action(ActionType::Love, day_number),
    ActionType::Love,
    alive_ids_except(village, creature_id),
  )
  out
}

///|
impl RoleActor for LoverActor with resolve_action(_self, _, action, _) {
  if not(action.action_type == ActionType::Love) {
    return empty_role_effect()
  }
  match action.target {
    Some(target) => partnered_love_effect(action.actor, target, [action.actor, target])
    None => empty_role_effect()
  }
}

///|
impl RoleActor for LoverActor with on_death(_self, village, day_logs, self_id, dead_id) {
  lovers_suicide_on_partner_death(village, day_logs, self_id, dead_id)
}

///|
priv struct BitchActor {}
impl RoleActor for BitchActor

///|
impl RoleActor for BitchActor with can_do_action(_self, action_type, day_number) {
  ((action_type == ActionType::Love || action_type == ActionType::FakeLove) && day_number == 1) ||
  (action_type == ActionType::Vote && day_number >= 1)
}

///|
impl RoleActor for BitchActor with available_actions(self, village, creature_id, day_number) {
  let mut out = vote_actions(
    village,
    creature_id,
    self.can_do_action(ActionType::Vote, day_number),
  )
  out = add_action(
    out,
    self.can_do_action(ActionType::Love, day_number),
    ActionType::Love,
    alive_ids_except(village, creature_id),
  )
  out = add_action(
    out,
    self.can_do_action(ActionType::FakeLove, day_number),
    ActionType::FakeLove,
    alive_ids_except(village, creature_id),
  )
  out
}

///|
impl RoleActor for BitchActor with resolve_action(_self, _, action, _) {
  match action.action_type {
    ActionType::Love =>
      match action.target {
        Some(target) => partnered_love_effect(action.actor, target, [action.actor, target])
        None => empty_role_effect()
      }
    ActionType::FakeLove =>
      match action.target {
        Some(target) => partnered_love_effect(action.actor, target, [target])
        None => empty_role_effect()
      }
    _ => empty_role_effect()
  }
}

///|
impl RoleActor for BitchActor with on_death(_self, village, day_logs, self_id, dead_id) {
  lovers_suicide_on_partner_death(village, day_logs, self_id, dead_id)
}
