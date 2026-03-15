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
// JSON helpers
// ---------------------------------------------------------------------------

fn opt_str(j: Json, key: String) -> String? {
  match j {
    Json::Object(obj) =>
      match obj[key] {
        Some(Json::String(s)) => Some(s)
        _ => None
      }
    _ => None
  }
}

fn req_str(j: Json, key: String) -> String {
  opt_str(j, key).unwrap_or("")
}

fn get_obj(j: Json, key: String) -> Json {
  match j {
    Json::Object(obj) =>
      match obj[key] {
        Some(v) => v
        None => Json::Null
      }
    _ => Json::Null
  }
}

fn get_arr(j: Json, key: String) -> Array[Json] {
  match j {
    Json::Object(obj) =>
      match obj[key] {
        Some(Json::Array(arr)) => arr
        _ => []
      }
    _ => []
  }
}

fn json_opt_str(s: String?) -> Json {
  match s {
    Some(v) => Json::String(v)
    None => Json::Null
  }
}

fn parse_rule(j: Json) -> Rule {
  { vote: req_str(j, "vote") }
}

fn parse_role(j: Json) -> Role {
  let role_type = req_str(j, "role_type")
  let mut metadata: Map[String, String] = Map::new()
  match j {
    Json::Object(obj) =>
      match obj["metadata"] {
        Some(Json::Object(meta)) => {
          for k, v in meta {
            match v {
              Json::String(s) => metadata[k] = s
              _ => ()
            }
          }
        }
        _ => ()
      }
    _ => ()
  }
  { role_type, metadata }
}

fn parse_creature(j: Json) -> Creature {
  let id = req_str(j, "id")
  let role = parse_role(get_obj(j, "role"))
  { id, role }
}

fn parse_action(j: Json) -> Action {
  let actor = req_str(j, "actor")
  let action_type = req_str(j, "action_type")
  let target = opt_str(j, "target")
  { actor, action_type, target }
}

fn parse_log(j: Json) -> Log {
  let action_type = req_str(j, "action_type")
  let actor = opt_str(j, "actor")
  let target = opt_str(j, "target")
  let result = opt_str(j, "result")
  let receivers: Receivers = match j {
    Json::Object(obj) =>
      match obj["receivers"] {
        Some(Json::String(s)) =>
          if s == "all" {
            Receivers::All
          } else {
            Receivers::Afterall
          }
        Some(Json::Array(arr)) => {
          let ids: Array[CreatureId] = []
          for item in arr {
            match item {
              Json::String(s) => ids.push(s)
              _ => ()
            }
          }
          Receivers::Only(ids)
        }
        _ => Receivers::All
      }
    _ => Receivers::All
  }
  { receivers, action_type, actor, target, result }
}

fn parse_day(j: Json) -> Day {
  let day_number = match j {
    Json::Object(obj) =>
      match obj["day_number"] {
        Some(Json::Number(n)) => n.to_int()
        _ => 0
      }
    _ => 0
  }
  let actions = get_arr(j, "actions").map(parse_action)
  let logs = get_arr(j, "logs").map(parse_log)
  { day_number, actions, logs }
}

fn parse_village(j: Json) -> Village {
  let rule = parse_rule(get_obj(j, "rule"))
  let creatures = get_arr(j, "creatures").map(parse_creature)
  let days = get_arr(j, "days").map(parse_day)
  { rule, creatures, days }
}

fn serialize_rule(r: Rule) -> Json {
  let obj: Map[String, Json] = Map::new()
  obj["vote"] = Json::String(r.vote)
  Json::Object(obj)
}

fn serialize_role(r: Role) -> Json {
  let meta: Map[String, Json] = Map::new()
  for k, v in r.metadata {
    meta[k] = Json::String(v)
  }
  let obj: Map[String, Json] = Map::new()
  obj["role_type"] = Json::String(r.role_type)
  obj["metadata"] = Json::Object(meta)
  Json::Object(obj)
}

fn serialize_creature(c: Creature) -> Json {
  let obj: Map[String, Json] = Map::new()
  obj["id"] = Json::String(c.id)
  obj["role"] = serialize_role(c.role)
  Json::Object(obj)
}

fn serialize_action(a: Action) -> Json {
  let obj: Map[String, Json] = Map::new()
  obj["actor"] = Json::String(a.actor)
  obj["action_type"] = Json::String(a.action_type)
  obj["target"] = json_opt_str(a.target)
  Json::Object(obj)
}

fn serialize_receivers(r: Receivers) -> Json {
  match r {
    Receivers::All => Json::String("all")
    Receivers::Afterall => Json::String("afterall")
    Receivers::Only(ids) => Json::Array(ids.map(fn(id) { Json::String(id) }))
  }
}

fn serialize_log(l: Log) -> Json {
  let obj: Map[String, Json] = Map::new()
  obj["receivers"] = serialize_receivers(l.receivers)
  obj["action_type"] = Json::String(l.action_type)
  obj["actor"] = json_opt_str(l.actor)
  obj["target"] = json_opt_str(l.target)
  obj["result"] = json_opt_str(l.result)
  Json::Object(obj)
}

fn serialize_day(d: Day) -> Json {
  let obj: Map[String, Json] = Map::new()
  obj["day_number"] = Json::Number(d.day_number.to_double())
  obj["actions"] = Json::Array(d.actions.map(serialize_action))
  obj["logs"] = Json::Array(d.logs.map(serialize_log))
  Json::Object(obj)
}

fn serialize_village(v: Village) -> Json {
  let obj: Map[String, Json] = Map::new()
  obj["rule"] = serialize_rule(v.rule)
  obj["creatures"] = Json::Array(v.creatures.map(serialize_creature))
  obj["days"] = Json::Array(v.days.map(serialize_day))
  Json::Object(obj)
}

fn serialize_available_action(a: AvailableAction) -> Json {
  let obj: Map[String, Json] = Map::new()
  obj["action_type"] = Json::String(a.action_type)
  obj["targets"] = Json::Array(a.targets.map(fn(id) { Json::String(id) }))
  Json::Object(obj)
}

fn serialize_creature_status(s: CreatureStatus) -> Json {
  let obj: Map[String, Json] = Map::new()
  obj["id"] = Json::String(s.id)
  obj["role_type"] = Json::String(s.role_type)
  obj["team"] = Json::String(s.team)
  obj["status"] = Json::String(s.status)
  obj["available_actions"] = Json::Array(s.available_actions.map(serialize_available_action))
  obj["cause_of_death"] = json_opt_str(s.cause_of_death)
  Json::Object(obj)
}

fn serialize_today(t: Today) -> Json {
  let obj: Map[String, Json] = Map::new()
  obj["day_number"] = Json::Number(t.day_number.to_double())
  obj["alive_creatures"] = Json::Array(t.alive_creatures.map(serialize_creature_status))
  obj["all_creatures"] = Json::Array(t.all_creatures.map(serialize_creature_status))
  obj["game_result"] = json_opt_str(t.game_result)
  Json::Object(obj)
}

fn serialize_death_record(d: DeathRecord) -> Json {
  let obj: Map[String, Json] = Map::new()
  obj["creature_id"] = Json::String(d.creature_id)
  obj["reason"] = Json::String(d.reason)
  Json::Object(obj)
}

fn serialize_day_result(r: DayResult) -> Json {
  let obj: Map[String, Json] = Map::new()
  obj["today"] = serialize_today(r.today)
  obj["logs"] = Json::Array(r.logs.map(serialize_log))
  obj["deaths"] = Json::Array(r.deaths.map(serialize_death_record))
  Json::Object(obj)
}

// ---------------------------------------------------------------------------
// JSON-based WASM exports
// These functions accept and return JSON strings, matching the WIT interface
// defined in wit/world.wit.
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

