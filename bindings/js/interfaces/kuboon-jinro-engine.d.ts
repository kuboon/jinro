/** @module Interface kuboon:jinro/engine **/
export function createVillage(roles: Array<Role>, rule: Rule): [Village, Today];
export function processDay(village: Village, actions: Array<Action>): [DayResult, Village, Today];
export type CreatureId = string;
/**
 * # Variants
 *
 * ## `"villagers"`
 *
 * ## `"wolves"`
 *
 * ## `"hamsters"`
 *
 * ## `"lovers"`
 */
export type Team = 'villagers' | 'wolves' | 'hamsters' | 'lovers';
/**
 * # Variants
 *
 * ## `"vote"`
 *
 * ## `"bite"`
 *
 * ## `"divine"`
 *
 * ## `"medium"`
 *
 * ## `"guard"`
 *
 * ## `"hamster-curse"`
 *
 * ## `"love"`
 *
 * ## `"lovers-suicide"`
 *
 * ## `"fake-love"`
 *
 * ## `"unknown"`
 */
export type ActionType = 'vote' | 'bite' | 'divine' | 'medium' | 'guard' | 'hamster-curse' | 'love' | 'lovers-suicide' | 'fake-love' | 'unknown';
/**
 * # Variants
 *
 * ## `"executed"`
 *
 * ## `"found-dead"`
 */
export type CauseOfDeath = 'executed' | 'found-dead';
/**
 * # Variants
 *
 * ## `"villager"`
 *
 * ## `"seer"`
 *
 * ## `"bodyguard"`
 *
 * ## `"wolf"`
 *
 * ## `"madman"`
 *
 * ## `"lover"`
 *
 * ## `"bitch"`
 *
 * ## `"medium"`
 *
 * ## `"hamster"`
 */
export type RoleType = 'villager' | 'seer' | 'bodyguard' | 'wolf' | 'madman' | 'lover' | 'bitch' | 'medium' | 'hamster';
export type Receivers = ReceiversAll | ReceiversAfterall | ReceiversOnly;
export interface ReceiversAll {
  tag: 'all',
}
export interface ReceiversAfterall {
  tag: 'afterall',
}
export interface ReceiversOnly {
  tag: 'only',
  val: Array<CreatureId>,
}
export type LogResult = LogResultDead | LogResultGuarded | LogResultPartnered | LogResultWolf | LogResultNonWolf;
export interface LogResultDead {
  tag: 'dead',
}
export interface LogResultGuarded {
  tag: 'guarded',
}
export interface LogResultPartnered {
  tag: 'partnered',
}
export interface LogResultWolf {
  tag: 'wolf',
}
export interface LogResultNonWolf {
  tag: 'non-wolf',
}
export type VoteRule = VoteRulePublic | VoteRulePrivate;
export interface VoteRulePublic {
  tag: 'public',
}
export interface VoteRulePrivate {
  tag: 'private',
}
export interface Rule {
  vote: VoteRule,
}
export type OptsEntry = [string, string];
export type Opts = Array<OptsEntry>;
export interface Role {
  roleType: RoleType,
  opts: Opts,
}
export interface Creature {
  id: CreatureId,
  role: Role,
}
export interface Action {
  actor: CreatureId,
  actionType: ActionType,
  target?: CreatureId,
}
export type LogId = string;
export interface Log {
  id: LogId,
  receivers: Receivers,
  actionType: ActionType,
  actor?: CreatureId,
  target?: CreatureId,
  logResult?: LogResult,
}
export interface Day {
  dayNumber: number,
  actions: Array<Action>,
  logs: Array<Log>,
}
export interface Village {
  rule: Rule,
  creatures: Array<Creature>,
  days: Array<Day>,
}
export interface AvailableAction {
  actionType: ActionType,
  targets: Array<CreatureId>,
}
export interface CreatureStatus {
  id: CreatureId,
  roleType: RoleType,
  team: Team,
  availableActions: Array<AvailableAction>,
  causeOfDeath?: CauseOfDeath,
  logIds: Array<LogId>,
}
export interface Today {
  dayNumber: number,
  winner?: Team,
  creatureStatuses: Array<CreatureStatus>,
}
export interface DayResult {
  voted: CreatureId,
  deads: Array<CreatureId>,
  logs: Array<Log>,
}
export type DataError = DataErrorDataError;
export interface DataErrorDataError {
  tag: 'data-error',
  val: string,
}
