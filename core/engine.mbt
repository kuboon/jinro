// Jinro core engine (stateless)

// RoleType constants
const ROLE_VILLAGER: RoleType = "villager"
const ROLE_SEER: RoleType = "seer"
const ROLE_BODYGUARD: RoleType = "bodyguard"
const ROLE_WOLF: RoleType = "wolf"
const ROLE_LOVER: RoleType = "lover"
const ROLE_BITCH: RoleType = "bitch"
const ROLE_MEDIUM: RoleType = "medium"
const ROLE_HAMSTER: RoleType = "hamster"

// ActionType constants
const ACTION_VOTE: ActionType = "vote"
const ACTION_BITE: ActionType = "bite"
const ACTION_UNKNOWN: ActionType = "unknown"
const ACTION_GUARD: ActionType = "guard"
const ACTION_DIVINE: ActionType = "divine"
const ACTION_LOVE: ActionType = "love"
const ACTION_FAKE_LOVE: ActionType = "fake_love"
const ACTION_LOVERS_SUICIDE: ActionType = "lovers_suicide"
const ACTION_MEDIUM: ActionType = "medium"
const ACTION_HAMSTER_CURSE: ActionType = "hamster_curse"

fn current_day(village: Village) -> Int {
  village.days.length()
}

fn team_of(role_type: RoleType) -> Team {
  if role_type == ROLE_WOLF {
    "wolves"
  } else if role_type == ROLE_LOVER {
    "lovers"
  } else {
    "villagers"
  }
}

fn is_hamster_alive(village: Village) -> Bool {
  for c in village.creatures {
    if c.role.role_type == ROLE_HAMSTER {
      if is_alive(village, c.id) {
        return true
      }
    }
  }
  false
}

fn role_of(village: Village, id: CreatureId) -> RoleType? {
  for c in village.creatures {
    if c.id == id {
      return Some(c.role.role_type)
    }
  }
  None
}

fn is_dead_by_logs(village: Village, id: CreatureId) -> Bool {
  for d in village.days {
    for l in d.logs {
      // Death should be determined by the in-game visible logs.
      match l.receivers {
        Receivers::All => {
          match (l.target, l.result) {
            (Some(t), Some(r)) => {
              if t == id && r == "dead" {
                return true
              }
            }
            _ => ()
          }
        }
        _ => ()
      }
    }
  }
  false
}

fn is_alive(village: Village, id: CreatureId) -> Bool {
  not(is_dead_by_logs(village, id))
}

fn alive_ids(village: Village) -> Array[CreatureId] {
  let mut ids: Array[CreatureId] = []
  for c in village.creatures {
    if is_alive(village, c.id) {
      ids = [..ids, c.id]
    }
  }
  ids
}

fn alive_ids_except(village: Village, me: CreatureId) -> Array[CreatureId] {
  let mut ids: Array[CreatureId] = []
  for id in alive_ids(village) {
    if id != me {
      ids = [..ids, id]
    }
  }
  ids
}

fn alive_non_wolf_ids(village: Village) -> Array[CreatureId] {
  let mut ids: Array[CreatureId] = []
  for c in village.creatures {
    if is_alive(village, c.id) {
      let t = team_of(c.role.role_type)
      if t != "wolves" {
        ids = [..ids, c.id]
      }
    }
  }
  ids
}

fn cause_of_death(village: Village, id: CreatureId) -> String? {
  for d in village.days {
    for l in d.logs {
      // In-game cause should not reveal hidden reasons.
      match l.receivers {
        Receivers::All => {
          match (l.target, l.result) {
            (Some(t), Some(r)) => {
              if t == id && r == "dead" {
                return Some(l.action_type)
              }
            }
            _ => ()
          }
        }
        _ => ()
      }
    }
  }
  None
}

fn partner_in_logs(logs: Array[Log], id: CreatureId) -> CreatureId? {
  for l in logs {
    if l.action_type == ACTION_LOVE && l.result == Some("partnered") {
      match (l.actor, l.target) {
        (Some(a), Some(t)) => {
          // Partnership is only formed if this love log is shared to both sides.
          // This allows fake love to show a "love" log to the target without forming a partnership.
          match l.receivers {
            Receivers::Only(rs) => {
              if not(contains_id(rs, a) && contains_id(rs, t)) {
                continue
              }
            }
            _ => continue
          }
          if a == id {
            return Some(t)
          }
          if t == id {
            return Some(a)
          }
        }
        _ => ()
      }
    }
  }
  None
}

fn partner_of(village: Village, day_logs: Array[Log], id: CreatureId) -> CreatureId? {
  let p = partner_in_logs(day_logs, id)
  match p {
    Some(_) => p
    None => {
      for d in village.days {
        let q = partner_in_logs(d.logs, id)
        match q {
          Some(_) => return q
          None => ()
        }
      }
      None
    }
  }
}

fn contains_id(ids: Array[CreatureId], id: CreatureId) -> Bool {
  for x in ids {
    if x == id {
      return true
    }
  }
  false
}

fn can_do_action(role_type: RoleType, action_type: ActionType, day_number: Int) -> Bool {
  // day_number is 0 at setup (no actions)
  if role_type == ROLE_VILLAGER {
    action_type == ACTION_VOTE && day_number >= 2
  } else if role_type == ROLE_SEER {
    (action_type == ACTION_DIVINE && day_number == 1) || (action_type == ACTION_VOTE && day_number >= 2)
  } else if role_type == ROLE_BODYGUARD {
    (action_type == ACTION_GUARD && day_number >= 1) || (action_type == ACTION_VOTE && day_number >= 2)
  } else if role_type == ROLE_WOLF {
    (action_type == ACTION_BITE && day_number >= 1) || (action_type == ACTION_VOTE && day_number >= 2)
  } else if role_type == ROLE_LOVER {
    (action_type == ACTION_LOVE && day_number == 1) || (action_type == ACTION_VOTE && day_number >= 2)
  } else if role_type == ROLE_BITCH {
    ((action_type == ACTION_LOVE || action_type == ACTION_FAKE_LOVE) && day_number == 1) || (action_type == ACTION_VOTE && day_number >= 2)
  } else if role_type == ROLE_MEDIUM {
    action_type == ACTION_VOTE && day_number >= 2
  } else if role_type == ROLE_HAMSTER {
    action_type == ACTION_VOTE && day_number >= 2
  } else {
    false
  }
}

pub fn get_available_actions(village: Village, creature_id: CreatureId) -> Array[AvailableAction] {
  if not(is_alive(village, creature_id)) {
    return []
  }
  let day_number = current_day(village)
  let role_type_opt = role_of(village, creature_id)
  match role_type_opt {
    None => []
    Some(role_type) => {
      let mut out: Array[AvailableAction] = []
      // vote
      if can_do_action(role_type, ACTION_VOTE, day_number) {
        out = [..out, { action_type: ACTION_VOTE, targets: alive_ids_except(village, creature_id) }]
      }
      // divine
      if can_do_action(role_type, ACTION_DIVINE, day_number) {
        out = [..out, { action_type: ACTION_DIVINE, targets: alive_ids_except(village, creature_id) }]
      }
      // guard
      if can_do_action(role_type, ACTION_GUARD, day_number) {
        out = [..out, { action_type: ACTION_GUARD, targets: alive_ids(village) }]
      }
      // bite
      if can_do_action(role_type, ACTION_BITE, day_number) {
        out = [..out, { action_type: ACTION_BITE, targets: alive_non_wolf_ids(village) }]
      }
      // love
      if can_do_action(role_type, ACTION_LOVE, day_number) {
        out = [..out, { action_type: ACTION_LOVE, targets: alive_ids_except(village, creature_id) }]
      }
      // fake love (bitch only)
      if can_do_action(role_type, ACTION_FAKE_LOVE, day_number) {
        out = [..out, { action_type: ACTION_FAKE_LOVE, targets: alive_ids_except(village, creature_id) }]
      }
      out
    }
  }
}

fn winner(village: Village) -> Team? {
  let mut base: Team? = None

  // Lovers win if the last two survivors are partnered.
  let alive = alive_ids(village)
  if alive.length() == 2 {
    let a = alive[0]
    let b = alive[1]
    let pa = partner_of(village, [], a)
    let pb = partner_of(village, [], b)
    if pa == Some(b) && pb == Some(a) {
      base = Some("lovers")
    }
  }

  let mut wolves = 0
  let mut villagers = 0
  let mut lovers = 0
  for c in village.creatures {
    if is_alive(village, c.id) {
      match team_of(c.role.role_type) {
        "wolves" => wolves = wolves + 1
        "lovers" => lovers = lovers + 1
        _ => villagers = villagers + 1
      }
    }
  }
  if base is None {
    if wolves == 0 {
      base = Some("villagers")
    } else if wolves >= villagers {
      base = Some("wolves")
    }
  }

  // Hamster wins solo if alive at game end.
  match base {
    Some(_) => {
      if is_hamster_alive(village) {
        return Some("hamster")
      }
      base
    }
    None => None
  }
}

fn build_status(village: Village, id: CreatureId) -> CreatureStatus {
  let mut role_type: RoleType = ROLE_VILLAGER
  for c in village.creatures {
    if c.id == id {
      role_type = c.role.role_type
    }
  }
  let t = team_of(role_type)
  let alive = is_alive(village, id)
  let status: Result = if alive { "alive" } else { "dead" }
  let actions = if alive { get_available_actions(village, id) } else { [] }
  let cod = if alive { None } else { cause_of_death(village, id) }
  {
    id,
    role_type,
    team: t,
    status,
    available_actions: actions,
    cause_of_death: cod,
  }
}

fn build_today(village: Village) -> Today {
  let day_number = current_day(village)
  let mut alive_creatures: Array[CreatureStatus] = []
  let mut all_creatures: Array[CreatureStatus] = []
  for c in village.creatures {
    let st = build_status(village, c.id)
    all_creatures = [..all_creatures, st]
    if st.status == "alive" {
      alive_creatures = [..alive_creatures, st]
    }
  }
  {
    day_number,
    alive_creatures,
    all_creatures,
    game_result: winner(village),
  }
}

pub fn create_village(creatures: Array[Creature], rule: Rule) -> (Village, Today) {
  let village: Village = { rule, creatures, days: [] }
  (village, build_today(village))
}

fn compute_vote_death(actions: Array[Action]) -> CreatureId? {
  let votes: Map[CreatureId, Int] = Map::new()
  for a in actions {
    if a.action_type == ACTION_VOTE {
      match a.target {
        Some(t) => {
          let cur = votes.get(t).unwrap_or(0)
          votes.set(t, cur + 1)
        }
        None => ()
      }
    }
  }

  let mut max = 0
  for _k, v in votes {
    if v > max {
      max = v
    }
  }
  if max == 0 {
    return None
  }

  let mut best: CreatureId? = None
  let mut tie = false
  for k, v in votes {
    if v == max {
      match best {
        None => best = Some(k)
        Some(_) => tie = true
      }
    }
  }
  if tie { None } else { best }
}

fn guarded_target(actions: Array[Action]) -> CreatureId? {
  for a in actions {
    if a.action_type == ACTION_GUARD {
      return a.target
    }
  }
  None
}

fn public_death_action(true_cause: ActionType) -> ActionType {
  if true_cause == ACTION_BITE || true_cause == ACTION_LOVERS_SUICIDE || true_cause == ACTION_HAMSTER_CURSE {
    ACTION_UNKNOWN
  } else {
    true_cause
  }
}

pub fn process_day(village: Village, actions: Array[Action]) -> (Village, DayResult) {
  let next_day_number = current_day(village) + 1
  let mut logs: Array[Log] = []

  // deaths for this day (true causes)
  let mut death_ids: Array[CreatureId] = []
  let mut death_causes: Array[ActionType] = []

  fn add_death(id: CreatureId, cause: ActionType) -> Unit {
    if not(contains_id(death_ids, id)) {
      death_ids = [..death_ids, id]
      death_causes = [..death_causes, cause]
    }
  }

  // Night actions
  let guarded = guarded_target(actions)

  // divine
  for a in actions {
    if a.action_type == ACTION_DIVINE {
      let rt = role_of(village, a.actor)
      match rt {
        Some(seer_role) => {
          if seer_role == ROLE_SEER {
            match a.target {
              Some(t) => {
                let target_role = role_of(village, t)
                match target_role {
                  Some(tr) => {
                    logs = [..logs, { receivers: Receivers::Only([a.actor]), action_type: ACTION_DIVINE, actor: Some(a.actor), target: Some(t), result: Some(tr) }]
                    if tr == ROLE_HAMSTER {
                      add_death(t, ACTION_HAMSTER_CURSE)
                    }
                  }
                  None => ()
                }
              }
              None => ()
            }
          }
        }
        None => ()
      }
    }
  }

  // guard log (private)
  for a in actions {
    if a.action_type == ACTION_GUARD {
      logs = [..logs, { receivers: Receivers::Only([a.actor]), action_type: ACTION_GUARD, actor: Some(a.actor), target: a.target, result: Some("guarded") }]
    }
  }

  // love log (private to both)
  for a in actions {
    if a.action_type == ACTION_LOVE {
      match a.target {
        Some(t) => logs = [..logs, { receivers: Receivers::Only([a.actor, t]), action_type: ACTION_LOVE, actor: Some(a.actor), target: Some(t), result: Some("partnered") }]
        None => ()
      }
    }
  }

  // fake love: target receives a love log but no partnership is formed
  for a in actions {
    if a.action_type == ACTION_FAKE_LOVE {
      let rt = role_of(village, a.actor)
      match rt {
        Some(r) => {
          if r == ROLE_BITCH {
            match a.target {
              Some(t) => logs = [..logs, { receivers: Receivers::Only([t]), action_type: ACTION_LOVE, actor: Some(a.actor), target: Some(t), result: Some("partnered") }]
              None => ()
            }
          }
        }
        None => ()
      }
    }
  }

  // bite (death handled here)
  for a in actions {
    if a.action_type == ACTION_BITE {
      match a.target {
        Some(t) => {
          if guarded == Some(t) {
            logs = [..logs, { receivers: Receivers::Only([a.actor]), action_type: ACTION_BITE, actor: Some(a.actor), target: Some(t), result: Some("guarded") }]
          } else {
            // Only the wolf gets the action result.
            logs = [..logs, { receivers: Receivers::Only([a.actor]), action_type: ACTION_BITE, actor: Some(a.actor), target: Some(t), result: Some("dead") }]
            add_death(t, ACTION_BITE)
          }
        }
        None => ()
      }
    }
  }

  // vote (day >= 2)
  if next_day_number >= 2 {
    let voted = compute_vote_death(actions)
    match voted {
      Some(t) => add_death(t, ACTION_VOTE)
      None => ()
    }
  }

  // medium: reveal whether executed by vote was a wolf
  if next_day_number >= 2 {
    let voted = compute_vote_death(actions)
    match voted {
      Some(exe) => {
        let exe_role = role_of(village, exe)
        let mut is_wolf = false
        match exe_role {
          Some(rt) => {
            if team_of(rt) == "wolves" {
              is_wolf = true
            }
          }
          None => ()
        }
        for c in village.creatures {
          if c.role.role_type == ROLE_MEDIUM {
            if is_alive(village, c.id) && not(contains_id(death_ids, c.id)) {
              let res = if is_wolf { "wolf" } else { "not_wolf" }
              logs = [..logs, { receivers: Receivers::Only([c.id]), action_type: ACTION_MEDIUM, actor: Some(c.id), target: Some(exe), result: Some(res) }]
            }
          }
        }
      }
      None => ()
    }
  }

  let mut i = 0
  while i < death_ids.length() {
    let dead = death_ids[i]
    let partner = partner_of(village, logs, dead)
    match partner {
      Some(p) => {
        if is_alive(village, p) && not(contains_id(death_ids, p)) {
          add_death(p, ACTION_LOVERS_SUICIDE)
        }
      }
      None => ()
    }
    i = i + 1
  }

  // publish deaths (in-game vs afterall)
  let mut deaths: Array[DeathRecord] = []
  let mut idx = 0
  while idx < death_ids.length() {
    let id = death_ids[idx]
    let cause = death_causes[idx]
    let pub_action = public_death_action(cause)
    // in-game visible log
    logs = [..logs, { receivers: Receivers::All, action_type: pub_action, actor: None, target: Some(id), result: Some("dead") }]
    // after game disclosure
    logs = [..logs, { receivers: Receivers::Afterall, action_type: cause, actor: None, target: Some(id), result: Some("dead") }]
    deaths = [..deaths, { creature_id: id, reason: cause }]
    idx = idx + 1
  }

  let day: Day = { day_number: next_day_number, actions, logs }
  let days: Array[Day] = [..village.days, day]
  let new_village: Village = { rule: village.rule, creatures: village.creatures, days }

  let today = build_today(new_village)
  let result: DayResult = { today, logs: day.logs, deaths }
  (new_village, result)
}
