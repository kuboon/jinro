pub type CreatureId = String
pub type RoleType = String
pub type ActionType = String
pub type Team = String
pub type VoteType = String
pub type Result = String

pub(all) enum Receivers {
  All
  Afterall
  Only(Array[CreatureId])
}

pub(all) struct Rule {
  vote: VoteType
}

pub(all) struct Role {
  role_type: RoleType
  metadata: Map[String, String]
}

pub(all) struct Creature {
  id: CreatureId
  role: Role
}

pub(all) struct Action {
  actor: CreatureId
  action_type: ActionType
  target: CreatureId?
}

pub(all) struct Log {
  receivers: Receivers
  action_type: ActionType
  actor: CreatureId?
  target: CreatureId?
  result: String?
}

pub(all) struct Day {
  day_number: Int
  actions: Array[Action]
  logs: Array[Log]
}

pub(all) struct Village {
  rule: Rule
  creatures: Array[Creature]
  days: Array[Day]
}

pub(all) struct AvailableAction {
  action_type: ActionType
  targets: Array[CreatureId]
}

pub(all) struct CreatureStatus {
  id: CreatureId
  role_type: RoleType
  team: Team
  status: Result
  available_actions: Array[AvailableAction]
  cause_of_death: String?
}

pub(all) struct DeathRecord {
  creature_id: CreatureId
  reason: String
}

pub(all) struct Today {
  day_number: Int
  alive_creatures: Array[CreatureStatus]
  all_creatures: Array[CreatureStatus]
  game_result: Team?
}

pub(all) struct DayResult {
  today: Today
  logs: Array[Log]
  deaths: Array[DeathRecord]
}

// Constructor functions for creating instances
pub fn make_rule(vote: VoteType) -> Rule {
  { vote, }
}

pub fn make_role(role_type: RoleType) -> Role {
  { role_type, metadata: Map::new(), }
}

pub fn make_role_with_metadata(role_type: RoleType, metadata: Map[String, String]) -> Role {
  { role_type, metadata, }
}

pub fn make_creature(id: CreatureId, role: Role) -> Creature {
  { id, role, }
}

pub fn make_action(actor: CreatureId, action_type: ActionType, target: CreatureId?) -> Action {
  { actor, action_type, target, }
}

pub fn make_log(
  receivers: Receivers,
  action_type: ActionType,
  actor: CreatureId?,
  target: CreatureId?,
  result: String?,
) -> Log {
  { receivers, action_type, actor, target, result, }
}

pub fn make_day(day_number: Int, actions: Array[Action], logs: Array[Log]) -> Day {
  { day_number, actions, logs, }
}

pub fn make_village(rule: Rule, creatures: Array[Creature], days: Array[Day]) -> Village {
  { rule, creatures, days, }
}

pub fn make_available_action(action_type: ActionType, targets: Array[CreatureId]) -> AvailableAction {
  { action_type, targets, }
}

pub fn make_creature_status(
  id: CreatureId,
  role_type: RoleType,
  team: Team,
  status: Result,
  available_actions: Array[AvailableAction],
  cause_of_death: String?,
) -> CreatureStatus {
  { id, role_type, team, status, available_actions, cause_of_death, }
}

pub fn make_death_record(creature_id: CreatureId, reason: String) -> DeathRecord {
  { creature_id, reason, }
}

pub fn make_today(
  day_number: Int,
  alive_creatures: Array[CreatureStatus],
  all_creatures: Array[CreatureStatus],
  game_result: Team?,
) -> Today {
  { day_number, alive_creatures, all_creatures, game_result, }
}

pub fn make_day_result(
  today: Today,
  logs: Array[Log],
  deaths: Array[DeathRecord],
) -> DayResult {
  { today, logs, deaths, }
}
