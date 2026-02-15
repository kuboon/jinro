// Jinro Engine - Core game logic

import "types"
import "role/mod"

// Get creature by ID
fn get_creature(village: Village, id: CreatureId) -> Option[Creature] {
  village.creatures |> Array::find(fn(c) { c.id == id })
}

// Get current day number
fn get_current_day(village: Village) -> Int {
  village.days.length()
}

// Check if creature is alive
fn is_alive(village: Village, id: CreatureId) -> Bool {
  // Check if died in any previous day
  for day in village.days {
    for log in day.logs {
      match log.target {
        Some(target) =>
          if target == id && log.result == Some("dead") {
            return false
          }
        _ => ()
      }
    }
  }
  true
}

// Get cause of death
fn get_cause_of_death(village: Village, id: CreatureId) -> Option[String] {
  for day in village.days {
    for log in day.logs {
      match log.target {
        Some(target) =>
          if target == id {
            match log.result {
              Some("dead") => return Some(log.action_type)
              _ => ()
            }
          }
        _ => ()
      }
    }
  }
  None
}

// Get death reason from vote
fn get_vote_death_reason(village: Village, id: CreatureId) -> Option[String] {
  for day in village.days {
    for log in day.logs {
      match log.target {
        Some(target) =>
          if target == id && log.action_type == "vote" && log.result == Some("dead") {
            return Some("voted")
          }
        _ => ()
      }
    }
  }
  None
}

// Get alive creatures
fn get_alive_creatures(village: Village) -> Array[Creature] {
  village.creatures |> Array::filter(fn(c) { is_alive(village, c.id) })
}

// Get dead creatures
fn get_dead_creatures(village: Village) -> Array[Creature] {
  village.creatures |> Array::filter(fn(c) { not(is_alive(village, c.id)) })
}

// Count teams among alive creatures
fn count_teams(village: Village) -> (Int, Int, Int) {
  let alive = get_alive_creatures(village)
  let mut wolves = 0
  let mut villagers = 0
  let mut lovers = 0
  for c in alive {
    let team = role.get_team(c.role.role_type)
    match team {
      "wolves" => wolves = wolves + 1
      "lovers" => lovers = lovers + 1
      _ => villagers = villagers + 1
    }
  }
  (wolves, villagers, lovers)
}

// Check if game is over and return winner
fn check_game_end(village: Village) -> Option[Team] {
  let (wolves, villagers, lovers) = count_teams(village)
  let alive_total = wolves + villagers + lovers
  
  if alive_total == 0 {
    return Some("villagers") // Draw, but technically no one wins
  }
  
  // Wolves win if they equal or outnumber villagers
  if wolves >= villagers && wolves > 0 {
    return Some("wolves")
  }
  
  // Villagers win if no wolves left
  if wolves == 0 {
    return Some("villagers")
  }
  
  // Lovers win if only lovers remain
  if villagers == 0 && wolves == 0 && lovers > 0 {
    return Some("lovers")
  }
  
  None
}

// Get available actions for a creature on current day
pub fn get_available_actions(village: Village, creature_id: CreatureId) -> Array[AvailableAction] {
  let day_number = get_current_day(village)
  
  // Check if creature exists
  match get_creature(village, creature_id) {
    None => []
    Some(creature) => {
      // Check if alive
      if not(is_alive(village, creature_id)) {
        return []
      }
      
      // Get valid action types for this role on this day
      let valid_actions = role.get_valid_actions(creature.role.role_type, day_number)
      
      // Build available actions
      let mut available = []
      for action_type in valid_actions {
        let targets = if action_type == "vote" {
          // Vote can target any alive creature (excluding self)
          get_alive_creatures(village)
          |> Array::filter(fn(c) { c.id != creature_id })
          |> Array::map(fn(c) { c.id })
        } else if action_type == "bite" {
          // Wolf can bite any alive non-wolf
          get_alive_creatures(village)
          |> Array::filter(fn(c) {
            let team = role.get_team(c.role.role_type)
            team != "wolves"
          })
          |> Array::map(fn(c) { c.id })
        } else if action_type == "guard" {
          // Bodyguard can guard any alive creature
          get_alive_creatures(village)
          |> Array::map(fn(c) { c.id })
        } else if action_type == "divine" {
          // Seer can divine any alive creature
          get_alive_creatures(village)
          |> Array::map(fn(c) { c.id })
        } else if action_type == "love" {
          // Lover can choose any alive creature (excluding self)
          get_alive_creatures(village)
          |> Array::filter(fn(c) { c.id != creature_id })
          |> Array::map(fn(c) { c.id })
        } else {
          []
        }
        available = [{ action_type, targets }, ..available]
      }
      available
    }
  }
}

// Build creature status
fn build_creature_status(village: Village, creature: Creature) -> CreatureStatus {
  let team = role.get_team(creature.role.role_type)
  let alive = is_alive(village, creature.id)
  let status = if alive { "alive" } else { "dead" }
  
  let cause = if not(alive) {
    get_cause_of_death(village, creature.id)
  } else {
    None
  }
  
  let available_actions = if alive {
    get_available_actions(village, creature.id)
  } else {
    []
  }
  
  {
    id: creature.id,
    role_type: creature.role.role_type,
    team,
    status,
    available_actions,
    cause_of_death: cause,
  }
}

// Build today's info
fn build_today(village: Village) -> Today {
  let day_number = get_current_day(village)
  let alive_creatures = get_alive_creatures(village)
    |> Array::map(fn(c) { build_creature_status(village, c) })
  let all_creatures = village.creatures
    |> Array::map(fn(c) { build_creature_status(village, c) })
  let game_result = check_game_end(village)
  
  { day_number, alive_creatures, all_creatures, game_result }
}

// Create initial village
pub fn create_village(creatures: Array[Creature], rule: Rule) -> (Village, Today) {
  let village: Village = {
    rule,
    creatures,
    days: [],
  }
  let today = build_today(village)
  (village, today)
}

// Process vote and return death record if any
fn process_vote(village: Village, actions: Array[Action]) -> (Array[Log], Array[DeathRecord]) {
  let day_number = get_current_day(village)
  if day_number < 1 {
    return ([], [])
  }
  
  // Get all vote actions
  let votes = actions |> Array::filter(fn(a) { a.action_type == "vote" })
  
  if votes.length() == 0 {
    return ([], [])
  }
  
  // Count votes for each target
  let mut vote_counts: Map[CreatureId, Int] = Map::new()
  for vote in votes {
    match vote.target {
      Some(target) => {
        let count = vote_counts.get(target).unwrap_or(0)
        vote_counts.set(target, count + 1)
      }
      None => ()
    }
  }
  
  // Find max votes
  let mut max_votes = 0
  for _, count in vote_counts {
    if count > max_votes {
      max_votes = count
    }
  }
  
  // Find all with max votes
  let mut to_die = []
  for target, count in vote_counts {
    if count == max_votes && max_votes > 0 {
      to_die = [target, ..to_die]
    }
  }
  
  // If tie, no one dies (or implement tie-breaker logic)
  if to_die.length() > 1 {
    return ([], [])
  }
  
  // Create death records and logs
  let mut logs = []
  let mut deaths = []
  for target in to_die {
    let log: Log = {
      receivers: "all",
      action_type: "vote",
      actor: None,
      target: Some(target),
      result: Some("dead"),
    }
    let death: DeathRecord = {
      creature_id: target,
      reason: "voted",
    }
    logs = [log, ..logs]
    deaths = [death, ..deaths]
  }
  
  (logs, deaths)
}

// Process a day with actions
pub fn process_day(village: Village, actions: Array[Action]) -> (Village, DayResult) {
  let day_number = get_current_day(village)
  let day_number = day_number + 1 // Increment to next day
  
  // Process role-specific actions (night actions)
  let mut all_logs: Array[Log] = []
  let mut deaths: Array[DeathRecord] = []
  
  // Execute role-specific actions
  for action in actions {
    let creature = get_creature(village, action.actor)
    match creature {
      Some(c) => {
        if is_alive(village, action.actor) {
          let mod = role.get_role_module(c.role.role_type)
          let action_logs = mod.actions(action, village, actions)
          all_logs = all_logs + action_logs
        }
      }
      None => ()
    }
  }
  
  // Process deaths from night actions (bite)
  let mut bite_deaths: Array[DeathRecord] = []
  for log in all_logs {
    match (log.action_type, log.target, log.result) {
      ("bite", Some(target), Some("dead")) => {
        bite_deaths = [{ creature_id: target, reason: "bite" }, ..bite_deaths]
      }
      _ => ()
    }
  }
  
  // Process vote
  let (vote_logs, vote_deaths) = process_vote(village, actions)
  all_logs = all_logs + vote_logs
  deaths = deaths + vote_deaths + bite_deaths
  
  // Add death logs for bite deaths
  for death in bite_deaths {
    let log: Log = {
      receivers: "all",
      action_type: "bite",
      actor: None,
      target: Some(death.creature_id),
      result: Some("dead"),
    }
    all_logs = [log, ..all_logs]
  }
  
  // Add new day to village
  let new_day: Day = {
    day_number,
    actions,
    logs: all_logs,
  }
  
  let new_village: Village = {
    rule: village.rule,
    creatures: village.creatures,
    days: village.days + [new_day],
  }
  
  let today = build_today(new_village)
  
  let result: DayResult = {
    today,
    logs: all_logs,
    deaths,
  }
  
  (new_village, result)
}
