// Jinro Engine Tests - Blackbox tests

test {
  // Simple test - verify basic arithmetic
  let x = 1 + 1
  if not(x == 2) { panic() }
}

test {
  // Test create_village
  let creatures: Array[@jinro.Creature] = [
    { id: "player1", role: { role_type: "villager", metadata: Map::new() } },
    { id: "player2", role: { role_type: "wolf", metadata: Map::new() } },
    { id: "player3", role: { role_type: "seer", metadata: Map::new() } },
  ]
  let rule: @jinro.Rule = { vote: "public" }
  let (village, today) = @jinro.create_village(creatures, rule)
  
  if not(village.creatures.length() == 3) { panic() }
  if not(today.day_number == 0) { panic() }
}

test {
  // Vote kills on day 2+
  let creatures: Array[@jinro.Creature] = [
    { id: "p1", role: { role_type: "villager", metadata: Map::new() } },
    { id: "p2", role: { role_type: "villager", metadata: Map::new() } },
    { id: "p3", role: { role_type: "villager", metadata: Map::new() } },
  ]
  let (v0, _t0) = @jinro.create_village(creatures, ({ vote: "public" } : @jinro.Rule))
  let (v1, _r1) = @jinro.process_day(v0, []) // advance to day 1
  let actions: Array[@jinro.Action] = [
    { actor: "p1", action_type: "vote", target: Some("p2") },
    { actor: "p2", action_type: "vote", target: Some("p2") },
    { actor: "p3", action_type: "vote", target: Some("p2") },
  ]
  let (_v2, r2) = @jinro.process_day(v1, actions)
  if not(r2.deaths.length() == 1) { panic() }
  if not(r2.deaths[0].creature_id == "p2") { panic() }
  if not(r2.deaths[0].reason == "vote") { panic() }
}

test {
  // Bite kills if not guarded
  let creatures: Array[@jinro.Creature] = [
    { id: "w", role: { role_type: "wolf", metadata: Map::new() } },
    { id: "v", role: { role_type: "villager", metadata: Map::new() } },
  ]
  let (v0, _t0) = @jinro.create_village(creatures, ({ vote: "public" } : @jinro.Rule))
  let (_v1, r1) = @jinro.process_day(v0, ([
    { actor: "w", action_type: "bite", target: Some("v") },
  ] : Array[@jinro.Action]))
  if not(r1.deaths.length() == 1) { panic() }
  if not(r1.deaths[0].creature_id == "v") { panic() }
  if not(r1.deaths[0].reason == "bite") { panic() }
}

test {
  // Guard prevents bite
  let creatures: Array[@jinro.Creature] = [
    { id: "w", role: { role_type: "wolf", metadata: Map::new() } },
    { id: "g", role: { role_type: "bodyguard", metadata: Map::new() } },
    { id: "v", role: { role_type: "villager", metadata: Map::new() } },
  ]
  let (v0, _t0) = @jinro.create_village(creatures, ({ vote: "public" } : @jinro.Rule))
  let (_v1, r1) = @jinro.process_day(v0, ([
    { actor: "g", action_type: "guard", target: Some("v") },
    { actor: "w", action_type: "bite", target: Some("v") },
  ] : Array[@jinro.Action]))
  if not(r1.deaths.length() == 0) { panic() }
}
