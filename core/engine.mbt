// Jinro core engine (stateless)

fn current_day(village: Village) -> Int {
  village.days.length()
}

fn team_of(role_type: RoleType) -> Team {
  role_team_of(role_type)
}

fn role_of(village: Village, id: CreatureId) -> RoleType? {
  for c in village.creatures {
    if c.id == id {
      return Some(c.role.role_type)
    }
  }
  None
}

fn role_actor_of(village: Village, id: CreatureId) -> RoleActorEnum? {
  match role_of(village, id) {
    None => None
    Some(role_type) => Some(role_actor_from_type(role_type))
  }
}

fn is_dead_by_logs(village: Village, id: CreatureId) -> Bool {
  for d in village.days {
    for l in d.logs {
      // Death should be determined by the in-game visible logs.
      match l.receivers {
        Receivers::All => {
          match (l.target, l.result) {
            (Some(t), Some(LogResult::Dead)) => {
              if t == id {
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
      if t != Team::Wolves {
        ids = [..ids, c.id]
      }
    }
  }
  ids
}

fn cause_of_death_from_action(action_type: ActionType) -> CauseOfDeath {
  if action_type == ActionType::Vote {
    CauseOfDeath::Executed
  } else {
    CauseOfDeath::FoundDead
  }
}

fn cause_of_death(village: Village, id: CreatureId) -> CauseOfDeath? {
  for d in village.days {
    for l in d.logs {
      // In-game cause should not reveal hidden reasons.
      match l.receivers {
        Receivers::All => {
          match (l.target, l.result) {
            (Some(t), Some(LogResult::Dead)) => {
              if t == id {
                return Some(cause_of_death_from_action(l.action_type))
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
    let partnered = match l.result {
      Some(LogResult::Partnered) => true
      _ => false
    }
    if l.action_type == ActionType::Love && partnered {
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

pub fn get_available_actions(village: Village, creature_id: CreatureId) -> Array[AvailableAction] {
  if not(is_alive(village, creature_id)) {
    return []
  }
  let day_number = current_day(village)
  match role_actor_of(village, creature_id) {
    None => []
    Some(actor) => actor.available_actions(village, creature_id, day_number)
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
      base = Some(Team::Lovers)
    }
  }

  let mut wolves = 0
  let mut villagers = 0
  let mut lovers = 0
  for c in village.creatures {
    if is_alive(village, c.id) {
      match team_of(c.role.role_type) {
        Team::Wolves => wolves = wolves + 1
        Team::Lovers => lovers = lovers + 1
        _ => villagers = villagers + 1
      }
    }
  }
  if base is None {
    if wolves == 0 {
      base = Some(Team::Villagers)
    } else if wolves >= villagers {
      base = Some(Team::Wolves)
    }
  }

  match base {
    Some(_) => {
      for c in village.creatures {
        let actor = role_actor_from_type(c.role.role_type)
        match actor.override_winner(village, c.id, base) {
          Some(team) => return Some(team)
          None => ()
        }
      }
      base
    }
    None => None
  }
}

fn build_status(village: Village, id: CreatureId) -> CreatureStatus {
  let mut role_type: RoleType = RoleType::Villager
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
  let mut creature_statuses: Array[CreatureStatus] = []
  for c in village.creatures {
    let st = build_status(village, c.id)
    creature_statuses = [..creature_statuses, st]
  }
  {
    day_number,
    winner: winner(village),
    creature_statuses,
  }
}

pub fn create_village(roles: Array[Role], rule: Rule) -> (Village, Today) {
  let mut creatures: Array[Creature] = []
  let mut idx = 0
  for role in roles {
    let id: CreatureId = "c" + (idx + 1).to_string()
    creatures = [..creatures, { id, role }]
    idx = idx + 1
  }
  let village: Village = { rule, creatures, days: [] }
  (village, build_today(village))
}

fn compute_vote_death(actions: Array[Action]) -> CreatureId? {
  let votes: Map[CreatureId, Int] = Map::new()
  for a in actions {
    if a.action_type == ActionType::Vote {
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
    if a.action_type == ActionType::Guard {
      return a.target
    }
  }
  None
}

fn public_death_action(true_cause: ActionType) -> ActionType {
  if true_cause == ActionType::Bite || true_cause == ActionType::LoversSuicide || true_cause == ActionType::HamsterCurse {
    ActionType::Unknown
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

  fn apply_role_effect(effect: RoleEffectResult) -> Unit {
    for log in effect.logs {
      logs = [..logs, log]
    }
    for death in effect.deaths {
      add_death(death.creature_id, death.cause)
    }
  }

  // Night actions
  let guarded = guarded_target(actions)

  for a in actions {
    match role_actor_of(village, a.actor) {
      Some(actor) => apply_role_effect(actor.resolve_action(village, a, guarded))
      None => ()
    }
  }

  // vote (day >= 1)
  if next_day_number >= 1 {
    let voted = compute_vote_death(actions)
    match voted {
      Some(t) => add_death(t, ActionType::Vote)
      None => ()
    }
  }

  // medium: reveal whether executed by vote was a wolf
  if next_day_number >= 1 {
    let voted = compute_vote_death(actions)
    match voted {
      Some(exe) => {
        for c in village.creatures {
          if is_alive(village, c.id) && not(contains_id(death_ids, c.id)) {
            let actor = role_actor_from_type(c.role.role_type)
            apply_role_effect(actor.on_executed(village, c.id, exe))
          }
        }
      }
      None => ()
    }
  }

  let mut i = 0
  while i < death_ids.length() {
    let dead = death_ids[i]
    for c in village.creatures {
      if is_alive(village, c.id) && not(contains_id(death_ids, c.id)) {
        let actor = role_actor_from_type(c.role.role_type)
        apply_role_effect(actor.on_death(village, logs, c.id, dead))
      }
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
    logs = [..logs, { receivers: Receivers::All, action_type: pub_action, actor: None, target: Some(id), result: Some(LogResult::Dead) }]
    // after game disclosure
    logs = [..logs, { receivers: Receivers::Afterall, action_type: cause, actor: None, target: Some(id), result: Some(LogResult::Dead) }]
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
