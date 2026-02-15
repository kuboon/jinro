// Jinro package - public API
// Re-export types and engine functions

pub typealias Rule = types.Rule
pub typealias Role = types.Role
pub typealias Creature = types.Creature
pub typealias Action = types.Action
pub typealias Log = types.Log
pub typealias Day = types.Day
pub typealias Village = types.Village
pub typealias AvailableAction = types.AvailableAction
pub typealias CreatureStatus = types.CreatureStatus
pub typealias DeathRecord = types.DeathRecord
pub typealias Today = types.Today
pub typealias DayResult = types.DayResult

pub typealias CreatureId = types.CreatureId
pub typealias RoleType = types.RoleType
pub typealias ActionType = types.ActionType
pub typealias Team = types.Team
pub typealias VoteType = types.VoteType
pub typealias Result = types.Result

pub fn make_rule { types.make_rule }
pub fn make_role { types.make_role }
pub fn make_creature { types.make_creature }
pub fn make_action { types.make_action }
pub fn make_log { types.make_log }
pub fn make_day { types.make_day }
pub fn make_village { types.make_village }
pub fn make_available_action { types.make_available_action }
pub fn make_creature_status { types.make_creature_status }
pub fn make_death_record { types.make_death_record }
pub fn make_today { types.make_today }
pub fn make_day_result { types.make_day_result }

pub fn create_village { engine.create_village }
pub fn process_day { engine.process_day }
pub fn get_available_actions { engine.get_available_actions }
