///|
priv struct CreatureState {
  village : Village
  creature_id : CreatureId
  actor : &RoleActor
}

///|
fn CreatureState::new(
  village : Village,
  creature_id : CreatureId,
) -> CreatureState {
  let actor = match role_of(village, creature_id) {
    None => role_actor_from_type(RoleType::VILLAGER)
    Some(role_type) => role_actor_from_type(role_type)
  }
  { village, creature_id, actor }
}

///|
fn CreatureState::each_logs(self : Self) -> Iter[Log] {
  let days = self.village.days.iter()
  days.flat_map(fn(d) -> Iter[Log] { d.logs.iter() })
}

///|
fn CreatureState::cause_of_death(self : Self) -> CauseOfDeath raise DataError {
  for l in self.each_logs() {
    match l.receivers {
      Receivers::All =>
        match (l.target, l.log_result) {
          (Some(t), Some(LogResult::Dead)) =>
            if t == self.creature_id {
              return match l.action_type {
                ActionType::VOTE => CauseOfDeath::EXECUTED
                _ => CauseOfDeath::FOUND_DEAD
              }
            }
          _ => ()
        }
      _ => ()
    }
  }
  raise DataError("Cause of death not found")
}

///|
fn CreatureState::available_actions(self : Self) -> Array[AvailableAction] {
  let day_number = self.village.days.length()
  if self.is_alive() {
    self.actor.available_actions(self.village, self.creature_id, day_number)
  } else {
    []
  }
}

///|
fn CreatureState::is_alive(self : Self) -> Bool {
  is_alive(self.village, self.creature_id)
}

///|
priv struct VillageState {
  village : Village
  creature_statuses : Map[CreatureId, CreatureState]
}

///|
fn VillageState::new(village : Village) -> VillageState {
  let creature_statuses : Map[CreatureId, CreatureState] = Map::new()
  for c in village.creatures {
    creature_statuses.set(c.id, CreatureState::new(village, c.id))
  }
  { village, creature_statuses }
}

///|
fn role_of(village : Village, id : CreatureId) -> RoleType? {
  for c in village.creatures {
    if c.id == id {
      return Some(c.role.role_type)
    }
  }
  None
}

///|
fn is_dead_by_logs(village : Village, id : CreatureId) -> Bool {
  for d in village.days {
    for l in d.logs {
      // Death should be determined by the in-game visible logs.
      match l.receivers {
        Receivers::All =>
          match (l.target, l.log_result) {
            (Some(t), Some(LogResult::Dead)) => if t == id { return true }
            _ => ()
          }
        _ => ()
      }
    }
  }
  false
}

///|
fn is_alive(village : Village, id : CreatureId) -> Bool {
  not(is_dead_by_logs(village, id))
}

///|
fn alive_ids(village : Village) -> Array[CreatureId] {
  let mut result : Array[CreatureId] = []
  for c in village.creatures {
    if is_alive(village, c.id) {
      result = [..result, c.id]
    }
  }
  result
}

///|
fn alive_ids_except(
  village : Village,
  except : CreatureId,
) -> Array[CreatureId] {
  let mut result : Array[CreatureId] = []
  for c in village.creatures {
    if c.id != except && is_alive(village, c.id) {
      result = [..result, c.id]
    }
  }
  result
}

///|
fn alive_non_wolf_ids(village : Village) -> Array[CreatureId] {
  let mut result : Array[CreatureId] = []
  for c in village.creatures {
    if is_alive(village, c.id) &&
      role_actor_from_type(c.role.role_type).team() != Team::WOLVES {
      result = [..result, c.id]
    }
  }
  result
}

///|
fn VillageState::winner(self : Self) -> Team? {
  let village = self.village
  let mut base : Team? = None

  // Lovers win if the last two survivors are partnered.
  let alive = alive_ids(village)
  if alive.length() == 2 {
    let a = alive[0]
    let b = alive[1]
    let pa = partner_of(village, [], a)
    let pb = partner_of(village, [], b)
    if pa == Some(b) && pb == Some(a) {
      base = Some(Team::LOVERS)
    }
  }

  let mut wolves = 0
  let mut villagers = 0
  let mut _lovers = 0
  for c in village.creatures {
    let cs = self.creature_statuses.get(c.id).unwrap()
    if cs.is_alive() {
      match cs.actor.team() {
        Team::WOLVES => wolves = wolves + 1
        Team::LOVERS => _lovers = _lovers + 1
        _ => villagers = villagers + 1
      }
    }
  }
  if base is None {
    if wolves == 0 {
      base = Some(Team::VILLAGERS)
    } else if wolves >= villagers {
      base = Some(Team::WOLVES)
    }
  }

  match base {
    Some(_) => {
      for c in village.creatures {
        let cs = self.creature_statuses.get(c.id).unwrap()
        match cs.actor.override_winner(village, c.id, base) {
          Some(team) => return Some(team)
          None => ()
        }
      }
      base
    }
    None => None
  }
}
