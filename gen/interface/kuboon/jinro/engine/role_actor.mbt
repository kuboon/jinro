///|
priv trait RoleActor {
  team(Self) -> Team = _
  can_do_action(Self, ActionType, Int) -> Bool = _
  available_actions(Self, Village, CreatureId, Int) -> Array[AvailableAction] = _
  resolve_action(Self, Village, Action, CreatureId?) -> RoleEffectResult = _
  on_death(Self, Village, Array[Log], CreatureId, CreatureId) -> RoleEffectResult = _
  on_executed(Self, Village, CreatureId, CreatureId) -> RoleEffectResult = _
  override_winner(Self, Village, CreatureId, Team?) -> Team? = _
}

///|
impl RoleActor with team(_self) {
  Team::VILLAGERS
}

///|
impl RoleActor with can_do_action(_self, _, _) {
  false
}

///|
impl RoleActor with available_actions(_self, _, _, _) {
  []
}

///|
impl RoleActor with resolve_action(_self, _, _, _) {
  { logs: [], deaths: [] }
}

///|
impl RoleActor with on_death(_self, _, _, _, _) {
  { logs: [], deaths: [] }
}

///|
impl RoleActor with on_executed(_self, _, _, _) {
  { logs: [], deaths: [] }
}

///|
impl RoleActor with override_winner(_self, _, _, _) {
  None
}

///|
fn empty_role_effect() -> RoleEffectResult {
  { logs: [], deaths: [] }
}

///|
fn vote_actions(
  village : Village,
  creature_id : CreatureId,
  enabled : Bool,
) -> Array[AvailableAction] {
  if enabled {
    [
      {
        action_type: ActionType::VOTE,
        targets: alive_ids_except(village, creature_id),
      },
    ]
  } else {
    []
  }
}

///|
fn add_action(
  actions : Array[AvailableAction],
  enabled : Bool,
  action_type : ActionType,
  targets : Array[CreatureId],
) -> Array[AvailableAction] {
  if enabled {
    [..actions, { action_type, targets }]
  } else {
    actions
  }
}

///|
fn partnered_love_effect(
  actor : CreatureId,
  target : CreatureId,
  receivers : Array[CreatureId],
) -> RoleEffectResult {
  {
    logs: [
      {
        receivers: Receivers::Only(receivers),
        action_type: ActionType::LOVE,
        actor: Some(actor),
        target: Some(target),
        log_result: Some(LogResult::Partnered),
      },
    ],
    deaths: [],
  }
}

///|
fn lovers_suicide_on_partner_death(
  village : Village,
  day_logs : Array[Log],
  self_id : CreatureId,
  dead_id : CreatureId,
) -> RoleEffectResult {
  match partner_of(village, day_logs, self_id) {
    Some(partner) =>
      if partner == dead_id {
        {
          logs: [],
          deaths: [{ creature_id: self_id, cause: ActionType::LOVERS_SUICIDE }],
        }
      } else {
        empty_role_effect()
      }
    None => empty_role_effect()
  }
}

///|
fn is_wolf_role(village : Village, id : CreatureId) -> Bool {
  match role_of(village, id) {
    Some(role_type) => role_actor_from_type(role_type).team() == Team::WOLVES
    None => false
  }
}

///|
fn role_actor_from_type(role_type : RoleType) -> &RoleActor {
  match role_type {
    RoleType::VILLAGER => VillagerActor::{  } as &RoleActor
    RoleType::SEER => SeerActor::{  } as &RoleActor
    RoleType::BODYGUARD => BodyguardActor::{  } as &RoleActor
    RoleType::WOLF => WolfActor::{  } as &RoleActor
    RoleType::MADMAN => MadmanActor::{  } as &RoleActor
    RoleType::LOVER => LoverActor::{  } as &RoleActor
    RoleType::BITCH => BitchActor::{  } as &RoleActor
    RoleType::MEDIUM => MediumActor::{  } as &RoleActor
    RoleType::HAMSTER => HamsterActor::{  } as &RoleActor
  }
}
