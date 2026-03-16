priv trait RoleActor {
  team(Self) -> Team = _
  can_do_action(Self, ActionType, Int) -> Bool = _
  available_actions(Self, Village, CreatureId, Int) -> Array[AvailableAction] = _
  resolve_action(Self, Village, Action, CreatureId?) -> RoleEffectResult = _
  on_death(Self, Village, Array[Log], CreatureId, CreatureId) -> RoleEffectResult = _
  on_executed(Self, Village, CreatureId, CreatureId) -> RoleEffectResult = _
  override_winner(Self, Village, CreatureId, Team?) -> Team? = _
}

impl RoleActor with team(_self) {
  Team::Villagers
}

impl RoleActor with can_do_action(_self, _, _) {
  false
}

impl RoleActor with available_actions(_self, _, _, _) {
  []
}

impl RoleActor with resolve_action(_self, _, _, _) {
  { logs: [], deaths: [] }
}

impl RoleActor with on_death(_self, _, _, _, _) {
  { logs: [], deaths: [] }
}

impl RoleActor with on_executed(_self, _, _, _) {
  { logs: [], deaths: [] }
}

impl RoleActor with override_winner(_self, _, _, _) {
  None
}

priv struct VillagerActor {}
impl RoleActor for VillagerActor

impl RoleActor for VillagerActor with can_do_action(_self, action_type, day_number) {
  action_type == ActionType::Vote && day_number >= 1
}

impl RoleActor for VillagerActor with available_actions(self, village, creature_id, day_number) {
  let mut out: Array[AvailableAction] = []
  if self.can_do_action(ActionType::Vote, day_number) {
    out = [..out, { action_type: ActionType::Vote, targets: alive_ids_except(village, creature_id) }]
  }
  out
}

priv struct SeerActor {}
impl RoleActor for SeerActor

impl RoleActor for SeerActor with can_do_action(_self, action_type, day_number) {
  match action_type {
    ActionType::Divine => true
    ActionType::Vote => day_number >= 1
    _ => false
  }
}

impl RoleActor for SeerActor with available_actions(self, village, creature_id, day_number) {
  let mut out: Array[AvailableAction] = []
  if self.can_do_action(ActionType::Vote, day_number) {
    out = [..out, { action_type: ActionType::Vote, targets: alive_ids_except(village, creature_id) }]
  }
  if self.can_do_action(ActionType::Divine, day_number) {
    out = [..out, { action_type: ActionType::Divine, targets: alive_ids_except(village, creature_id) }]
  }
  out
}

impl RoleActor for SeerActor with resolve_action(_self, village, action, _) {
  if not(action.action_type == ActionType::Divine) {
    return { logs: [], deaths: [] }
  }
  match action.target {
    Some(target) => {
      match role_of(village, target) {
        Some(target_role) => {
          let divine_result = if role_actor_from_type(target_role).team() == Team::Wolves {
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
          let deaths = match target_role {
            RoleType::Hamster => [{ creature_id: target, cause: ActionType::HamsterCurse }]
            _ => []
          }
          { logs, deaths }
        }
        None => { logs: [], deaths: [] }
      }
    }
    None => { logs: [], deaths: [] }
  }
}

priv struct BodyguardActor {}
impl RoleActor for BodyguardActor

impl RoleActor for BodyguardActor with can_do_action(_self, action_type, day_number) {
  (action_type == ActionType::Guard && day_number >= 1) || (action_type == ActionType::Vote && day_number >= 1)
}

impl RoleActor for BodyguardActor with available_actions(self, village, creature_id, day_number) {
  let mut out: Array[AvailableAction] = []
  if self.can_do_action(ActionType::Vote, day_number) {
    out = [..out, { action_type: ActionType::Vote, targets: alive_ids_except(village, creature_id) }]
  }
  if self.can_do_action(ActionType::Guard, day_number) {
    out = [..out, { action_type: ActionType::Guard, targets: alive_ids(village) }]
  }
  out
}

impl RoleActor for BodyguardActor with resolve_action(_self, _, action, _) {
  if not(action.action_type == ActionType::Guard) {
    return { logs: [], deaths: [] }
  }
  {
    logs: [{ receivers: Receivers::Only([action.actor]), action_type: ActionType::Guard, actor: Some(action.actor), target: action.target, result: Some(LogResult::Guarded) }],
    deaths: [],
  }
}

priv struct WolfActor {}
impl RoleActor for WolfActor

impl RoleActor for WolfActor with team(_self) {
  Team::Wolves
}

impl RoleActor for WolfActor with can_do_action(_self, action_type, day_number) {
  (action_type == ActionType::Bite && day_number >= 1) || (action_type == ActionType::Vote && day_number >= 1)
}

impl RoleActor for WolfActor with available_actions(self, village, creature_id, day_number) {
  let mut out: Array[AvailableAction] = []
  if self.can_do_action(ActionType::Vote, day_number) {
    out = [..out, { action_type: ActionType::Vote, targets: alive_ids_except(village, creature_id) }]
  }
  if self.can_do_action(ActionType::Bite, day_number) {
    out = [..out, { action_type: ActionType::Bite, targets: alive_non_wolf_ids(village) }]
  }
  out
}

impl RoleActor for WolfActor with resolve_action(_self, _, action, guarded) {
  if not(action.action_type == ActionType::Bite) {
    return { logs: [], deaths: [] }
  }
  match action.target {
    Some(target) => {
      if guarded == Some(target) {
        {
          logs: [{ receivers: Receivers::Only([action.actor]), action_type: ActionType::Bite, actor: Some(action.actor), target: Some(target), result: Some(LogResult::Guarded) }],
          deaths: [],
        }
      } else {
        {
          logs: [{ receivers: Receivers::Only([action.actor]), action_type: ActionType::Bite, actor: Some(action.actor), target: Some(target), result: Some(LogResult::Dead) }],
          deaths: [{ creature_id: target, cause: ActionType::Bite }],
        }
      }
    }
    None => { logs: [], deaths: [] }
  }
}

priv struct MadmanActor {}
impl RoleActor for MadmanActor

impl RoleActor for MadmanActor with team(_self) {
  Team::Wolves
}

impl RoleActor for MadmanActor with can_do_action(_self, action_type, day_number) {
  action_type == ActionType::Vote && day_number >= 1
}

impl RoleActor for MadmanActor with available_actions(self, village, creature_id, day_number) {
  let mut out: Array[AvailableAction] = []
  if self.can_do_action(ActionType::Vote, day_number) {
    out = [..out, { action_type: ActionType::Vote, targets: alive_ids_except(village, creature_id) }]
  }
  out
}

priv struct LoverActor {}
impl RoleActor for LoverActor

impl RoleActor for LoverActor with team(_self) {
  Team::Lovers
}

impl RoleActor for LoverActor with can_do_action(_self, action_type, day_number) {
  (action_type == ActionType::Love && day_number == 1) || (action_type == ActionType::Vote && day_number >= 1)
}

impl RoleActor for LoverActor with available_actions(self, village, creature_id, day_number) {
  let mut out: Array[AvailableAction] = []
  if self.can_do_action(ActionType::Vote, day_number) {
    out = [..out, { action_type: ActionType::Vote, targets: alive_ids_except(village, creature_id) }]
  }
  if self.can_do_action(ActionType::Love, day_number) {
    out = [..out, { action_type: ActionType::Love, targets: alive_ids_except(village, creature_id) }]
  }
  out
}

impl RoleActor for LoverActor with resolve_action(_self, _, action, _) {
  if not(action.action_type == ActionType::Love) {
    return { logs: [], deaths: [] }
  }
  match action.target {
    Some(target) => {
      {
        logs: [{ receivers: Receivers::Only([action.actor, target]), action_type: ActionType::Love, actor: Some(action.actor), target: Some(target), result: Some(LogResult::Partnered) }],
        deaths: [],
      }
    }
    None => { logs: [], deaths: [] }
  }
}

impl RoleActor for LoverActor with on_death(_self, village, day_logs, self_id, dead_id) {
  match partner_of(village, day_logs, self_id) {
    Some(partner) => {
      if partner == dead_id {
        { logs: [], deaths: [{ creature_id: self_id, cause: ActionType::LoversSuicide }] }
      } else {
        { logs: [], deaths: [] }
      }
    }
    None => { logs: [], deaths: [] }
  }
}

priv struct BitchActor {}
impl RoleActor for BitchActor

impl RoleActor for BitchActor with can_do_action(_self, action_type, day_number) {
  ((action_type == ActionType::Love || action_type == ActionType::FakeLove) && day_number == 1) || (action_type == ActionType::Vote && day_number >= 1)
}

impl RoleActor for BitchActor with available_actions(self, village, creature_id, day_number) {
  let mut out: Array[AvailableAction] = []
  if self.can_do_action(ActionType::Vote, day_number) {
    out = [..out, { action_type: ActionType::Vote, targets: alive_ids_except(village, creature_id) }]
  }
  if self.can_do_action(ActionType::Love, day_number) {
    out = [..out, { action_type: ActionType::Love, targets: alive_ids_except(village, creature_id) }]
  }
  if self.can_do_action(ActionType::FakeLove, day_number) {
    out = [..out, { action_type: ActionType::FakeLove, targets: alive_ids_except(village, creature_id) }]
  }
  out
}

impl RoleActor for BitchActor with resolve_action(_self, _, action, _) {
  if action.action_type == ActionType::Love {
    match action.target {
      Some(target) => {
        return {
          logs: [{ receivers: Receivers::Only([action.actor, target]), action_type: ActionType::Love, actor: Some(action.actor), target: Some(target), result: Some(LogResult::Partnered) }],
          deaths: [],
        }
      }
      None => return { logs: [], deaths: [] }
    }
  }
  if action.action_type == ActionType::FakeLove {
    match action.target {
      Some(target) => {
        return {
          logs: [{ receivers: Receivers::Only([target]), action_type: ActionType::Love, actor: Some(action.actor), target: Some(target), result: Some(LogResult::Partnered) }],
          deaths: [],
        }
      }
      None => return { logs: [], deaths: [] }
    }
  }
  { logs: [], deaths: [] }
}

impl RoleActor for BitchActor with on_death(_self, village, day_logs, self_id, dead_id) {
  match partner_of(village, day_logs, self_id) {
    Some(partner) => {
      if partner == dead_id {
        { logs: [], deaths: [{ creature_id: self_id, cause: ActionType::LoversSuicide }] }
      } else {
        { logs: [], deaths: [] }
      }
    }
    None => { logs: [], deaths: [] }
  }
}

priv struct MediumActor {}
impl RoleActor for MediumActor

impl RoleActor for MediumActor with can_do_action(_self, action_type, day_number) {
  action_type == ActionType::Vote && day_number >= 1
}

impl RoleActor for MediumActor with available_actions(self, village, creature_id, day_number) {
  let mut out: Array[AvailableAction] = []
  if self.can_do_action(ActionType::Vote, day_number) {
    out = [..out, { action_type: ActionType::Vote, targets: alive_ids_except(village, creature_id) }]
  }
  out
}

impl RoleActor for MediumActor with on_executed(_self, village, self_id, executed_id) {
  let res = match role_of(village, executed_id) {
    Some(rt) => if role_actor_from_type(rt).team() == Team::Wolves { LogResult::Wolf } else { LogResult::NonWolf }
    None => LogResult::NonWolf
  }
  {
    logs: [{ receivers: Receivers::Only([self_id]), action_type: ActionType::Medium, actor: Some(self_id), target: Some(executed_id), result: Some(res) }],
    deaths: [],
  }
}

priv struct HamsterActor {}
impl RoleActor for HamsterActor

impl RoleActor for HamsterActor with can_do_action(_self, action_type, day_number) {
  action_type == ActionType::Vote && day_number >= 1
}

impl RoleActor for HamsterActor with available_actions(self, village, creature_id, day_number) {
  let mut out: Array[AvailableAction] = []
  if self.can_do_action(ActionType::Vote, day_number) {
    out = [..out, { action_type: ActionType::Vote, targets: alive_ids_except(village, creature_id) }]
  }
  out
}

impl RoleActor for HamsterActor with override_winner(_self, village, self_id, base) {
  match base {
    Some(_) => if is_alive(village, self_id) { Some(Team::Hamsters) } else { None }
    None => None
  }
}

fn role_actor_from_type(role_type: RoleType) -> &RoleActor {
  match role_type {
    RoleType::Villager => VillagerActor::{} as &RoleActor
    RoleType::Seer => SeerActor::{} as &RoleActor
    RoleType::Bodyguard => BodyguardActor::{} as &RoleActor
    RoleType::Wolf => WolfActor::{} as &RoleActor
    RoleType::Madman => MadmanActor::{} as &RoleActor
    RoleType::Lover => LoverActor::{} as &RoleActor
    RoleType::Bitch => BitchActor::{} as &RoleActor
    RoleType::Medium => MediumActor::{} as &RoleActor
    RoleType::Hamster => HamsterActor::{} as &RoleActor
  }
}

