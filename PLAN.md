# Jinro - Werewolf Game Engine

## Project Overview

Create a monorepo for a werewolf (人狼) game engine with core logic implemented in MoonBit compiled to WASM, with bindings for JavaScript, Python, and Ruby.

## Architecture

```
jinro/
├── core/           # MoonBit implementation (WASM)
├── bindings/
│   ├── js/         # JavaScript/TypeScript bindings
│   ├── python/     # Python bindings
│   └── ruby/       # Ruby bindings
└── pkg/            # Published packages
```

## Core Module (MoonBit/WASM)

### Data Types (moonbit)

- `rule` : 投票ルール (public | private)
- `creature_id` : プレイヤーID (string)
- `role` : 役割タイプ + メタデータ
- `creature` : creature_id + role
- `action` : アクション (type, actor, target)
- `log` : ログ (receivers, action, actor, target, result)
- `day` : 1日のデータ (actions[], logs[])
- `village` : 村の状態 (rule, creatures[], days[])

### Role System

Each role module provides:
- `name` : 役割名
- `team` : 陣営 (villagers | wolves | lovers)
- `choices` : その日の選択可能ターゲット
- `actions` : アクション実行関数

Implemented roles:
- `villager` : 村人 (投票のみ)
- `seer` :  占師 (初日夜に占う)
- `bodyguard` : 護衛 (護衛)
- `wolf` : 人狼 (襲撃)
- `lover` : 恋人 (勝利条件追加)

### Core Functions

```moonbit
// 村作成
fn create_village(creatures: Creature[], rule: Rule) -> Village

// その日の情報を取得 (生存者一覧、実行可能なアクション)
fn get_day_info(village: Village, day_num: Int) -> DayInfo

// アクション実行
fn execute_action(village: Village, action: Action) -> Village

// ゲーム終了判定
fn is_game_end(village: Village) -> Option<Team>
```

### WASM Interface

Input/Output as JSON:
- `setup(creatures_json, rule_json)` -> village_json
- `get_day_info(village_json, day_num)` -> day_info_json
- `execute_action(village_json, action_json)` -> (village_json, result_json)
- `is_game_end(village_json)` -> team_json | null

## Bindings

### JavaScript (TypeScript)
- Package name: `@jinro/engine`
- Use `wasm-bindgen` or similar
- Export TypeScript types matching core types

### Python
- Package name: `jinro`
- Use `wasmtime` or Pyodide
- PyO3 alternative for direct Rust (but we use MoonBit)

### Ruby
- Package name: `jinro`
- Use `wasmoon` or rb-wasm
- Native extension alternative

## Development Flow

1. Implement core in MoonBit (`core/`)
2. Build WASM: `moon build --target wasm`
3. Implement bindings for each language
4. Write tests for core logic
5. CI/CD for automated builds

## References

- Existing TypeScript implementation: https://github.com/kuboon/jinro.ts
- MoonBit: https://www.moonbitlang.com/
