// Jinro Engine Tests - Blackbox tests

fn mk_role(role_type: @jinro.RoleType) -> @jinro.Role {
  { role_type, metadata: Map::new() }
}

fn id_at(village: @jinro.Village, idx: Int) -> String {
  village.creatures[idx].id
}

test {
  // Test create_village assigns ids internally
  let roles: Array[@jinro.Role] = [
    mk_role(@jinro.RoleType::Villager),
    mk_role(@jinro.RoleType::Wolf),
    mk_role(@jinro.RoleType::Seer),
  ]
  let rule: @jinro.Rule = { vote: "public" }
  let (village, today) = @jinro.create_village(roles, rule)

  if not(village.creatures.length() == 3) { panic() }
  if not(today.day_number == 0) { panic() }
  if not(village.creatures[0].id != village.creatures[1].id) { panic() }
}

test {
  // Seer can divine from day 0
  let roles: Array[@jinro.Role] = [
    mk_role(@jinro.RoleType::Seer),
    mk_role(@jinro.RoleType::Villager),
  ]
  let (v0, _t0) = @jinro.create_village(roles, ({ vote: "public" } : @jinro.Rule))
  let s = id_at(v0, 0)
  let acts = @jinro.get_available_actions(v0, s)
  let mut has_divine = false
  for a in acts {
    match a.action_type {
      @jinro.ActionType::Divine => has_divine = true
      _ => ()
    }
  }
  if not(has_divine) { panic() }
}

test {
  // Villager can vote from day 1
  let roles: Array[@jinro.Role] = [
    mk_role(@jinro.RoleType::Villager),
    mk_role(@jinro.RoleType::Villager),
  ]
  let (v0, _t0) = @jinro.create_village(roles, ({ vote: "public" } : @jinro.Rule))
  let (v1, _r1) = @jinro.process_day(v0, [])
  let p1 = id_at(v1, 0)
  let acts = @jinro.get_available_actions(v1, p1)
  let mut has_vote = false
  for a in acts {
    match a.action_type {
      @jinro.ActionType::Vote => has_vote = true
      _ => ()
    }
  }
  if not(has_vote) { panic() }
}

test {
  // Madman is on wolves team
  let roles: Array[@jinro.Role] = [
    mk_role(@jinro.RoleType::Madman),
    mk_role(@jinro.RoleType::Villager),
  ]
  let (v0, t0) = @jinro.create_village(roles, ({ vote: "public" } : @jinro.Rule))
  let m = id_at(v0, 0)

  let mut m_team: String? = None
  for s in t0.creature_statuses {
    if s.id == m {
      m_team = Some(s.team)
    }
  }

  if not(m_team == Some("wolves")) { panic() }
}

test {
  // Vote kills once voting phase is available
  let roles: Array[@jinro.Role] = [
    mk_role(@jinro.RoleType::Villager),
    mk_role(@jinro.RoleType::Villager),
    mk_role(@jinro.RoleType::Villager),
  ]
  let (v0, _t0) = @jinro.create_village(roles, ({ vote: "public" } : @jinro.Rule))
  let (v1, _r1) = @jinro.process_day(v0, []) // advance to day 1
  let p1 = id_at(v1, 0)
  let p2 = id_at(v1, 1)
  let p3 = id_at(v1, 2)
  let actions: Array[@jinro.Action] = [
    { actor: p1, action_type: @jinro.ActionType::Vote, target: Some(p2) },
    { actor: p2, action_type: @jinro.ActionType::Vote, target: Some(p2) },
    { actor: p3, action_type: @jinro.ActionType::Vote, target: Some(p2) },
  ]
  let (_v2, r2) = @jinro.process_day(v1, actions)
  if not(r2.deaths.length() == 1) { panic() }
  if not(r2.deaths[0].creature_id == p2) { panic() }
  if not(r2.deaths[0].reason == "vote") { panic() }

  let mut executed_ok = false
  for s in r2.today.creature_statuses {
    if s.id == p2 {
      match s.cause_of_death {
        Some(@jinro.CauseOfDeath::Executed) => executed_ok = true
        _ => ()
      }
    }
  }
  if not(executed_ok) { panic() }
}

test {
  // Medium can see if the executed person was a wolf
  let roles: Array[@jinro.Role] = [
    mk_role(@jinro.RoleType::Medium),
    mk_role(@jinro.RoleType::Wolf),
    mk_role(@jinro.RoleType::Villager),
  ]
  let (v0, _t0) = @jinro.create_village(roles, ({ vote: "public" } : @jinro.Rule))
  let (v1, _r1) = @jinro.process_day(v0, []) // advance to day 1
  let m = id_at(v1, 0)
  let w = id_at(v1, 1)
  let v = id_at(v1, 2)
  let (_v2, r2) = @jinro.process_day(v1, ([
    { actor: m, action_type: @jinro.ActionType::Vote, target: Some(w) },
    { actor: v, action_type: @jinro.ActionType::Vote, target: Some(w) },
    { actor: w, action_type: @jinro.ActionType::Vote, target: Some(v) },
  ] : Array[@jinro.Action]))

  let mut ok = false
  for l in r2.logs {
    match l.action_type {
      @jinro.ActionType::Medium => {
        if l.actor == Some(m) && l.target == Some(w) && l.result == Some("wolf") {
          ok = true
        }
      }
      _ => ()
    }
  }
  if not(ok) { panic() }
}

test {
  // Bite kills if not guarded
  let roles: Array[@jinro.Role] = [
    mk_role(@jinro.RoleType::Wolf),
    mk_role(@jinro.RoleType::Villager),
  ]
  let (v0, _t0) = @jinro.create_village(roles, ({ vote: "public" } : @jinro.Rule))
  let w = id_at(v0, 0)
  let v = id_at(v0, 1)
  let (_v1, r1) = @jinro.process_day(v0, ([
    { actor: w, action_type: @jinro.ActionType::Bite, target: Some(v) },
  ] : Array[@jinro.Action]))
  if not(r1.deaths.length() == 1) { panic() }
  if not(r1.deaths[0].creature_id == v) { panic() }
  if not(r1.deaths[0].reason == "bite") { panic() }

  let mut found_dead_ok = false
  for s in r1.today.creature_statuses {
    if s.id == v {
      match s.cause_of_death {
        Some(@jinro.CauseOfDeath::FoundDead) => found_dead_ok = true
        _ => ()
      }
    }
  }
  if not(found_dead_ok) { panic() }
}

test {
  // Hamster dies when divined (public log looks like bite)
  let roles: Array[@jinro.Role] = [
    mk_role(@jinro.RoleType::Seer),
    mk_role(@jinro.RoleType::Hamster),
    mk_role(@jinro.RoleType::Villager),
  ]
  let (v0, _t0) = @jinro.create_village(roles, ({ vote: "public" } : @jinro.Rule))
  let s = id_at(v0, 0)
  let h = id_at(v0, 1)
  let (_v1, r1) = @jinro.process_day(v0, ([
    { actor: s, action_type: @jinro.ActionType::Divine, target: Some(h) },
  ] : Array[@jinro.Action]))

  // death record should contain true cause
  if not(r1.deaths.length() == 1) { panic() }
  if not(r1.deaths[0].creature_id == h) { panic() }
  if not(r1.deaths[0].reason == "hamster_curse") { panic() }

  // logs: in-game (All) is indistinguishable and Afterall has true cause
  let mut has_public = false
  let mut has_afterall = false
  for l in r1.logs {
    match l.receivers {
      @jinro.Receivers::All => {
        match l.action_type {
          @jinro.ActionType::Unknown => {
            if l.target == Some(h) && l.result == Some("dead") {
              has_public = true
            }
          }
          _ => ()
        }
      }
      @jinro.Receivers::Afterall => {
        match l.action_type {
          @jinro.ActionType::HamsterCurse => {
            if l.target == Some(h) && l.result == Some("dead") {
              has_afterall = true
            }
          }
          _ => ()
        }
      }
      _ => ()
    }
  }
  if not(has_public && has_afterall) { panic() }
}

test {
  // Hamster wins solo if alive at game end
  let roles: Array[@jinro.Role] = [
    mk_role(@jinro.RoleType::Hamster),
    mk_role(@jinro.RoleType::Wolf),
    mk_role(@jinro.RoleType::Villager),
  ]
  let (v0, _t0) = @jinro.create_village(roles, ({ vote: "public" } : @jinro.Rule))
  let (v1, _r1) = @jinro.process_day(v0, [])
  let h = id_at(v1, 0)
  let w = id_at(v1, 1)
  let v = id_at(v1, 2)
  let (_v2, r2) = @jinro.process_day(v1, ([
    { actor: h, action_type: @jinro.ActionType::Vote, target: Some(w) },
    { actor: v, action_type: @jinro.ActionType::Vote, target: Some(w) },
    { actor: w, action_type: @jinro.ActionType::Vote, target: Some(v) },
  ] : Array[@jinro.Action]))
  if not(r2.today.winner == Some("hamster")) { panic() }
}

test {
  // Guard prevents bite
  let roles: Array[@jinro.Role] = [
    mk_role(@jinro.RoleType::Wolf),
    mk_role(@jinro.RoleType::Bodyguard),
    mk_role(@jinro.RoleType::Villager),
  ]
  let (v0, _t0) = @jinro.create_village(roles, ({ vote: "public" } : @jinro.Rule))
  let w = id_at(v0, 0)
  let g = id_at(v0, 1)
  let v = id_at(v0, 2)
  let (_v1, r1) = @jinro.process_day(v0, ([
    { actor: g, action_type: @jinro.ActionType::Guard, target: Some(v) },
    { actor: w, action_type: @jinro.ActionType::Bite, target: Some(v) },
  ] : Array[@jinro.Action]))
  if not(r1.deaths.length() == 0) { panic() }
}

test {
  // Bitch can do love and fake_love on day 1
  let roles: Array[@jinro.Role] = [
    mk_role(@jinro.RoleType::Bitch),
    mk_role(@jinro.RoleType::Villager),
  ]
  let (v0, _t0) = @jinro.create_village(roles, ({ vote: "public" } : @jinro.Rule))
  let (v1, _r1) = @jinro.process_day(v0, [])
  let b = id_at(v1, 0)
  let acts = @jinro.get_available_actions(v1, b)
  let mut has_love = false
  let mut has_fake = false
  for a in acts {
    match a.action_type {
      @jinro.ActionType::Love => has_love = true
      @jinro.ActionType::FakeLove => has_fake = true
      _ => ()
    }
  }
  if not(has_love && has_fake) { panic() }
}

test {
  // fake_love shows love log to target but does not form partnership
  let roles: Array[@jinro.Role] = [
    mk_role(@jinro.RoleType::Bitch),
    mk_role(@jinro.RoleType::Villager),
    mk_role(@jinro.RoleType::Wolf),
  ]
  let (v0, _t0) = @jinro.create_village(roles, ({ vote: "public" } : @jinro.Rule))
  let b = id_at(v0, 0)
  let p = id_at(v0, 1)
  let w = id_at(v0, 2)
  let (_v1, r1) = @jinro.process_day(v0, ([
    { actor: b, action_type: @jinro.ActionType::FakeLove, target: Some(p) },
    { actor: w, action_type: @jinro.ActionType::Bite, target: Some(p) },
  ] : Array[@jinro.Action]))
  if not(r1.deaths.length() == 1) { panic() }
  if not(r1.deaths[0].creature_id == p) { panic() }
}

test {
  // Bitch love is real love and can lead to lovers win
  let roles: Array[@jinro.Role] = [
    mk_role(@jinro.RoleType::Bitch),
    mk_role(@jinro.RoleType::Villager),
    mk_role(@jinro.RoleType::Wolf),
  ]
  let (v0, _t0) = @jinro.create_village(roles, ({ vote: "public" } : @jinro.Rule))
  let b = id_at(v0, 0)
  let p = id_at(v0, 1)
  let w = id_at(v0, 2)
  let (v1, _r1) = @jinro.process_day(v0, ([
    { actor: b, action_type: @jinro.ActionType::Love, target: Some(p) },
  ] : Array[@jinro.Action]))
  let (_v2, r2) = @jinro.process_day(v1, ([
    { actor: b, action_type: @jinro.ActionType::Vote, target: Some(w) },
    { actor: p, action_type: @jinro.ActionType::Vote, target: Some(w) },
  ] : Array[@jinro.Action]))
  if not(r2.today.winner == Some("lovers")) { panic() }
}

test {
  // Lover commits suicide when partner dies
  let roles: Array[@jinro.Role] = [
    mk_role(@jinro.RoleType::Lover),
    mk_role(@jinro.RoleType::Villager),
    mk_role(@jinro.RoleType::Wolf),
  ]
  let (v0, _t0) = @jinro.create_village(roles, ({ vote: "public" } : @jinro.Rule))
  let l = id_at(v0, 0)
  let p = id_at(v0, 1)
  let w = id_at(v0, 2)
  let (_v1, r1) = @jinro.process_day(v0, ([
    { actor: l, action_type: @jinro.ActionType::Love, target: Some(p) },
    { actor: w, action_type: @jinro.ActionType::Bite, target: Some(p) },
  ] : Array[@jinro.Action]))

  if not(r1.deaths.length() == 2) { panic() }

  fn find_reason(deaths: Array[@jinro.DeathRecord], id: String) -> String? {
    for d in deaths {
      if d.creature_id == id {
        return Some(d.reason)
      }
    }
    None
  }

  if not(find_reason(r1.deaths, p) == Some("bite")) { panic() }
  if not(find_reason(r1.deaths, l) == Some("lovers_suicide")) { panic() }
}

test {
  // Lovers win when last two survivors are partnered
  let roles: Array[@jinro.Role] = [
    mk_role(@jinro.RoleType::Lover),
    mk_role(@jinro.RoleType::Villager),
    mk_role(@jinro.RoleType::Wolf),
  ]
  let (v0, _t0) = @jinro.create_village(roles, ({ vote: "public" } : @jinro.Rule))
  let l = id_at(v0, 0)
  let p = id_at(v0, 1)
  let w = id_at(v0, 2)
  let (v1, _r1) = @jinro.process_day(v0, ([
    { actor: l, action_type: @jinro.ActionType::Love, target: Some(p) },
  ] : Array[@jinro.Action]))

  let (_v2, r2) = @jinro.process_day(v1, ([
    { actor: l, action_type: @jinro.ActionType::Vote, target: Some(w) },
    { actor: p, action_type: @jinro.ActionType::Vote, target: Some(w) },
  ] : Array[@jinro.Action]))

  if not(r2.today.winner == Some("lovers")) { panic() }
}