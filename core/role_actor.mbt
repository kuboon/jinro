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

priv enum RoleActorEnum {
  Villager
  Seer
  Bodyguard
  Wolf
  Madman
  Lover
  Bitch
  Medium
  Hamster
}

fn role_actor_from_type(role_type: RoleType) -> RoleActorEnum {
  match role_type {
    RoleType::Villager => RoleActorEnum::Villager
    RoleType::Seer => RoleActorEnum::Seer
    RoleType::Bodyguard => RoleActorEnum::Bodyguard
    RoleType::Wolf => RoleActorEnum::Wolf
    RoleType::Madman => RoleActorEnum::Madman
    RoleType::Lover => RoleActorEnum::Lover
    RoleType::Bitch => RoleActorEnum::Bitch
    RoleType::Medium => RoleActorEnum::Medium
    RoleType::Hamster => RoleActorEnum::Hamster
  }
}

fn RoleActorEnum::team(self: RoleActorEnum) -> Team {
  match self {
    RoleActorEnum::Villager => VillagerActor::team()
    RoleActorEnum::Seer => SeerActor::team()
    RoleActorEnum::Bodyguard => BodyguardActor::team()
    RoleActorEnum::Wolf => WolfActor::team()
    RoleActorEnum::Madman => MadmanActor::team()
    RoleActorEnum::Lover => LoverActor::team()
    RoleActorEnum::Bitch => BitchActor::team()
    RoleActorEnum::Medium => MediumActor::team()
    RoleActorEnum::Hamster => HamsterActor::team()
  }
}

fn RoleActorEnum::available_actions(
  self: RoleActorEnum,
  village: Village,
  creature_id: CreatureId,
  day_number: Int,
) -> Array[AvailableAction] {
  match self {
    RoleActorEnum::Villager => VillagerActor::available_actions(village, creature_id, day_number)
    RoleActorEnum::Seer => SeerActor::available_actions(village, creature_id, day_number)
    RoleActorEnum::Bodyguard => BodyguardActor::available_actions(village, creature_id, day_number)
    RoleActorEnum::Wolf => WolfActor::available_actions(village, creature_id, day_number)
    RoleActorEnum::Madman => MadmanActor::available_actions(village, creature_id, day_number)
    RoleActorEnum::Lover => LoverActor::available_actions(village, creature_id, day_number)
    RoleActorEnum::Bitch => BitchActor::available_actions(village, creature_id, day_number)
    RoleActorEnum::Medium => MediumActor::available_actions(village, creature_id, day_number)
    RoleActorEnum::Hamster => HamsterActor::available_actions(village, creature_id, day_number)
  }
}

fn RoleActorEnum::resolve_action(
  self: RoleActorEnum,
  village: Village,
  action: Action,
  guarded: CreatureId?,
) -> RoleEffectResult {
  match self {
    RoleActorEnum::Villager => VillagerActor::resolve_action(village, action, guarded)
    RoleActorEnum::Seer => SeerActor::resolve_action(village, action, guarded)
    RoleActorEnum::Bodyguard => BodyguardActor::resolve_action(village, action, guarded)
    RoleActorEnum::Wolf => WolfActor::resolve_action(village, action, guarded)
    RoleActorEnum::Madman => MadmanActor::resolve_action(village, action, guarded)
    RoleActorEnum::Lover => LoverActor::resolve_action(village, action, guarded)
    RoleActorEnum::Bitch => BitchActor::resolve_action(village, action, guarded)
    RoleActorEnum::Medium => MediumActor::resolve_action(village, action, guarded)
    RoleActorEnum::Hamster => HamsterActor::resolve_action(village, action, guarded)
  }
}

fn RoleActorEnum::on_death(
  self: RoleActorEnum,
  village: Village,
  day_logs: Array[Log],
  self_id: CreatureId,
  dead_id: CreatureId,
) -> RoleEffectResult {
  match self {
    RoleActorEnum::Villager => VillagerActor::on_death(village, day_logs, self_id, dead_id)
    RoleActorEnum::Seer => SeerActor::on_death(village, day_logs, self_id, dead_id)
    RoleActorEnum::Bodyguard => BodyguardActor::on_death(village, day_logs, self_id, dead_id)
    RoleActorEnum::Wolf => WolfActor::on_death(village, day_logs, self_id, dead_id)
    RoleActorEnum::Madman => MadmanActor::on_death(village, day_logs, self_id, dead_id)
    RoleActorEnum::Lover => LoverActor::on_death(village, day_logs, self_id, dead_id)
    RoleActorEnum::Bitch => BitchActor::on_death(village, day_logs, self_id, dead_id)
    RoleActorEnum::Medium => MediumActor::on_death(village, day_logs, self_id, dead_id)
    RoleActorEnum::Hamster => HamsterActor::on_death(village, day_logs, self_id, dead_id)
  }
}

fn RoleActorEnum::on_executed(
  self: RoleActorEnum,
  village: Village,
  self_id: CreatureId,
  executed_id: CreatureId,
) -> RoleEffectResult {
  match self {
    RoleActorEnum::Villager => VillagerActor::on_executed(village, self_id, executed_id)
    RoleActorEnum::Seer => SeerActor::on_executed(village, self_id, executed_id)
    RoleActorEnum::Bodyguard => BodyguardActor::on_executed(village, self_id, executed_id)
    RoleActorEnum::Wolf => WolfActor::on_executed(village, self_id, executed_id)
    RoleActorEnum::Madman => MadmanActor::on_executed(village, self_id, executed_id)
    RoleActorEnum::Lover => LoverActor::on_executed(village, self_id, executed_id)
    RoleActorEnum::Bitch => BitchActor::on_executed(village, self_id, executed_id)
    RoleActorEnum::Medium => MediumActor::on_executed(village, self_id, executed_id)
    RoleActorEnum::Hamster => HamsterActor::on_executed(village, self_id, executed_id)
  }
}

fn RoleActorEnum::override_winner(
  self: RoleActorEnum,
  village: Village,
  self_id: CreatureId,
  base: Team?,
) -> Team? {
  match self {
    RoleActorEnum::Villager => VillagerActor::override_winner(village, self_id, base)
    RoleActorEnum::Seer => SeerActor::override_winner(village, self_id, base)
    RoleActorEnum::Bodyguard => BodyguardActor::override_winner(village, self_id, base)
    RoleActorEnum::Wolf => WolfActor::override_winner(village, self_id, base)
    RoleActorEnum::Madman => MadmanActor::override_winner(village, self_id, base)
    RoleActorEnum::Lover => LoverActor::override_winner(village, self_id, base)
    RoleActorEnum::Bitch => BitchActor::override_winner(village, self_id, base)
    RoleActorEnum::Medium => MediumActor::override_winner(village, self_id, base)
    RoleActorEnum::Hamster => HamsterActor::override_winner(village, self_id, base)
  }
}

fn role_team_of(role_type: RoleType) -> Team {
  role_actor_from_type(role_type).team()
}