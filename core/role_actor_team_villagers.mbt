///|
priv struct VillagerActor {}
impl RoleActor for VillagerActor

///|
impl RoleActor for VillagerActor with can_do_action(_self, action_type, day_number) {
  action_type == ActionType::Vote && day_number >= 1
}

///|
impl RoleActor for VillagerActor with available_actions(self, village, creature_id, day_number) {
  vote_actions(village, creature_id, self.can_do_action(ActionType::Vote, day_number))
}

///|
priv struct SeerActor {}
impl RoleActor for SeerActor

///|
impl RoleActor for SeerActor with can_do_action(_self, action_type, day_number) {
  match action_type {
    ActionType::Divine => true
    ActionType::Vote => day_number >= 1
    _ => false
  }
}

///|
impl RoleActor for SeerActor with available_actions(self, village, creature_id, day_number) {
  let mut out = vote_actions(
    village,
    creature_id,
    self.can_do_action(ActionType::Vote, day_number),
  )
  out = add_action(
    out,
    self.can_do_action(ActionType::Divine, day_number),
    ActionType::Divine,
    alive_ids_except(village, creature_id),
  )
  out
}

///|
impl RoleActor for SeerActor with resolve_action(_self, village, action, _) {
  if not(action.action_type == ActionType::Divine) {
    return empty_role_effect()
  }
  match action.target {
    Some(target) => {
      let divine_result = if is_wolf_role(village, target) {
        LogResult::Wolf
      } else {
        LogResult::NonWolf
      }
      let logs = [{
        receivers: Receivers::Only([action.actor]),
        action_type: ActionType::Divine,
        actor: Some(action.actor),
        target: Some(target),
        result: Some(divine_result),
      }]
      let deaths = match role_of(village, target) {
        Some(RoleType::Hamster) => [{ creature_id: target, cause: ActionType::HamsterCurse }]
        _ => []
      }
      { logs, deaths }
    }
    None => empty_role_effect()
  }
}

///|
priv struct BodyguardActor {}
impl RoleActor for BodyguardActor

///|
impl RoleActor for BodyguardActor with can_do_action(_self, action_type, day_number) {
  (action_type == ActionType::Guard && day_number >= 1) ||
  (action_type == ActionType::Vote && day_number >= 1)
}

///|
impl RoleActor for BodyguardActor with available_actions(self, village, creature_id, day_number) {
  let mut out = vote_actions(
    village,
    creature_id,
    self.can_do_action(ActionType::Vote, day_number),
  )
  out = add_action(
    out,
    self.can_do_action(ActionType::Guard, day_number),
    ActionType::Guard,
    alive_ids(village),
  )
  out
}

///|
impl RoleActor for BodyguardActor with resolve_action(_self, _, action, _) {
  if not(action.action_type == ActionType::Guard) {
    return empty_role_effect()
  }
  {
    logs: [{
      receivers: Receivers::Only([action.actor]),
      action_type: ActionType::Guard,
      actor: Some(action.actor),
      target: action.target,
      result: Some(LogResult::Guarded),
    }],
    deaths: [],
  }
}

///|
priv struct MediumActor {}
impl RoleActor for MediumActor

///|
impl RoleActor for MediumActor with can_do_action(_self, action_type, day_number) {
  action_type == ActionType::Vote && day_number >= 1
}

///|
impl RoleActor for MediumActor with available_actions(self, village, creature_id, day_number) {
  vote_actions(village, creature_id, self.can_do_action(ActionType::Vote, day_number))
}

///|
impl RoleActor for MediumActor with on_executed(_self, village, self_id, executed_id) {
  let res = if is_wolf_role(village, executed_id) {
    LogResult::Wolf
  } else {
    LogResult::NonWolf
  }
  {
    logs: [{
      receivers: Receivers::Only([self_id]),
      action_type: ActionType::Medium,
      actor: Some(self_id),
      target: Some(executed_id),
      result: Some(res),
    }],
    deaths: [],
  }
}

///|
priv struct HamsterActor {}
impl RoleActor for HamsterActor

///|
impl RoleActor for HamsterActor with can_do_action(_self, action_type, day_number) {
  action_type == ActionType::Vote && day_number >= 1
}

///|
impl RoleActor for HamsterActor with available_actions(self, village, creature_id, day_number) {
  vote_actions(village, creature_id, self.can_do_action(ActionType::Vote, day_number))
}

///|
impl RoleActor for HamsterActor with override_winner(_self, village, self_id, base) {
  match base {
    Some(_) => if is_alive(village, self_id) { Some(Team::Hamsters) } else { None }
    None => None
  }
}
