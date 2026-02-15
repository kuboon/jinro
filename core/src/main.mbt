// Jinro WASM Main Entry Point
// Provides JSON-based interface for WASM consumption

import "types"
import "engine"

// JSON helpers - convert between JSON and types

// Parse JSON string to value
fn parse_json(_s: String) -> Result[Json, String] {
  // Placeholder - actual JSON parsing would need @moonbitlang/json
  Error("JSON parsing not implemented")
}

// Convert value to JSON string
fn to_json_string(_v: Json) -> String {
  // Placeholder - actual JSON serialization would need @moonbitlang/json
  "{}"
}

// Re-export engine functions
pub fn create_village(creatures: Array[Creature], rule: Rule) -> (Village, Today) {
  engine.create_village(creatures, rule)
}

pub fn process_day(village: Village, actions: Array[Action]) -> (Village, DayResult) {
  engine.process_day(village, actions)
}

pub fn get_available_actions(village: Village, creature_id: CreatureId) -> Array[AvailableAction] {
  engine.get_available_actions(village, creature_id)
}
