// WASM entry point (non-JSON for now).
// JSON serialization will be added later.

pub fn wasm_create_village(creatures: Array[Creature], rule: Rule) -> (Village, Today) {
  create_village(creatures, rule)
}

pub fn wasm_process_day(village: Village, actions: Array[Action]) -> (Village, DayResult) {
  process_day(village, actions)
}

pub fn wasm_get_available_actions(village: Village, creature_id: CreatureId) -> Array[AvailableAction] {
  get_available_actions(village, creature_id)
}
