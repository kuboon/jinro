// Role module interface
type RoleModule {
  name: String
  team: Team
  choices: fn(Int, Role) -> Array[CreatureId] // day_number, role -> available targets
  actions: fn(Action, Village, Array[Action]) -> Array[Log] // action, village, all_actions -> logs
}

// Get role module by role type
pub fn get_role_module(role_type: RoleType) -> RoleModule {
  match role_type {
    "villager" => villager_mod()
    "seer" => seer_mod()
    "bodyguard" => bodyguard_mod()
    "wolf" => wolf_mod()
    "lover" => lover_mod()
    _ => villager_mod() // default to villager
  }
}

// Get team for a role
pub fn get_team(role_type: RoleType) -> Team {
  match role_type {
    "wolf" => "wolves"
    "lover" => "lovers"
    _ => "villagers"
  }
}

// Check if action is valid for role on a given day
pub fn can_do_action(role_type: RoleType, action_type: ActionType, day_number: Int) -> Bool {
  match (role_type, action_type, day_number) {
    // Villager: can vote any day >= 1
    ("villager", "vote", d) => d >= 1
    ("villager", _, _) => false

    // Seer: can divine on day 1, can vote day >= 2
    ("seer", "divine", 1) => true
    ("seer", "vote", d) => d >= 2
    ("seer", _, _) => false

    // Bodyguard: can guard any day >= 1, can vote any day >= 1
    ("bodyguard", "guard", d) => d >= 1
    ("bodyguard", "vote", d) => d >= 1
    ("bodyguard", _, _) => false

    // Wolf: can bite any day >= 1, can vote any day >= 1
    ("wolf", "bite", d) => d >= 1
    ("wolf", "vote", d) => d >= 1
    ("wolf", _, _) => false

    // Lover: can love on day 1, can vote any day >= 1
    ("lover", "love", 1) => true
    ("lover", "vote", d) => d >= 1
    ("lover", _, _) => false

    _ => false
  }
}

// Get valid action types for a role on a given day
pub fn get_valid_actions(role_type: RoleType, day_number: Int) -> Array[ActionType] {
  let mut actions = []
  if can_do_action(role_type, "vote", day_number) {
    actions = ["vote", ..actions]
  }
  if can_do_action(role_type, "bite", day_number) {
    actions = ["bite", ..actions]
  }
  if can_do_action(role_type, "guard", day_number) {
    actions = ["guard", ..actions]
  }
  if can_do_action(role_type, "divine", day_number) {
    actions = ["divine", ..actions]
  }
  if can_do_action(role_type, "love", day_number) {
    actions = ["love", ..actions]
  }
  actions
}
