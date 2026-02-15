// Primitive types
type CreatureId String
type RoleType String
type ActionType String
type Team String
type VoteType String
type Result String

// Rule - voting system
type Rule {
  vote: VoteType
}

// Role - character role
type Role {
  role_type: RoleType
  metadata: Map[String, String]
}

// Creature - player in the game
type Creature {
  id: CreatureId
  role: Role
}

// Action - player action
type Action {
  actor: CreatureId
  action_type: ActionType
  target: Option[CreatureId]
}

// Log - record of events
type Log {
  receivers: Array[CreatureId] | "all" | "afterall"
  action_type: ActionType
  actor: Option[CreatureId]
  target: Option[CreatureId]
  result: Option[String]
}

// Day - one day of gameplay
type Day {
  day_number: Int
  actions: Array[Action]
  logs: Array[Log]
}

// Village - game state
type Village {
  rule: Rule
  creatures: Array[Creature]
  days: Array[Day]
}

// AvailableAction - what actions a creature can take
type AvailableAction {
  action_type: ActionType
  targets: Array[CreatureId]
}

// CreatureStatus - status of a creature
type CreatureStatus {
  id: CreatureId
  role_type: RoleType
  team: Team
  status: Result
  available_actions: Array[AvailableAction]
  cause_of_death: Option[String]
}

// DeathRecord - record of death
type DeathRecord {
  creature_id: CreatureId
  reason: String
}

// Today - current day information
type Today {
  day_number: Int
  alive_creatures: Array[CreatureStatus]
  all_creatures: Array[CreatureStatus]
  game_result: Option[Team]
}

// DayResult - result of processing a day
type DayResult {
  today: Today
  logs: Array[Log]
  deaths: Array[DeathRecord]
}

// Constructor functions for creating instances
pub fn make_rule(vote: VoteType) -> Rule {
  { vote }
}

pub fn make_role(role_type: RoleType) -> Role {
  { role_type, metadata: Map::new() }
}

pub fn make_role_with_metadata(role_type: RoleType, metadata: Map[String, String]) -> Role {
  { role_type, metadata }
}

pub fn make_creature(id: CreatureId, role: Role) -> Creature {
  { id, role }
}

pub fn make_action(actor: CreatureId, action_type: ActionType, target: Option[CreatureId]) -> Action {
  { actor, action_type, target }
}

pub fn make_log(
  receivers: Array[CreatureId] | "all" | "afterall",
  action_type: ActionType,
  actor: Option[CreatureId],
  target: Option[CreatureId],
  result: Option[String],
) -> Log {
  { receivers, action_type, actor, target, result }
}

pub fn make_day(day_number: Int, actions: Array[Action], logs: Array[Log]) -> Day {
  { day_number, actions, logs }
}

pub fn make_village(rule: Rule, creatures: Array[Creature], days: Array[Day]) -> Village {
  { rule, creatures, days }
}

pub fn make_available_action(action_type: ActionType, targets: Array[CreatureId]) -> AvailableAction {
  { action_type, targets }
}

pub fn make_creature_status(
  id: CreatureId,
  role_type: RoleType,
  team: Team,
  status: Result,
  available_actions: Array[AvailableAction],
  cause_of_death: Option[String],
) -> CreatureStatus {
  { id, role_type, team, status, available_actions, cause_of_death }
}

pub fn make_death_record(creature_id: CreatureId, reason: String) -> DeathRecord {
  { creature_id, reason }
}

pub fn make_today(
  day_number: Int,
  alive_creatures: Array[CreatureStatus],
  all_creatures: Array[CreatureStatus],
  game_result: Option[Team],
) -> Today {
  { day_number, alive_creatures, all_creatures, game_result }
}

pub fn make_day_result(
  today: Today,
  logs: Array[Log],
  deaths: Array[DeathRecord],
) -> DayResult {
  { today, logs, deaths }
}

// Type aliases for external use
pub typealias CreatureId = CreatureId
pub typealias RoleType = RoleType
pub typealias ActionType = ActionType
pub typealias Team = Team
pub typealias VoteType = VoteType
pub typealias Result = Result
