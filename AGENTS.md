# Jinro - Werewolf Game Engine

## Project Overview

A monorepo for a werewolf (人狼) game engine with core logic implemented in MoonBit compiled to WASM, with bindings for JavaScript, Ruby, etc.

## Architecture

```
jinro/
├── core/           # MoonBit implementation (WASM)
├── bindings/
│   ├── js/         # JavaScript/TypeScript bindings
│   ├── python/     # Python bindings
│   └── ruby/       # Ruby bindings
```

## Core Module (MoonBit/WASM)

### Role System

Implemented roles:
- `villager` : 村人 (1日目以降投票のみ)
- `seer` :  占師 (0日目夜から占う)
- `medium` : 霊媒師 (その日に投票で処刑された人物の人狼判定を知る)
- `bodyguard` : ボディーガード (護衛)
- `wolf` : 人狼 (襲撃)
- `madman`: 狂人 (人狼チームの人間)
- `hamster`: ハムスター人間 (噛まれても死なない、占われると死体になる)
- `lover` : 恋人 (自分以外の1人に求婚し、2人で恋人チームを形成する)
- `bitch` : 悪女 (恋人の亜種)

### 勝利条件
- 生存人狼がゼロになるとゲーム終了
  - ハムスターが生存してればハムスター陣営勝利
  - 恋人が揃って生存していたら恋人陣営勝利
  - それ以外なら村チーム勝利
- 生存人数の過半数が人狼になった時
  - 恋狼が生存している場合は恋狼以外の狼が全滅するか、恋狼が死ぬまで続行
  - 恋狼が生き残れば恋人陣営勝利
  - 恋人がおらず、ハムスターが生存していればハムスター勝利
  - 恋狼がいなければ人狼、狂人勝利

### Core Functions

```moonbit
type CreatureId = string
type LogId = string
enum Role
enum ActionType
enum Team
enum ActionResult {
  Wolf
  NonWolf
}
enum CauseOfDeath {
  Executed
  FoundDead
}

type Rule
type Creature {
  id: CreatureId
  role: Role
}
type Village {
  rule: Rule
  creatures: Array[Creature]
  days: Array[Day]
}
type Day {
  day_number: Int
  actions: Array[Action]
  logs: Array[Log]
}
type Action {
  actor: CreatureId
  action_type: ActionType
  target: Option[CreatureId]
}
type PossibleAction {
  action_type:
  targets: List[CreatureId]
}
type Log {
  id: LogId
  receivers: Array[CreatureId] | "all" | "afterall"
  action_type: ActionType
  actor: Option[CreatureId]
  target: Option[CreatureId]
  result: Option[ActionResult]
}

// 村作成。 CreatureId 発行 (days: [])、 0日目の Today 返却
fn create_village(roles: Array[Role], rule: Rule) -> (Village, Today)

// 翌日の情報を取得 (生存者一覧、実行可能なアクション、閲覧可能なログ)
type CreatureStatus {
  creature_id: CreatureId
  possible_actions: List[PossibleAction]
  cause_of_death: Option[CauseOfDeath]
  log_ids: Array[LogId]
}
type Today {
  day_number: Int
  winner: Option[Team] // ゲーム終了時に勝者が入る
  creature_statuses: Array[CreatureStatus]
}

// アクション実行
fn process_day(village: Village, actions: Array[Action]) -> (Village, Array[Log], Today)

```

### Example Flow
```psudo
rule = { vote: "public" }
roles = [
  { role_type: Villager, metadata: {} },
  { role_type: Wolf, metadata: {} },
  { role_type: Seer, metadata: {} }
]
village, today = create_village(roles, rule)
while(today.winner is null){
  actions = []
  today.creature_statuses.each {|status|
    status.possible_actions.each {|possible_action|
      target = await ask(possible_action)
      actions.add (
        actor: status.creature_id,
        action_type: possible_action.action_type,
        target
      )
    }
  }
  village, logs, today = process_day(village, actions)
  display(logs)
}
```

## Bindings

### JavaScript (TypeScript)
- publish to jsr
- Package name: `@kuboon/jinro`
- Export TypeScript types matching core types

### Ruby
- Gem Package name: `jinro`
- Use https://github.com/wasmerio/wasmer-ruby

## Development Flow

1. Implement core in MoonBit (`core/`)
2. Write tests for core logic
3. Build WASM: `moon build --target wasm`
4. Implement bindings for each language
5. Write tests for bindings
6. CI/CD for automated build, publish

## References

- Existing TypeScript implementation: https://github.com/kuboon/jinro.ts
- MoonBit: https://www.moonbitlang.com/
