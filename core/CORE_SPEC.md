# Jinro Core Specification

## vote
1日目 以降、全員が自分以外の生存者1人を選ぶ

## Role-Specific Rules

### seer
- divine
  - 0日目以降毎日。自分以外の生存者から1人を選ぶ
  - 結果は対象の役職名 (wolf / villager / hamster など)

### medium
- medium
  - 1日目以降、投票で処刑者が出た時に自動で通知
  - medium アクションを手動提出する必要はない
  - 結果は wolf or not_wolf

### bodyguard
- guard
  - Day N (N>=1): can guard (protect one target from bite)

### wolf
- Day N (N>=1): can bite (only at night, N>=1)

### lover
- love
  - Day 1: must choose partner (love action)
- suicide
  - lover or loved が死ぬと相方はその日のうちに死ぬ

### bitch
lover と同じだが、 fake_love アクションが追加
- fake_love
  - Day 1: must choose partner (love action)
  - 相手には love と同じ通知が行くが実際には lovers にならない

### hamster
- bite されても死なない (after all log のみ)
- divine target にされると死ぬ

## Victory Rules (Current Implementation)
- 生存者が2人で、その2人が相互に恋人ペアなら恋人勝利
- それ以外で生存人狼が 0 人なら村勝利
- それ以外で生存人狼数 >= 生存村陣営数 なら人狼勝利
- 上記のいずれかで勝敗が確定し、ハムスターが生存していればハムスター勝利で上書き

---

## Day Number Convention
```
day 0 = setup (create_village直後、seer の divine は可能)
day 1 = vote + night actions
day N (N>=1) = vote + night actions
```

Each `process_day` call represents one full cycle (night + day voting).


