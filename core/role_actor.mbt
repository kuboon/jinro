priv trait RoleActor {
  team() -> Team = _
  can_do_action(ActionType, Int) -> Bool = _
  available_actions(Village, CreatureId, Int) -> Array[AvailableAction] = _
  resolve_action(Village, Action, CreatureId?) -> RoleEffectResult = _
  on_death(Village, Array[Log], CreatureId, CreatureId) -> RoleEffectResult = _
  on_executed(Village, CreatureId, CreatureId) -> RoleEffectResult = _
  override_winner(Village, CreatureId, Team?) -> Team? = _
}

impl RoleActor with team() {
  Team::Villagers
}

impl RoleActor with can_do_action(_, _) {
  false
}

impl RoleActor with available_actions(_, _, _) {
  []
}

impl RoleActor with resolve_action(_, _, _) {
  { logs: [], deaths: [] }
}

impl RoleActor with on_death(_, _, _, _) {
  { logs: [], deaths: [] }
}

impl RoleActor with on_executed(_, _, _) {
  { logs: [], deaths: [] }
}

impl RoleActor with override_winner(_, _, _) {
  None
}

priv type VillagerActor
impl RoleActor for VillagerActor

impl RoleActor for VillagerActor with can_do_action(action_type, day_number) {
  action_type == ActionType::Vote && day_number >= 1
}

impl RoleActor for VillagerActor with available_actions(village, creature_id, day_number) {
  let mut out: Array[AvailableAction] = []
  if VillagerActor::can_do_action(ActionType::Vote, day_number) {
    out = [..out, { action_type: ActionType::Vote, targets: alive_ids_except(village, creature_id) }]
  }
  out
}

priv type SeerActor
impl RoleActor for SeerActor

impl RoleActor for SeerActor with can_do_action(action_type, day_number) {
  match action_type {
    ActionType::Divine => true
    ActionType::Vote => day_number >= 1
    _ => false
  }
}

impl RoleActor for SeerActor with available_actions(village, creature_id, day_number) {
  let mut out: Array[AvailableAction] = []
  if SeerActor::can_do_action(ActionType::Vote, day_number) {
    out = [..out, { action_type: ActionType::Vote, targets: alive_ids_except(village, creature_id) }]
  }
  if SeerActor::can_do_action(ActionType::Divine, day_number) {
    out = [..out, { action_type: ActionType::Divine, targets: alive_ids_except(village, creature_id) }]
  }
  out
}

impl RoleActor for SeerActor with resolve_action(village, action, _) {
  if not(action.action_type == ActionType::Divine) {
    return { logs: [], deaths: [] }
  }
  match action.target {
    Some(target) => {
      match role_of(village, target) {
        Some(target_role) => {
          let divine_result = if team_of(target_role) == Team::Wolves {
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

priv type BodyguardActor
impl RoleActor for BodyguardActor

impl RoleActor for BodyguardActor with can_do_action(action_type, day_number) {
  (action_type == ActionType::Guard && day_number >= 1) || (action_type == ActionType::Vote && day_number >= 1)
}

impl RoleActor for BodyguardActor with available_actions(village, creature_id, day_number) {
  let mut out: Array[AvailableAction] = []
  if BodyguardActor::can_do_action(ActionType::Vote, day_number) {
    out = [..out, { action_type: ActionType::Vote, targets: alive_ids_except(village, creature_id) }]
  }
  if BodyguardActor::can_do_action(ActionType::Guard, day_number) {
    out = [..out, { action_type: ActionType::Guard, targets: alive_ids(village) }]
  }
  out
}

impl RoleActor for BodyguardActor with resolve_action(_, action, _) {
  if not(action.action_type == ActionType::Guard) {
    return { logs: [], deaths: [] }
  }
  {
    logs: [{ receivers: Receivers::Only([action.actor]), action_type: ActionType::Guard, actor: Some(action.actor), target: action.target, result: Some(LogResult::Guarded) }],
    deaths: [],
  }
}

priv type WolfActor
impl RoleActor for WolfActor

impl RoleActor for WolfActor with team() {
  Team::Wolves
}

impl RoleActor for WolfActor with can_do_action(action_type, day_number) {
  (action_type == ActionType::Bite && day_number >= 1) || (action_type == ActionType::Vote && day_number >= 1)
}

impl RoleActor for WolfActor with available_actions(village, creature_id, day_number) {
  let mut out: Array[AvailableAction] = []
  if WolfActor::can_do_action(ActionType::Vote, day_number) {
    out = [..out, { action_type: ActionType::Vote, targets: alive_ids_except(village, creature_id) }]
  }
  if WolfActor::can_do_action(ActionType::Bite, day_number) {
    out = [..out, { action_type: ActionType::Bite, targets: alive_non_wolf_ids(village) }]
  }
  out
}

impl RoleActor for WolfActor with resolve_action(_, action, guarded) {
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

priv type MadmanActor
impl RoleActor for MadmanActor

impl RoleActor for MadmanActor with team() {
  Team::Wolves
}

impl RoleActor for MadmanActor with can_do_action(action_type, day_number) {
  action_type == ActionType::Vote && day_number >= 1
}

impl RoleActor for MadmanActor with available_actions(village, creature_id, day_number) {
  let mut out: Array[AvailableAction] = []
  if MadmanActor::can_do_action(ActionType::Vote, day_number) {
    out = [..out, { action_type: ActionType::Vote, targets: alive_ids_except(village, creature_id) }]
  }
  out
}

priv type LoverActor
impl RoleActor for LoverActor

impl RoleActor for LoverActor with team() {
  Team::Lovers
}

impl RoleActor for LoverActor with can_do_action(action_type, day_number) {
  (action_type == ActionType::Love && day_number == 1) || (action_type == ActionType::Vote && day_number >= 1)
}

impl RoleActor for LoverActor with available_actions(village, creature_id, day_number) {
  let mut out: Array[AvailableAction] = []
  if LoverActor::can_do_action(ActionType::Vote, day_number) {
    out = [..out, { action_type: ActionType::Vote, targets: alive_ids_except(village, creature_id) }]
  }
  if LoverActor::can_do_action(ActionType::Love, day_number) {
    out = [..out, { action_type: ActionType::Love, targets: alive_ids_except(village, creature_id) }]
  }
  out
}

impl RoleActor for LoverActor with resolve_action(_, action, _) {
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

impl RoleActor for LoverActor with on_death(village, day_logs, self_id, dead_id) {
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

priv type BitchActor
impl RoleActor for BitchActor

impl RoleActor for BitchActor with can_do_action(action_type, day_number) {
  ((action_type == ActionType::Love || action_type == ActionType::FakeLove) && day_number == 1) || (action_type == ActionType::Vote && day_number >= 1)
}

impl RoleActor for BitchActor with available_actions(village, creature_id, day_number) {
  let mut out: Array[AvailableAction] = []
  if BitchActor::can_do_action(ActionType::Vote, day_number) {
    out = [..out, { action_type: ActionType::Vote, targets: alive_ids_except(village, creature_id) }]
  }
  if BitchActor::can_do_action(ActionType::Love, day_number) {
    out = [..out, { action_type: ActionType::Love, targets: alive_ids_except(village, creature_id) }]
  }
  if BitchActor::can_do_action(ActionType::FakeLove, day_number) {
    out = [..out, { action_type: ActionType::FakeLove, targets: alive_ids_except(village, creature_id) }]
  }
  out
}

impl RoleActor for BitchActor with resolve_action(_, action, _) {
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

impl RoleActor for BitchActor with on_death(village, day_logs, self_id, dead_id) {
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

priv type MediumActor
impl RoleActor for MediumActor

impl RoleActor for MediumActor with can_do_action(action_type, day_number) {
  action_type == ActionType::Vote && day_number >= 1
}

impl RoleActor for MediumActor with available_actions(village, creature_id, day_number) {
  let mut out: Array[AvailableAction] = []
  if MediumActor::can_do_action(ActionType::Vote, day_number) {
    out = [..out, { action_type: ActionType::Vote, targets: alive_ids_except(village, creature_id) }]
  }
  out
}

impl RoleActor for MediumActor with on_executed(village, self_id, executed_id) {
  let res = match role_of(village, executed_id) {
    Some(rt) => if role_team_of(rt) == Team::Wolves { LogResult::Wolf } else { LogResult::NonWolf }
    None => LogResult::NonWolf
  }
  {
    logs: [{ receivers: Receivers::Only([self_id]), action_type: ActionType::Medium, actor: Some(self_id), target: Some(executed_id), result: Some(res) }],
    deaths: [],
  }
}

priv type HamsterActor
impl RoleActor for HamsterActor

impl RoleActor for HamsterActor with can_do_action(action_type, day_number) {
  action_type == ActionType::Vote && day_number >= 1
}

impl RoleActor for HamsterActor with available_actions(village, creature_id, day_number) {
  let mut out: Array[AvailableAction] = []
  if HamsterActor::can_do_action(ActionType::Vote, day_number) {
    out = [..out, { action_type: ActionType::Vote, targets: alive_ids_except(village, creature_id) }]
  }
  out
}

impl RoleActor for HamsterActor with override_winner(village, self_id, base) {
  match base {
    Some(_) => if is_alive(village, self_id) { Some(Team::Hamsters) } else { None }
    None => None
  }
}

fn role_team_of(role_type: RoleType) -> Team {
  match role_type {
    RoleType::Villager => VillagerActor::team()
    RoleType::Seer => SeerActor::team()
    RoleType::Bodyguard => BodyguardActor::team()
    RoleType::Wolf => WolfActor::team()
    RoleType::Madman => MadmanActor::team()
    RoleType::Lover => LoverActor::team()
    RoleType::Bitch => BitchActor::team()
    RoleType::Medium => MediumActor::team()
    RoleType::Hamster => HamsterActor::team()
  }
}

fn role_available_actions(role_type: RoleType, village: Village, creature_id: CreatureId, day_number: Int) -> Array[AvailableAction] {
  match role_type {
    RoleType::Villager => VillagerActor::available_actions(village, creature_id, day_number)
    RoleType::Seer => SeerActor::available_actions(village, creature_id, day_number)
    RoleType::Bodyguard => BodyguardActor::available_actions(village, creature_id, day_number)
    RoleType::Wolf => WolfActor::available_actions(village, creature_id, day_number)
    RoleType::Madman => MadmanActor::available_actions(village, creature_id, day_number)
    RoleType::Lover => LoverActor::available_actions(village, creature_id, day_number)
    RoleType::Bitch => BitchActor::available_actions(village, creature_id, day_number)
    RoleType::Medium => MediumActor::available_actions(village, creature_id, day_number)
    RoleType::Hamster => HamsterActor::available_actions(village, creature_id, day_number)
  }
}

fn role_resolve_action(role_type: RoleType, village: Village, action: Action, guarded: CreatureId?) -> RoleEffectResult {
  match role_type {
    RoleType::Villager => VillagerActor::resolve_action(village, action, guarded)
    RoleType::Seer => SeerActor::resolve_action(village, action, guarded)
    RoleType::Bodyguard => BodyguardActor::resolve_action(village, action, guarded)
    RoleType::Wolf => WolfActor::resolve_action(village, action, guarded)
    RoleType::Madman => MadmanActor::resolve_action(village, action, guarded)
    RoleType::Lover => LoverActor::resolve_action(village, action, guarded)
    RoleType::Bitch => BitchActor::resolve_action(village, action, guarded)
    RoleType::Medium => MediumActor::resolve_action(village, action, guarded)
    RoleType::Hamster => HamsterActor::resolve_action(village, action, guarded)
  }
}

fn role_on_death(role_type: RoleType, village: Village, day_logs: Array[Log], self_id: CreatureId, dead_id: CreatureId) -> RoleEffectResult {
  match role_type {
    RoleType::Villager => VillagerActor::on_death(village, day_logs, self_id, dead_id)
    RoleType::Seer => SeerActor::on_death(village, day_logs, self_id, dead_id)
    RoleType::Bodyguard => BodyguardActor::on_death(village, day_logs, self_id, dead_id)
    RoleType::Wolf => WolfActor::on_death(village, day_logs, self_id, dead_id)
    RoleType::Madman => MadmanActor::on_death(village, day_logs, self_id, dead_id)
    RoleType::Lover => LoverActor::on_death(village, day_logs, self_id, dead_id)
    RoleType::Bitch => BitchActor::on_death(village, day_logs, self_id, dead_id)
    RoleType::Medium => MediumActor::on_death(village, day_logs, self_id, dead_id)
    RoleType::Hamster => HamsterActor::on_death(village, day_logs, self_id, dead_id)
  }
}

fn role_on_executed(role_type: RoleType, village: Village, self_id: CreatureId, executed_id: CreatureId) -> RoleEffectResult {
  match role_type {
    RoleType::Villager => VillagerActor::on_executed(village, self_id, executed_id)
    RoleType::Seer => SeerActor::on_executed(village, self_id, executed_id)
    RoleType::Bodyguard => BodyguardActor::on_executed(village, self_id, executed_id)
    RoleType::Wolf => WolfActor::on_executed(village, self_id, executed_id)
    RoleType::Madman => MadmanActor::on_executed(village, self_id, executed_id)
    RoleType::Lover => LoverActor::on_executed(village, self_id, executed_id)
    RoleType::Bitch => BitchActor::on_executed(village, self_id, executed_id)
    RoleType::Medium => MediumActor::on_executed(village, self_id, executed_id)
    RoleType::Hamster => HamsterActor::on_executed(village, self_id, executed_id)
  }
}

fn role_override_winner(role_type: RoleType, village: Village, self_id: CreatureId, base: Team?) -> Team? {
  match role_type {
    RoleType::Villager => VillagerActor::override_winner(village, self_id, base)
    RoleType::Seer => SeerActor::override_winner(village, self_id, base)
    RoleType::Bodyguard => BodyguardActor::override_winner(village, self_id, base)
    RoleType::Wolf => WolfActor::override_winner(village, self_id, base)
    RoleType::Madman => MadmanActor::override_winner(village, self_id, base)
    RoleType::Lover => LoverActor::override_winner(village, self_id, base)
    RoleType::Bitch => BitchActor::override_winner(village, self_id, base)
    RoleType::Medium => MediumActor::override_winner(village, self_id, base)
    RoleType::Hamster => HamsterActor::override_winner(village, self_id, base)
  }
}