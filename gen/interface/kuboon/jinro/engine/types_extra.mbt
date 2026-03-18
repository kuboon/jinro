///|
pub type CreatureId = String

///|
pub type LogId = String

///|
pub(all) struct DeathRecord {
  creature_id : CreatureId
  reason : ActionType
}

///|
pub(all) struct DeathEffect {
  creature_id : CreatureId
  cause : ActionType
}

///|
pub(all) struct RoleEffectResult {
  logs : Array[Log]
  deaths : Array[DeathEffect]
}

// Constructor functions for creating instances

///|
pub fn make_rule(vote : VoteRule) -> Rule {
  { vote, }
}

///|
pub fn make_role(role_type : RoleType) -> Role {
  { role_type, opts: [] }
}

///|
pub fn make_role_with_opts(
  role_type : RoleType,
  opts : Array[(String, String)],
) -> Role {
  { role_type, opts }
}

///|
pub fn make_creature(id : CreatureId, role : Role) -> Creature {
  { id, role }
}

///|
pub fn make_action(
  actor : CreatureId,
  action_type : ActionType,
  target : CreatureId?,
) -> Action {
  { actor, action_type, target }
}

///|
pub fn make_log(
  receivers : Receivers,
  action_type : ActionType,
  actor : CreatureId?,
  target : CreatureId?,
  log_result : LogResult?,
) -> Log {
  { receivers, action_type, actor, target, log_result }
}

///|
pub fn make_day(
  day_number : Int,
  actions : Array[Action],
  logs : Array[Log],
) -> Day {
  { day_number, actions, logs }
}

///|
pub fn make_village(
  rule : Rule,
  creatures : Array[Creature],
  days : Array[Day],
) -> Village {
  { rule, creatures, days }
}

///|
pub fn make_available_action(
  action_type : ActionType,
  targets : Array[CreatureId],
) -> AvailableAction {
  { action_type, targets }
}

///|
pub fn make_death_record(
  creature_id : CreatureId,
  reason : ActionType,
) -> DeathRecord {
  { creature_id, reason }
}

///|
pub fn make_death_effect(
  creature_id : CreatureId,
  cause : ActionType,
) -> DeathEffect {
  { creature_id, cause }
}

///|
pub fn make_role_effect_result(
  logs : Array[Log],
  deaths : Array[DeathEffect],
) -> RoleEffectResult {
  { logs, deaths }
}

///|
pub fn make_today(
  day_number : Int,
  winner : Team?,
  creature_statuses : Array[CreatureStatus],
) -> Today {
  { day_number, winner, creature_statuses }
}

///|
pub fn make_day_result(
  voted : CreatureId,
  deads : Array[CreatureId],
  logs : Array[Log],
) -> DayResult {
  { voted, deads, logs }
}
