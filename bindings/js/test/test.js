/**
 * Simple test for the Jinro engine JavaScript bindings.
 *
 * Run via:  npm test  (from bindings/js/)
 * This builds the WASM component from src/impl.js and runs the tests against
 * the generated JS bindings.
 */

import { createVillage, processDay, getAvailableActions } from '../gen/jinro.component.js';

let passed = 0;
let failed = 0;
const failedTests = [];
let currentTest = '';

function assert(condition, message) {
  if (condition) {
    console.log(`  ✓ ${message}`);
    passed++;
  } else {
    console.error(`  ✗ ${message}`);
    failed++;
    failedTests.push(`${currentTest}: ${message}`);
  }
}

function test(name, fn) {
  currentTest = name;
  console.log(`\n[test] ${name}`);
  fn();
}

// ---------------------------------------------------------------------------
// Test: create_village
// ---------------------------------------------------------------------------
test('create-village initialises state', () => {
  const creaturesJson = JSON.stringify([
    { id: 'p1', role: { role_type: 'villager', metadata: {} } },
    { id: 'p2', role: { role_type: 'wolf', metadata: {} } },
    { id: 'p3', role: { role_type: 'seer', metadata: {} } },
  ]);
  const ruleJson = JSON.stringify({ vote: 'public' });

  const out = JSON.parse(createVillage(creaturesJson, ruleJson));
  assert(out.village.creatures.length === 3, 'village has 3 creatures');
  assert(out.today.day_number === 0, 'initial day_number is 0');
  assert(out.today.game_result === null, 'no winner yet');
});

// ---------------------------------------------------------------------------
// Test: process_day – wolf bites villager
// ---------------------------------------------------------------------------
test('wolf bites villager → villager dies', () => {
  const creaturesJson = JSON.stringify([
    { id: 'w', role: { role_type: 'wolf', metadata: {} } },
    { id: 'v', role: { role_type: 'villager', metadata: {} } },
  ]);
  const ruleJson = JSON.stringify({ vote: 'public' });

  const { village } = JSON.parse(createVillage(creaturesJson, ruleJson));
  const actionsJson = JSON.stringify([
    { actor: 'w', action_type: 'bite', target: 'v' },
  ]);

  const out = JSON.parse(processDay(JSON.stringify(village), actionsJson));
  assert(out.result.deaths.length === 1, 'one death');
  assert(out.result.deaths[0].creature_id === 'v', 'villager died');
  assert(out.result.deaths[0].reason === 'bite', 'cause is bite');
});

// ---------------------------------------------------------------------------
// Test: process_day – guard saves villager
// ---------------------------------------------------------------------------
test('bodyguard protects target → no death', () => {
  const creaturesJson = JSON.stringify([
    { id: 'w', role: { role_type: 'wolf', metadata: {} } },
    { id: 'g', role: { role_type: 'bodyguard', metadata: {} } },
    { id: 'v', role: { role_type: 'villager', metadata: {} } },
  ]);
  const ruleJson = JSON.stringify({ vote: 'public' });

  const { village } = JSON.parse(createVillage(creaturesJson, ruleJson));
  const actionsJson = JSON.stringify([
    { actor: 'g', action_type: 'guard', target: 'v' },
    { actor: 'w', action_type: 'bite', target: 'v' },
  ]);

  const out = JSON.parse(processDay(JSON.stringify(village), actionsJson));
  assert(out.result.deaths.length === 0, 'no deaths (guard saved v)');
});

// ---------------------------------------------------------------------------
// Test: process_day – vote kills
// ---------------------------------------------------------------------------
test('majority vote kills target', () => {
  const creaturesJson = JSON.stringify([
    { id: 'p1', role: { role_type: 'villager', metadata: {} } },
    { id: 'p2', role: { role_type: 'villager', metadata: {} } },
    { id: 'p3', role: { role_type: 'wolf', metadata: {} } },
  ]);
  const ruleJson = JSON.stringify({ vote: 'public' });

  let { village } = JSON.parse(createVillage(creaturesJson, ruleJson));
  // Advance to day 1 (no actions)
  ({ village } = JSON.parse(processDay(JSON.stringify(village), JSON.stringify([]))));
  // Day 2 – vote
  const actionsJson = JSON.stringify([
    { actor: 'p1', action_type: 'vote', target: 'p3' },
    { actor: 'p2', action_type: 'vote', target: 'p3' },
    { actor: 'p3', action_type: 'vote', target: 'p1' },
  ]);

  const out = JSON.parse(processDay(JSON.stringify(village), actionsJson));
  assert(out.result.deaths.length === 1, 'one death');
  assert(out.result.deaths[0].creature_id === 'p3', 'wolf was voted out');
  assert(out.result.today.game_result === 'villagers', 'villagers win');
});

// ---------------------------------------------------------------------------
// Test: get_available_actions
// ---------------------------------------------------------------------------
test('seer can divine on day 1', () => {
  const creaturesJson = JSON.stringify([
    { id: 's', role: { role_type: 'seer', metadata: {} } },
    { id: 'v', role: { role_type: 'villager', metadata: {} } },
  ]);
  const ruleJson = JSON.stringify({ vote: 'public' });

  // Advance to day 1
  let { village } = JSON.parse(createVillage(creaturesJson, ruleJson));
  ({ village } = JSON.parse(processDay(JSON.stringify(village), JSON.stringify([]))));

  const actions = JSON.parse(getAvailableActions(JSON.stringify(village), 's'));
  const hasDivine = actions.some(a => a.action_type === 'divine');
  assert(hasDivine, 'seer has divine action on day 1');
});

// ---------------------------------------------------------------------------
// Summary
// ---------------------------------------------------------------------------
console.log(`\n${passed + failed} tests: ${passed} passed, ${failed} failed`);
if (failed > 0) {
  console.error('\nFailed assertions:');
  for (const msg of failedTests) console.error(`  - ${msg}`);
  process.exit(1);
}
