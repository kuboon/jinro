///|
fn contains_id(ids : Array[CreatureId], id : CreatureId) -> Bool {
  for x in ids {
    if x == id {
      return true
    }
  }
  false
}

///|
fn partner_in_logs(logs : Array[Log], id : CreatureId) -> CreatureId? {
  for l in logs {
    let partnered = match l.log_result {
      Some(LogResult::Partnered) => true
      _ => false
    }
    if l.action_type == ActionType::LOVE && partnered {
      match (l.actor, l.target) {
        (Some(a), Some(t)) => {
          // Partnership is only formed if this love log is shared to both sides.
          // This allows fake love to show a "love" log to the target without forming a partnership.
          match l.receivers {
            Receivers::Only(rs) =>
              if not(contains_id(rs, a) && contains_id(rs, t)) {
                continue
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

///|
fn partner_of(
  village : Village,
  day_logs : Array[Log],
  id : CreatureId,
) -> CreatureId? {
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

///|
fn build_today(village : Village) -> Today raise DataError {
  let village_state = VillageState::new(village)
  let day_number = village.days.length()
  let mut creature_statuses : Array[CreatureStatus] = []
  for c in village.creatures {
    let id = c.id
    let creature_state = village_state.creature_statuses.get(id).unwrap()
    let role_type = c.role.role_type
    let alive = creature_state.is_alive()
    let actions = creature_state.available_actions()
    let cod = if alive { None } else { Some(creature_state.cause_of_death()) }
    let status : CreatureStatus = {
      id,
      role_type,
      team: creature_state.actor.team(),
      available_actions: actions,
      cause_of_death: cod,
    }
    creature_statuses = [..creature_statuses, status]
  }
  { day_number, winner: village_state.winner(), creature_statuses }
}

///|
pub fn create_village(
  roles : Array[Role],
  rule : Rule,
) -> Result[(Village, Today), DataError] {
  Ok(create_village_inner(roles, rule)) catch {
    DataError(s) => Err(DataError(s))
  }
}

///|
fn create_village_inner(
  roles : Array[Role],
  rule : Rule,
) -> (Village, Today) raise DataError {
  let mut creatures : Array[Creature] = []
  let mut idx = 0
  for role in roles {
    let id : CreatureId = "c" + (idx + 1).to_string()
    creatures = [..creatures, { id, role }]
    idx = idx + 1
  }
  let village : Village = { rule, creatures, days: [] }
  (village, build_today(village))
}

///|
fn compute_vote_death(actions : Array[Action]) -> CreatureId? {
  let votes : Map[CreatureId, Int] = Map::new()
  for a in actions {
    if a.action_type == ActionType::VOTE {
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

  let mut best : CreatureId? = None
  let mut tie = false
  for k, v in votes {
    if v == max {
      match best {
        None => best = Some(k)
        Some(_) => tie = true
      }
    }
  }
  if tie {
    None
  } else {
    best
  }
}

///|
fn guarded_target(actions : Array[Action]) -> CreatureId? {
  for a in actions {
    if a.action_type == ActionType::GUARD {
      return a.target
    }
  }
  None
}

///|
fn public_death_action(true_cause : ActionType) -> ActionType {
  if true_cause == ActionType::BITE ||
    true_cause == ActionType::LOVERS_SUICIDE ||
    true_cause == ActionType::HAMSTER_CURSE {
    ActionType::UNKNOWN
  } else {
    true_cause
  }
}

///|
pub fn process_day(
  village : Village,
  actions : Array[Action],
) -> Result[(DayResult, Village, Today), DataError] {
  Ok(process_day_inner(village, actions)) catch {
    DataError(s) => Err(DataError(s))
  }
}

///|
fn process_day_inner(
  village : Village,
  actions : Array[Action],
) -> (DayResult, Village, Today) raise DataError {
  let village_state = VillageState::new(village)
  let next_day_number = village.days.length() + 1
  let mut logs : Array[Log] = []

  // deaths for this day (true causes)
  let mut death_ids : Array[CreatureId] = []
  let mut death_causes : Array[ActionType] = []

  fn add_death(id : CreatureId, cause : ActionType) -> Unit {
    if not(contains_id(death_ids, id)) {
      death_ids = [..death_ids, id]
      death_causes = [..death_causes, cause]
    }
  }

  fn apply_role_effect(effect : RoleEffectResult) -> Unit {
    for log in effect.logs {
      logs = [..logs, log]
    }
    for death in effect.deaths {
      add_death(death.creature_id, death.cause)
    }
  }

  let guarded = guarded_target(actions)
  for a in actions {
    let creature_state = village_state.creature_statuses.get(a.actor).unwrap()
    apply_role_effect(creature_state.actor.resolve_action(village, a, guarded))
  }

  let voted = if next_day_number >= 1 {
    compute_vote_death(actions)
  } else {
    None
  }
  match voted {
    Some(t) => add_death(t, ActionType::VOTE)
    None => ()
  }

  // medium: reveal whether executed by vote was a wolf
  match voted {
    Some(exe) =>
      for c in village.creatures {
        if is_alive(village, c.id) && not(contains_id(death_ids, c.id)) {
          let actor = role_actor_from_type(c.role.role_type)
          apply_role_effect(actor.on_executed(village, c.id, exe))
        }
      }
    None => ()
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
  let mut deaths : Array[DeathRecord] = []
  let mut idx = 0
  while idx < death_ids.length() {
    let id = death_ids[idx]
    let cause = death_causes[idx]
    let pub_action = public_death_action(cause)
    logs = [
      ..logs,
      {
        receivers: Receivers::All,
        action_type: pub_action,
        actor: None,
        target: Some(id),
        log_result: Some(LogResult::Dead),
      },
    ]
    logs = [
      ..logs,
      {
        receivers: Receivers::Afterall,
        action_type: cause,
        actor: None,
        target: Some(id),
        log_result: Some(LogResult::Dead),
      },
    ]
    deaths = [..deaths, { creature_id: id, reason: cause }]
    idx = idx + 1
  }

  let day : Day = { day_number: next_day_number, actions, logs }
  let days : Array[Day] = [..village.days, day]
  let new_village : Village = {
    rule: village.rule,
    creatures: village.creatures,
    days,
  }

  let today = build_today(new_village)
  let result : DayResult = {
    voted: voted.unwrap_or(""),
    deads: deaths.map(fn(d) { d.creature_id }),
    logs: day.logs,
  }
  (result, new_village, today)
}
