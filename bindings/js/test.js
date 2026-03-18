import { engine } from './jinro_component.js';
const { createVillage } = engine;

const roles = [
  { roleType: "villager", opts: [] },
  { roleType: "wolf", opts: [] },
  { roleType: "seer", opts: [] }
];

const rule = { vote: { tag: "public" } };

try {
  console.log("Creating village...");
  const [village, today] = createVillage(roles, rule);
  console.log("Created village with day number:", today.dayNumber);
  console.log("Creatures:", village.creatures.length);
  console.log("Test passed!");
} catch (e) {
  console.error("Error creating village:", e);
}
