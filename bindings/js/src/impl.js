/**
 * Jinro (Werewolf) core logic implemented in JavaScript.
 * This module is used by `jco componentize` to produce a WASM component
 * implementing the WIT interface defined in `wit/world.wit`.
 *
 * The MoonBit source in `core/` is the canonical implementation; this file
 * mirrors that logic so that JS consumers can test the full pipeline locally
 * without building the MoonBit WASM.
 */

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function teamOf(roleType) {
  if (roleType === 'wolf') return 'wolves';
  if (roleType === 'lover') return 'lovers';
  return 'villagers';
}

function isDeadByLogs(village, id) {
  for (const day of village.days) {
    for (const log of day.logs) {
      if (log.receivers === 'all') {
        if (log.target === id && log.result === 'dead') {
          return true;
        }
      }
    }
  }
  return false;
}

function isAlive(village, id) {
  return !isDeadByLogs(village, id);
}

function aliveIds(village) {
  return village.creatures.filter(c => isAlive(village, c.id)).map(c => c.id);
}

function aliveIdsExcept(village, me) {
  return aliveIds(village).filter(id => id !== me);
}

function aliveNonWolfIds(village) {
  return village.creatures
    .filter(c => isAlive(village, c.id) && teamOf(c.role.role_type) !== 'wolves')
    .map(c => c.id);
}

function roleOf(village, id) {
  const c = village.creatures.find(c => c.id === id);
  return c ? c.role.role_type : null;
}

function causeOfDeath(village, id) {
  for (const day of village.days) {
    for (const log of day.logs) {
      if (log.receivers === 'all' && log.target === id && log.result === 'dead') {
        return log.action_type;
      }
    }
  }
  return null;
}

function partnerInLogs(logs, id) {
  for (const log of logs) {
    if (log.action_type === 'love' && log.result === 'partnered') {
      const { actor, target } = log;
      if (!Array.isArray(log.receivers)) continue;
      if (!(log.receivers.includes(actor) && log.receivers.includes(target))) continue;
      if (actor === id) return target;
      if (target === id) return actor;
    }
  }
  return null;
}

function partnerOf(village, dayLogs, id) {
  const p = partnerInLogs(dayLogs, id);
  if (p !== null) return p;
  for (const day of village.days) {
    const q = partnerInLogs(day.logs, id);
    if (q !== null) return q;
  }
  return null;
}

function isHamsterAlive(village) {
  return village.creatures.some(c => c.role.role_type === 'hamster' && isAlive(village, c.id));
}

function winner(village) {
  const alive = aliveIds(village);

  // Lovers win if the last two survivors are partnered.
  if (alive.length === 2) {
    const [a, b] = alive;
    if (partnerOf(village, [], a) === b && partnerOf(village, [], b) === a) {
      if (isHamsterAlive(village)) return 'hamster';
      return 'lovers';
    }
  }

  let wolves = 0;
  let villagers = 0;
  for (const c of village.creatures) {
    if (isAlive(village, c.id)) {
      const t = teamOf(c.role.role_type);
      if (t === 'wolves') wolves++;
      else villagers++;
    }
  }

  let base = null;
  if (wolves === 0) base = 'villagers';
  else if (wolves >= villagers) base = 'wolves';

  if (base !== null && isHamsterAlive(village)) return 'hamster';
  return base;
}

function buildStatus(village, id) {
  const creature = village.creatures.find(c => c.id === id);
  const role_type = creature ? creature.role.role_type : 'villager';
  const team = teamOf(role_type);
  const alive = isAlive(village, id);
  const status = alive ? 'alive' : 'dead';
  const available_actions = alive ? getAvailableActionsInternal(village, id) : [];
  const cause_of_death = alive ? null : causeOfDeath(village, id);
  return { id, role_type, team, status, available_actions, cause_of_death };
}

function buildToday(village) {
  const day_number = village.days.length;
  const all_creatures = village.creatures.map(c => buildStatus(village, c.id));
  const alive_creatures = all_creatures.filter(s => s.status === 'alive');
  const game_result = winner(village);
  return { day_number, alive_creatures, all_creatures, game_result };
}

function canDoAction(roleType, actionType, dayNumber) {
  switch (roleType) {
    case 'villager': return actionType === 'vote' && dayNumber >= 2;
    case 'seer':
      return (actionType === 'divine' && dayNumber === 1) ||
             (actionType === 'vote' && dayNumber >= 2);
    case 'bodyguard':
      return (actionType === 'guard' && dayNumber >= 1) ||
             (actionType === 'vote' && dayNumber >= 2);
    case 'wolf':
      return (actionType === 'bite' && dayNumber >= 1) ||
             (actionType === 'vote' && dayNumber >= 2);
    case 'lover':
      return (actionType === 'love' && dayNumber === 1) ||
             (actionType === 'vote' && dayNumber >= 2);
    case 'bitch':
      return ((actionType === 'love' || actionType === 'fake_love') && dayNumber === 1) ||
             (actionType === 'vote' && dayNumber >= 2);
    case 'medium': return actionType === 'vote' && dayNumber >= 2;
    case 'hamster': return actionType === 'vote' && dayNumber >= 2;
    default: return false;
  }
}

function getAvailableActionsInternal(village, creatureId) {
  if (!isAlive(village, creatureId)) return [];
  const dayNumber = village.days.length;
  const role_type = roleOf(village, creatureId);
  if (!role_type) return [];

  const out = [];
  if (canDoAction(role_type, 'vote', dayNumber))
    out.push({ action_type: 'vote', targets: aliveIdsExcept(village, creatureId) });
  if (canDoAction(role_type, 'divine', dayNumber))
    out.push({ action_type: 'divine', targets: aliveIdsExcept(village, creatureId) });
  if (canDoAction(role_type, 'guard', dayNumber))
    out.push({ action_type: 'guard', targets: aliveIds(village) });
  if (canDoAction(role_type, 'bite', dayNumber))
    out.push({ action_type: 'bite', targets: aliveNonWolfIds(village) });
  if (canDoAction(role_type, 'love', dayNumber))
    out.push({ action_type: 'love', targets: aliveIdsExcept(village, creatureId) });
  if (canDoAction(role_type, 'fake_love', dayNumber))
    out.push({ action_type: 'fake_love', targets: aliveIdsExcept(village, creatureId) });
  return out;
}

function computeVoteDeath(actions) {
  const votes = {};
  for (const a of actions) {
    if (a.action_type === 'vote' && a.target !== null) {
      votes[a.target] = (votes[a.target] || 0) + 1;
    }
  }
  const max = Math.max(0, ...Object.values(votes));
  if (max === 0) return null;
  const leaders = Object.keys(votes).filter(k => votes[k] === max);
  return leaders.length === 1 ? leaders[0] : null;
}

function guardedTarget(actions) {
  const a = actions.find(a => a.action_type === 'guard');
  return a ? a.target : null;
}

function publicDeathAction(trueCause) {
  return ['bite', 'lovers_suicide', 'hamster_curse'].includes(trueCause) ? 'unknown' : trueCause;
}

function processDayInternal(village, actions) {
  const nextDayNumber = village.days.length + 1;
  const logs = [];
  const deathIds = [];
  const deathCauses = [];

  function addDeath(id, cause) {
    if (!deathIds.includes(id)) {
      deathIds.push(id);
      deathCauses.push(cause);
    }
  }

  const guarded = guardedTarget(actions);

  // divine
  for (const a of actions) {
    if (a.action_type === 'divine') {
      if (roleOf(village, a.actor) === 'seer' && a.target !== null) {
        const tr = roleOf(village, a.target);
        if (tr) {
          logs.push({ receivers: [a.actor], action_type: 'divine', actor: a.actor, target: a.target, result: tr });
          if (tr === 'hamster') addDeath(a.target, 'hamster_curse');
        }
      }
    }
  }

  // guard log (private)
  for (const a of actions) {
    if (a.action_type === 'guard') {
      logs.push({ receivers: [a.actor], action_type: 'guard', actor: a.actor, target: a.target, result: 'guarded' });
    }
  }

  // love (real partnership)
  for (const a of actions) {
    if (a.action_type === 'love' && a.target !== null) {
      logs.push({ receivers: [a.actor, a.target], action_type: 'love', actor: a.actor, target: a.target, result: 'partnered' });
    }
  }

  // fake love: target receives a love log but no partnership is formed
  for (const a of actions) {
    if (a.action_type === 'fake_love' && roleOf(village, a.actor) === 'bitch' && a.target !== null) {
      logs.push({ receivers: [a.target], action_type: 'love', actor: a.actor, target: a.target, result: 'partnered' });
    }
  }

  // bite
  for (const a of actions) {
    if (a.action_type === 'bite' && a.target !== null) {
      if (guarded !== null && guarded === a.target) {
        logs.push({ receivers: [a.actor], action_type: 'bite', actor: a.actor, target: a.target, result: 'guarded' });
      } else {
        logs.push({ receivers: [a.actor], action_type: 'bite', actor: a.actor, target: a.target, result: 'dead' });
        addDeath(a.target, 'bite');
      }
    }
  }

  // vote (day >= 2)
  if (nextDayNumber >= 2) {
    const voted = computeVoteDeath(actions);
    if (voted) addDeath(voted, 'vote');
  }

  // medium reveal
  if (nextDayNumber >= 2) {
    const voted = computeVoteDeath(actions);
    if (voted) {
      const exeRole = roleOf(village, voted);
      const isWolf = exeRole ? teamOf(exeRole) === 'wolves' : false;
      for (const c of village.creatures) {
        if (c.role.role_type === 'medium' && isAlive(village, c.id) && !deathIds.includes(c.id)) {
          logs.push({ receivers: [c.id], action_type: 'medium', actor: c.id, target: voted, result: isWolf ? 'wolf' : 'not_wolf' });
        }
      }
    }
  }

  // lovers suicide propagation
  let i = 0;
  while (i < deathIds.length) {
    const dead = deathIds[i];
    const partner = partnerOf(village, logs, dead);
    if (partner && isAlive(village, partner) && !deathIds.includes(partner)) {
      addDeath(partner, 'lovers_suicide');
    }
    i++;
  }

  // publish deaths
  const deaths = [];
  for (let idx = 0; idx < deathIds.length; idx++) {
    const id = deathIds[idx];
    const cause = deathCauses[idx];
    const pubAction = publicDeathAction(cause);
    logs.push({ receivers: 'all', action_type: pubAction, actor: null, target: id, result: 'dead' });
    logs.push({ receivers: 'afterall', action_type: cause, actor: null, target: id, result: 'dead' });
    deaths.push({ creature_id: id, reason: cause });
  }

  const day = { day_number: nextDayNumber, actions, logs };
  const newVillage = { rule: village.rule, creatures: village.creatures, days: [...village.days, day] };
  const today = buildToday(newVillage);
  const result = { today, logs: day.logs, deaths };
  return { village: newVillage, result };
}

// ---------------------------------------------------------------------------
// WIT exports (named in camelCase matching jco conventions)
// ---------------------------------------------------------------------------

export function createVillage(creaturesJson, ruleJson) {
  const creatures = JSON.parse(creaturesJson);
  const rule = JSON.parse(ruleJson);
  const village = { rule, creatures, days: [] };
  const today = buildToday(village);
  return JSON.stringify({ village, today });
}

export function processDay(villageJson, actionsJson) {
  const village = JSON.parse(villageJson);
  const actions = JSON.parse(actionsJson);
  const output = processDayInternal(village, actions);
  return JSON.stringify(output);
}

export function getAvailableActions(villageJson, creatureId) {
  const village = JSON.parse(villageJson);
  return JSON.stringify(getAvailableActionsInternal(village, creatureId));
}
