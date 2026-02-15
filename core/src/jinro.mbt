// Jinro Engine Tests

test {
  // test_create_village
  let creatures = [
    { id: "player1", role: { role_type: "villager", metadata: Map::new() } },
    { id: "player2", role: { role_type: "wolf", metadata: Map::new() } },
    { id: "player3", role: { role_type: "seer", metadata: Map::new() } },
  ]
  let rule = { vote: "public" }
  let (village, today) = create_village(creatures, rule)
  
  if not(village.creatures.length() == 3) { panic() }
  if not(today.day_number == 0) { panic() }
  if not(today.alive_creatures.length() == 3) { panic() }
  if not(today.game_result.is_none()) { panic() }
}

test {
  // test_vote_kills
  let creatures = [
    { id: "player1", role: { role_type: "villager", metadata: Map::new() } },
    { id: "player2", role: { role_type: "villager", metadata: Map::new() } },
    { id: "player3", role: { role_type: "villager", metadata: Map::new() } },
  ]
  let rule = { vote: "public" }
  let (village, _today) = create_village(creatures, rule)
  
  let actions = [
    { actor: "player1", action_type: "vote", target: Some("player2") },
    { actor: "player2", action_type: "vote", target: Some("player2") },
    { actor: "player3", action_type: "vote", target: Some("player2") },
  ]
  
  let (village2, result) = process_day(village, actions)
  
  if not(result.deaths.length() == 1) { panic() }
  if not(result.deaths[0].creature_id == "player2") { panic() }
  if not(result.deaths[0].reason == "voted") { panic() }
}

test {
  // test_wolf_bite_kills
  let creatures = [
    { id: "player1", role: { role_type: "wolf", metadata: Map::new() } },
    { id: "player2", role: { role_type: "villager", metadata: Map::new() } },
  ]
  let rule = { vote: "public" }
  let (village, _today) = create_village(creatures, rule)
  
  let actions = [
    { actor: "player1", action_type: "bite", target: Some("player2") },
  ]
  
  let (village2, result) = process_day(village, actions)
  
  if not(result.deaths.length() == 1) { panic() }
  if not(result.deaths[0].creature_id == "player2") { panic() }
  if not(result.deaths[0].reason == "bite") { panic() }
}

test {
  // test_wolf_bite_guarded
  let creatures = [
    { id: "wolf1", role: { role_type: "wolf", metadata: Map::new() } },
    { id: "villager1", role: { role_type: "villager", metadata: Map::new() } },
    { id: "bodyguard1", role: { role_type: "bodyguard", metadata: Map::new() } },
  ]
  let rule = { vote: "public" }
  let (village, _today) = create_village(creatures, rule)
  
  let actions = [
    { actor: "wolf1", action_type: "bite", target: Some("villager1") },
    { actor: "bodyguard1", action_type: "guard", target: Some("villager1") },
  ]
  
  let (village2, result) = process_day(village, actions)
  
  if not(result.deaths.length() == 0) { panic() }
}

test {
  // test_seer_divine
  let creatures = [
    { id: "seer1", role: { role_type: "seer", metadata: Map::new() } },
    { id: "wolf1", role: { role_type: "wolf", metadata: Map::new() } },
  ]
  let rule = { vote: "public" }
  let (village, _today) = create_village(creatures, rule)
  
  let actions = [
    { actor: "seer1", action_type: "divine", target: Some("wolf1") },
  ]
  
  let (village2, result) = process_day(village, actions)
  
  if not(result.logs.length() > 0) { panic() }
  let divine_log = result.logs[0]
  if not(divine_log.action_type == "divine") { panic() }
  if not(divine_log.result == Some("wolf")) { panic() }
}

test {
  // test_game_end_wolves_win
  let creatures = [
    { id: "wolf1", role: { role_type: "wolf", metadata: Map::new() } },
    { id: "villager1", role: { role_type: "villager", metadata: Map::new() } },
  ]
  let rule = { vote: "public" }
  let (village, _today) = create_village(creatures, rule)
  
  let actions = [
    { actor: "wolf1", action_type: "bite", target: Some("villager1") },
  ]
  
  let (village2, result) = process_day(village, actions)
  
  if not(result.today.game_result == Some("wolves")) { panic() }
}

test {
  // test_game_end_villagers_win
  let creatures = [
    { id: "wolf1", role: { role_type: "wolf", metadata: Map::new() } },
    { id: "villager1", role: { role_type: "villager", metadata: Map::new() } },
    { id: "villager2", role: { role_type: "villager", metadata: Map::new() } },
  ]
  let rule = { vote: "public" }
  let (village, _today) = create_village(creatures, rule)
  
  let actions = [
    { actor: "wolf1", action_type: "vote", target: Some("villager1") },
    { actor: "villager1", action_type: "vote", target: Some("wolf1") },
    { actor: "villager2", action_type: "vote", target: Some("wolf1") },
  ]
  
  let (village2, result) = process_day(village, actions)
  
  if not(result.today.game_result == Some("villagers")) { panic() }
}

test {
  // test_get_available_actions_day0
  let creatures = [
    { id: "player1", role: { role_type: "seer", metadata: Map::new() } },
    { id: "player2", role: { role_type: "villager", metadata: Map::new() } },
  ]
  let rule = { vote: "public" }
  let (village, _today) = create_village(creatures, rule)
  
  let actions_day0 = get_available_actions(village, "player1")
  if not(actions_day0.length() == 0) { panic() }
}

test {
  // test_get_available_actions_day1
  let creatures = [
    { id: "player1", role: { role_type: "seer", metadata: Map::new() } },
    { id: "player2", role: { role_type: "villager", metadata: Map::new() } },
  ]
  let rule = { vote: "public" }
  let (village, _today) = create_village(creatures, rule)
  
  let (village2, _result) = process_day(village, [])
  
  let actions_day1 = get_available_actions(village2, "player1")
  if not(actions_day1.length() > 0) { panic() }
  if not(actions_day1[0].action_type == "divine") { panic() }
}
