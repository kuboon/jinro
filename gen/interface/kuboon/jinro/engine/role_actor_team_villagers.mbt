///|
priv struct VillagerActor {}

///|
impl RoleActor for VillagerActor

///|
impl RoleActor for VillagerActor with can_do_action(
  _self,
  action_type,
  day_number,
) {
  action_type == ActionType::VOTE && day_number >= 1
}

///|
impl RoleActor for VillagerActor with available_actions(
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

///|
priv struct SeerActor {}

///|
impl RoleActor for SeerActor

///|
impl RoleActor for SeerActor with can_do_action(_self, action_type, day_number) {
  match action_type {
    ActionType::DIVINE => true
    ActionType::VOTE => day_number >= 1
    _ => false
  }
}

///|
impl RoleActor for SeerActor with available_actions(
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
    self.can_do_action(ActionType::DIVINE, day_number),
    ActionType::DIVINE,
    alive_ids_except(village, creature_id),
  )
  out
}

///|
impl RoleActor for SeerActor with resolve_action(_self, village, action, _) {
  if not(action.action_type == ActionType::DIVINE) {
    return empty_role_effect()
  }
  match action.target {
    Some(target) => {
      let divine_result = if is_wolf_role(village, target) {
        LogResult::Wolf
      } else {
        LogResult::NonWolf
      }
      let logs = [
        {
          receivers: Receivers::Only([action.actor]),
          action_type: ActionType::DIVINE,
          actor: Some(action.actor),
          target: Some(target),
          log_result: Some(divine_result),
        },
      ]
      let deaths = match role_of(village, target) {
        Some(RoleType::HAMSTER) =>
          [{ creature_id: target, cause: ActionType::HAMSTER_CURSE }]
        _ => []
      }
      { logs, deaths }
    }
    None => empty_role_effect()
  }
}

///|
priv struct BodyguardActor {}

///|
impl RoleActor for BodyguardActor

///|
impl RoleActor for BodyguardActor with can_do_action(
  _self,
  action_type,
  day_number,
) {
  (action_type == ActionType::GUARD && day_number >= 1) ||
  (action_type == ActionType::VOTE && day_number >= 1)
}

///|
impl RoleActor for BodyguardActor with available_actions(
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
    self.can_do_action(ActionType::GUARD, day_number),
    ActionType::GUARD,
    alive_ids(village),
  )
  out
}

///|
impl RoleActor for BodyguardActor with resolve_action(_self, _, action, _) {
  if not(action.action_type == ActionType::GUARD) {
    return empty_role_effect()
  }
  {
    logs: [
      {
        receivers: Receivers::Only([action.actor]),
        action_type: ActionType::GUARD,
        actor: Some(action.actor),
        target: action.target,
        log_result: Some(LogResult::Guarded),
      },
    ],
    deaths: [],
  }
}

///|
priv struct MediumActor {}

///|
impl RoleActor for MediumActor

///|
impl RoleActor for MediumActor with can_do_action(
  _self,
  action_type,
  day_number,
) {
  action_type == ActionType::VOTE && day_number >= 1
}

///|
impl RoleActor for MediumActor with available_actions(
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

///|
impl RoleActor for MediumActor with on_executed(
  _self,
  village,
  self_id,
  executed_id,
) {
  let res = if is_wolf_role(village, executed_id) {
    LogResult::Wolf
  } else {
    LogResult::NonWolf
  }
  {
    logs: [
      {
        receivers: Receivers::Only([self_id]),
        action_type: ActionType::MEDIUM,
        actor: Some(self_id),
        target: Some(executed_id),
        log_result: Some(res),
      },
    ],
    deaths: [],
  }
}

///|
priv struct HamsterActor {}

///|
impl RoleActor for HamsterActor

///|
impl RoleActor for HamsterActor with can_do_action(
  _self,
  action_type,
  day_number,
) {
  action_type == ActionType::VOTE && day_number >= 1
}

///|
impl RoleActor for HamsterActor with available_actions(
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

///|
impl RoleActor for HamsterActor with override_winner(
  _self,
  village,
  self_id,
  base,
) {
  match base {
    Some(_) =>
      if is_alive(village, self_id) {
        Some(Team::HAMSTERS)
      } else {
        None
      }
    None => None
  }
}
