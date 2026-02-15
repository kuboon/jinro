// Jinro Engine Tests

@test
fn test_create_village() = {
  let creatures = [
    { id: "player1", role: { role_type: "villager", metadata: Map::new() } },
    { id: "player2", role: { role_type: "wolf", metadata: Map::new() } },
    { id: "player3", role: { role_type: "seer", metadata: Map::new() } },
  ]
  let rule = { vote: "public" }
  let (village, today) = create_village(creatures, rule)
  
  @assert.assert_true(village.creatures.length() == 3)
  @assert.assert_true(today.day_number == 0)
  @assert.assert_true(today.alive_creatures.length() == 3)
  @assert.assert_true(today.game_result.is_none())
}

@test
fn test_vote_kills() = {
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
  
  @assert.assert_true(result.deaths.length() == 1)
  @assert.equal(result.deaths[0].creature_id, "player2")
  @assert.equal(result.deaths[0].reason, "voted")
}

@test
fn test_wolf_bite_kills() = {
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
  
  @assert.assert_true(result.deaths.length() == 1)
  @assert.equal(result.deaths[0].creature_id, "player2")
  @assert.equal(result.deaths[0].reason, "bite")
}

@test
fn test_wolf_bite_guarded() = {
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
  
  @assert.assert_true(result.deaths.length() == 0)
}

@test
fn test_seer_divine() = {
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
  
  @assert.assert_true(result.logs.length() > 0)
  let divine_log = result.logs[0]
  @assert.equal(divine_log.action_type, "divine")
  @assert.equal(divine_log.result, Some("wolf"))
}

@test
fn test_game_end_wolves_win() = {
  let creatures = [
    { id: "wolf1", role: { role_type: "wolf", metadata: Map::new() } },
    { id: "villager1", role: { role_type: "villager", metadata: Map::new() } },
  ]
  let rule = { vote: "public" }
  let (village, _today) = create_village(creatures, rule)
  
  let actions = [
    { actor: "wolf1", action_type: "bite", target: Some("villager1") },
    { actor: "villager1", action_type: "vote", target: Some("wolf1") },
  ]
  
  let (village2, result) = process_day(village, actions)
  
  @assert.assert_true(result.today.game_result == Some("wolves"))
}

@test
fn test_game_end_villagers_win() = {
  let creatures = [
    { id: "wolf1", role: { role_type: "wolf", metadata: Map::new() } },
    { id: "villager1", role: { role_type: "villager", metadata: Map::new() } },
    { id: "villager2", role: { role_type: "villager", metadata: Map::new() } },
  ]
  let rule = { vote: "public" }
  let (village, _today) = create_village(creatures, rule)
  
  // Wolf votes for villager1, villagers vote for wolf
  let actions = [
    { actor: "wolf1", action_type: "vote", target: Some("villager1") },
    { actor: "villager1", action_type: "vote", target: Some("wolf1") },
    { actor: "villager2", action_type: "vote", target: Some("wolf1") },
  ]
  
  let (village2, result) = process_day(village, actions)
  
  @assert.assert_true(result.today.game_result == Some("villagers"))
}

@test
fn test_get_available_actions() = {
  let creatures = [
    { id: "player1", role: { role_type: "seer", metadata: Map::new() } },
    { id: "player2", role: { role_type: "villager", metadata: Map::new() } },
  ]
  let rule = { vote: "public" }
  let (village, _today) = create_village(creatures, rule)
  
  // On day 0, no actions available
  let actions_day0 = get_available_actions(village, "player1")
  @assert.assert_true(actions_day0.length() == 0)
  
  // Process day 1 (seer can divine)
  let (village2, _result) = process_day(village, [])
  
  let actions_day1 = get_available_actions(village2, "player1")
  @assert.assert_true(actions_day1.length() > 0)
  @assert.assert_true(actions_day1[0].action_type == "divine")
}
