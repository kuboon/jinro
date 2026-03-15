// WASM entry points (typed, non-JSON).
// These expose the core types directly; used internally and for testing.

pub fn wasm_create_village(creatures: Array[Creature], rule: Rule) -> (Village, Today) {
  create_village(creatures, rule)
}

pub fn wasm_process_day(village: Village, actions: Array[Action]) -> (Village, DayResult) {
  process_day(village, actions)
}

pub fn wasm_get_available_actions(village: Village, creature_id: CreatureId) -> Array[AvailableAction] {
  get_available_actions(village, creature_id)
}

// ---------------------------------------------------------------------------
// JSON-based WASM exports
// These functions accept and return JSON strings, matching the WIT interface
// defined in wit/world.wit.
// JSON helpers live in json.mbt.
// ---------------------------------------------------------------------------

fn error_json(msg: String) -> String {
  let obj: Map[String, Json] = Map::new()
  obj["error"] = Json::String(msg)
  @json.stringify(Json::Object(obj))
}

/// Creates a new village.
/// Input:  creatures_json – JSON array of Creature objects
///         rule_json      – JSON Rule object (e.g. {"vote":"public"})
/// Output: JSON object {"village": Village, "today": Today}
///         or {"error": "..."} on bad input.
pub fn create_village_json(creatures_json: String, rule_json: String) -> String {
  let creatures_j = match @json.parse?(creatures_json) {
    Ok(j) => j
    Err(e) => return error_json("invalid creatures_json: \{e}")
  }
  let rule_j = match @json.parse?(rule_json) {
    Ok(j) => j
    Err(e) => return error_json("invalid rule_json: \{e}")
  }
  let creatures: Array[Creature] = match creatures_j {
    Json::Array(arr) => arr.map(parse_creature)
    _ => return error_json("creatures_json must be an array")
  }
  let rule = parse_rule(rule_j)
  let (village, today) = create_village(creatures, rule)
  let out: Map[String, Json] = Map::new()
  out["village"] = serialize_village(village)
  out["today"] = serialize_today(today)
  @json.stringify(Json::Object(out))
}

/// Processes one day.
/// Input:  village_json – JSON Village object
///         actions_json – JSON array of Action objects
/// Output: JSON object {"village": Village, "result": DayResult}
///         or {"error": "..."} on bad input.
pub fn process_day_json(village_json: String, actions_json: String) -> String {
  let village_j = match @json.parse?(village_json) {
    Ok(j) => j
    Err(e) => return error_json("invalid village_json: \{e}")
  }
  let actions_j = match @json.parse?(actions_json) {
    Ok(j) => j
    Err(e) => return error_json("invalid actions_json: \{e}")
  }
  let village = parse_village(village_j)
  let actions: Array[Action] = match actions_j {
    Json::Array(arr) => arr.map(parse_action)
    _ => return error_json("actions_json must be an array")
  }
  let (new_village, result) = process_day(village, actions)
  let out: Map[String, Json] = Map::new()
  out["village"] = serialize_village(new_village)
  out["result"] = serialize_day_result(result)
  @json.stringify(Json::Object(out))
}

/// Returns available actions for a creature.
/// Input:  village_json – JSON Village object
///         creature_id  – creature ID string
/// Output: JSON array of AvailableAction objects
///         or {"error": "..."} on bad input.
pub fn get_available_actions_json(village_json: String, creature_id: String) -> String {
  let village_j = match @json.parse?(village_json) {
    Ok(j) => j
    Err(e) => return error_json("invalid village_json: \{e}")
  }
  let village = parse_village(village_j)
  let actions = get_available_actions(village, creature_id)
  @json.stringify(Json::Array(actions.map(serialize_available_action)))
}

