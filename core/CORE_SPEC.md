# Jinro Core Specification

## Core Design

Stateless function signature:
```
fn process_day(village: Village, actions: Action[]) -> (Village, DayResult)
```

Where:
- **Input**: `village` (current state) + `actions` (all actions for this day)
- **Output**: `village` (updated state) + `DayResult` (results + current day info)

---

## Data Types

### Primitive Types

```moonbit
type CreatureId = String
type RoleType = String // "villager" | "seer" | "bodyguard" | "wolf" | "lover"
type ActionType = String // "vote" | "bite" | "guard" | "divine" | "love"
type Team = String // "villagers" | "wolves" | "lovers"
type VoteType = String // "public" | "private"
type Result = String // "alive" | "dead"
```

### Rule

```moonbit
type Rule {
  vote: VoteType
}
```

### Role

```moonbit
type Role {
  role_type: RoleType
  // 拡張用 (例: lover の相方 ID など)
  metadata: Map[String, String]
}
```

### Creature

```moonbit
type Creature {
  id: CreatureId
  role: Role
}
```

### Action

```moonbit
type Action {
  actor: CreatureId
  action_type: ActionType
  target: Option[CreatureId]
}
```

### Log (record of what happened)

```moonbit
type Log {
  receivers: Array[CreatureId] | "all" | "afterall"
  action_type: ActionType
  actor: Option[CreatureId]
  target: Option[CreatureId]
  result: Option[String] // e.g., "dead", "wolf", "villager"
}
```

### Day

```moonbit
type Day {
  day_number: Int // 0 = 設定段階 (no actions yet), 1 = 1st night, 2 = 2nd day, ...
  actions: Array[Action]
  logs: Array[Log]
}
```

### Village

```moonbit
type Village {
  rule: Rule
  creatures: Array[Creature]
  days: Array[Day]
}
```

---

## Output Types

### AvailableAction

```moonbit
type AvailableAction {
  action_type: ActionType
  targets: Array[CreatureId] // 空配列 = ターゲットなし (投票など)
}
```

### CreatureStatus

```moonbit
type CreatureStatus {
  id: CreatureId
  role_type: RoleType
  team: Team
  status: Result // "alive" | "dead"
  available_actions: Array[AvailableAction]
  // 死因 (死んでいる場合)
  cause_of_death: Option[String]
}
```

### Today (current day info)

```moonbit
type Today {
  day_number: Int
  alive_creatures: Array[CreatureStatus]
  // 全プレイヤー (生存者 + 死亡者)
  all_creatures: Array[CreatureStatus]
  // ゲーム終了か、終了時の勝利陣営
  game_result: Option[Team]
}
```

### DayResult

```moonbit
type DayResult {
  today: Today
  logs: Array[Log]
  // 死亡者リスト
  deaths: Array[DeathRecord]
}
```

### DeathRecord

```moonbit
type DeathRecord {
  creature_id: CreatureId
  reason: String // "voted" | "bite" | "divine" | "lovers_suicide"
}
```

---

## Function Specification

### create_village

```moonbit
fn create_village(creatures: Array[Creature], rule: Rule) -> (Village, Today)
```

Creates initial village state (day 0), returns initial Today info.

### process_day

```moonbit
fn process_day(village: Village, actions: Array[Action]) -> (Village, DayResult)
```

1. Validate all actions (actor exists, action is valid for role, target is valid)
2. Execute actions in order:
   - All night actions first (bite, guard, divine, love)
   - Then vote
3. Calculate deaths
4. Generate logs
5. Update village state
6. Return updated village + DayResult

### get_available_actions

```moonbit
fn get_available_actions(village: Village, creature_id: CreatureId) -> Array[AvailableAction>
```

Returns what actions the creature can perform on the current day based on:
- Role
- Whether alive
- Current day number (some actions only on specific days)

---

## Role-Specific Rules

### villager
- Day N (N>=1): can vote

### seer
- Day 1: can divine (once only, or every night?)
- Day N (N>=2): can vote

### bodyguard
- Day N (N>=1): can guard (protect one target from bite)

### wolf
- Day N (N>=1): can bite (only at night, N>=1)
- Day N: can vote

### lover
- Day 1: must choose partner (love action)
- After: can vote

---

## Day Number Convention

- Day 0: Initial state, no actions yet
- Day 1: First night (Divine, Guard, Bite happen here)
- Day 2: First morning (Vote results, then night actions)
- ...

Actually, let's simplify:

```
day 0 = setup (no actions yet)
day 1 = first night actions -> morning results
day 2 = second day voting -> night actions -> ...
```

Each `process_day` call represents one full cycle (night + day voting).

---

## Example Flow

```
1. create_village(creatures, {vote: "public"})
   -> village, Today { day_number: 0, alive_creatures: [...], game_result: None }

2. process_day(village, [
     { actor: "A", action_type: "divine", target: Some("B") },
     { actor: "B", action_type: "bite", target: Some("C") },
     { actor: "C", action_type: "guard", target: Some("C") },
     { actor: "D", action_type: "vote", target: Some("E") },
   ])
   -> village', DayResult {
        today: Today { day_number: 1, alive_creatures: [...], game_result: None },
        logs: [...],
        deaths: [{ creature_id: "E", reason: "voted" }]
      }
```

---

## JSON Serialization

All functions take and return JSON strings.

```json
// Input
{
  "village": { ... },
  "actions": [ ... ]
}

// Output
{
  "village": { ... },
  "result": {
    "today": { ... },
    "logs": [ ... ],
    "deaths": [ ... ]
  }
}
```
