//! Thin, unverified glue between the WIT interface (string ids, records)
//! and the verified `jinro-core` (index ids). All id validation happens here,
//! so the core can assume every id is in range.

wit_bindgen::generate!({
    world: "jinro-world",
    path: "wit",
});

use exports::kuboon::jinro::engine as w;
use jinro_core as core_;

struct Component;
export!(Component);

fn err(msg: impl Into<String>) -> w::DataError {
    w::DataError::DataError(msg.into())
}

// ---- enums ---------------------------------------------------------------

fn role_in(r: w::RoleType) -> core_::RoleType {
    use core_::RoleType as C;
    use w::RoleType as W;
    match r {
        W::Villager => C::Villager,
        W::Seer => C::Seer,
        W::Bodyguard => C::Bodyguard,
        W::Wolf => C::Wolf,
        W::Madman => C::Madman,
        W::Lover => C::Lover,
        W::Bitch => C::Bitch,
        W::Medium => C::Medium,
        W::Hamster => C::Hamster,
    }
}

fn role_out(r: core_::RoleType) -> w::RoleType {
    use core_::RoleType as C;
    use w::RoleType as W;
    match r {
        C::Villager => W::Villager,
        C::Seer => W::Seer,
        C::Bodyguard => W::Bodyguard,
        C::Wolf => W::Wolf,
        C::Madman => W::Madman,
        C::Lover => W::Lover,
        C::Bitch => W::Bitch,
        C::Medium => W::Medium,
        C::Hamster => W::Hamster,
    }
}

fn team_out(t: core_::Team) -> w::Team {
    match t {
        core_::Team::Villagers => w::Team::Villagers,
        core_::Team::Wolves => w::Team::Wolves,
        core_::Team::Lovers => w::Team::Lovers,
        core_::Team::Hamsters => w::Team::Hamsters,
    }
}

fn act_in(a: w::ActionType) -> core_::ActionType {
    use core_::ActionType as C;
    use w::ActionType as W;
    match a {
        W::Vote => C::Vote,
        W::Unknown => C::Unknown,
        W::Bite => C::Bite,
        W::Divine => C::Divine,
        W::Medium => C::Medium,
        W::Guard => C::Guard,
        W::HamsterCurse => C::HamsterCurse,
        W::Love => C::Love,
        W::LoversSuicide => C::LoversSuicide,
        W::FakeLove => C::FakeLove,
    }
}

fn act_out(a: core_::ActionType) -> w::ActionType {
    use core_::ActionType as C;
    use w::ActionType as W;
    match a {
        C::Vote => W::Vote,
        C::Unknown => W::Unknown,
        C::Bite => W::Bite,
        C::Divine => W::Divine,
        C::Medium => W::Medium,
        C::Guard => W::Guard,
        C::HamsterCurse => W::HamsterCurse,
        C::Love => W::Love,
        C::LoversSuicide => W::LoversSuicide,
        C::FakeLove => W::FakeLove,
    }
}

fn result_in(r: w::LogResult) -> core_::LogResult {
    match r {
        w::LogResult::Dead => core_::LogResult::Dead,
        w::LogResult::Guarded => core_::LogResult::Guarded,
        w::LogResult::Partnered => core_::LogResult::Partnered,
        w::LogResult::Wolf => core_::LogResult::Wolf,
        w::LogResult::NonWolf => core_::LogResult::NonWolf,
    }
}

fn result_out(r: core_::LogResult) -> w::LogResult {
    match r {
        core_::LogResult::Dead => w::LogResult::Dead,
        core_::LogResult::Guarded => w::LogResult::Guarded,
        core_::LogResult::Partnered => w::LogResult::Partnered,
        core_::LogResult::Wolf => w::LogResult::Wolf,
        core_::LogResult::NonWolf => w::LogResult::NonWolf,
    }
}

fn cod_out(c: core_::CauseOfDeath) -> w::CauseOfDeath {
    match c {
        core_::CauseOfDeath::Executed => w::CauseOfDeath::Executed,
        core_::CauseOfDeath::FoundDead => w::CauseOfDeath::FoundDead,
    }
}

// ---- ids -----------------------------------------------------------------

struct Ids<'a>(&'a [w::Creature]);

impl Ids<'_> {
    fn idx(&self, id: &str) -> Result<usize, w::DataError> {
        self.0
            .iter()
            .position(|c| c.id == id)
            .ok_or_else(|| err(format!("unknown creature id: {id}")))
    }
    fn opt_idx(&self, id: &Option<String>) -> Result<Option<usize>, w::DataError> {
        id.as_deref().map(|s| self.idx(s)).transpose()
    }
    fn id(&self, i: usize) -> String {
        self.0[i].id.clone()
    }
    fn opt_id(&self, i: Option<usize>) -> Option<String> {
        i.map(|i| self.id(i))
    }
}

fn log_id(day: usize, index: usize) -> String {
    format!("{day}-{index}")
}

// ---- records -------------------------------------------------------------

fn action_in(ids: &Ids, a: &w::Action) -> Result<core_::Action, w::DataError> {
    Ok(core_::Action {
        actor: ids.idx(&a.actor)?,
        action_type: act_in(a.action_type),
        target: ids.opt_idx(&a.target)?,
    })
}

fn action_out(ids: &Ids, a: &core_::Action) -> w::Action {
    w::Action { actor: ids.id(a.actor), action_type: act_out(a.action_type), target: ids.opt_id(a.target) }
}

fn log_in(ids: &Ids, l: &w::Log) -> Result<core_::Log, w::DataError> {
    let receivers = match &l.receivers {
        w::Receivers::All => core_::Receivers::All,
        w::Receivers::Afterall => core_::Receivers::Afterall,
        w::Receivers::Only(rs) => {
            core_::Receivers::Only(rs.iter().map(|r| ids.idx(r)).collect::<Result<_, _>>()?)
        }
    };
    Ok(core_::Log {
        receivers,
        action_type: act_in(l.action_type),
        actor: ids.opt_idx(&l.actor)?,
        target: ids.opt_idx(&l.target)?,
        result: l.log_result.map(result_in),
    })
}

fn log_out(ids: &Ids, day: usize, index: usize, l: &core_::Log) -> w::Log {
    let receivers = match &l.receivers {
        core_::Receivers::All => w::Receivers::All,
        core_::Receivers::Afterall => w::Receivers::Afterall,
        core_::Receivers::Only(rs) => w::Receivers::Only(rs.iter().map(|&r| ids.id(r)).collect()),
    };
    w::Log {
        id: log_id(day, index),
        receivers,
        action_type: act_out(l.action_type),
        actor: ids.opt_id(l.actor),
        target: ids.opt_id(l.target),
        log_result: l.result.map(result_out),
    }
}

fn village_in(v: &w::Village) -> Result<core_::Village, w::DataError> {
    let ids = Ids(&v.creatures);
    for (i, c) in v.creatures.iter().enumerate() {
        if v.creatures[..i].iter().any(|d| d.id == c.id) {
            return Err(err(format!("duplicate creature id: {}", c.id)));
        }
    }
    let days = v
        .days
        .iter()
        .map(|d| {
            Ok(core_::Day {
                actions: d.actions.iter().map(|a| action_in(&ids, a)).collect::<Result<_, _>>()?,
                logs: d.logs.iter().map(|l| log_in(&ids, l)).collect::<Result<_, _>>()?,
            })
        })
        .collect::<Result<_, w::DataError>>()?;
    Ok(core_::Village { roles: v.creatures.iter().map(|c| role_in(c.role.role_type)).collect(), days })
}

fn village_out(src: &w::Village, v: &core_::Village) -> w::Village {
    let ids = Ids(&src.creatures);
    w::Village {
        rule: src.rule,
        creatures: src.creatures.clone(),
        days: v
            .days
            .iter()
            .enumerate()
            .map(|(d, day)| w::Day {
                day_number: (d + 1) as i32,
                actions: day.actions.iter().map(|a| action_out(&ids, a)).collect(),
                logs: day.logs.iter().enumerate().map(|(i, l)| log_out(&ids, d, i, l)).collect(),
            })
            .collect(),
    }
}

fn today_out(src: &w::Village, t: &core_::Today) -> w::Today {
    let ids = Ids(&src.creatures);
    w::Today {
        day_number: t.day_number as i32,
        winner: t.winner.map(team_out),
        creature_statuses: t
            .creature_statuses
            .iter()
            .enumerate()
            .map(|(i, s)| w::CreatureStatus {
                id: ids.id(i),
                role_type: role_out(s.role),
                team: team_out(s.team),
                available_actions: s
                    .available_actions
                    .iter()
                    .map(|a| w::AvailableAction {
                        action_type: act_out(a.action_type),
                        targets: a.targets.iter().map(|&t| ids.id(t)).collect(),
                    })
                    .collect(),
                cause_of_death: s.cause_of_death.map(cod_out),
                log_ids: s.visible_logs.iter().map(|r| log_id(r.day, r.index)).collect(),
            })
            .collect(),
    }
}

impl w::Guest for Component {
    fn create_village(roles: Vec<w::Role>, rule: w::Rule) -> Result<(w::Village, w::Today), w::DataError> {
        let village = w::Village {
            rule,
            creatures: roles
                .into_iter()
                .enumerate()
                .map(|(i, role)| w::Creature { id: format!("c{}", i + 1), role })
                .collect(),
            days: Vec::new(),
        };
        let core_village = village_in(&village)?;
        let today = today_out(&village, &core_::build_today(&core_village));
        Ok((village, today))
    }

    fn process_day(
        village: w::Village,
        actions: Vec<w::Action>,
    ) -> Result<(w::DayResult, w::Village, w::Today), w::DataError> {
        let ids = Ids(&village.creatures);
        let cv = village_in(&village)?;
        let ca = actions.iter().map(|a| action_in(&ids, a)).collect::<Result<Vec<_>, _>>()?;
        let (nv, r) = core_::process_day(&cv, &ca);
        let day = nv.days.len() - 1;
        let result = w::DayResult {
            voted: ids.opt_id(r.voted),
            deads: r.deaths.iter().map(|d| ids.id(d.creature)).collect(),
            logs: r.logs.iter().enumerate().map(|(i, l)| log_out(&ids, day, i, l)).collect(),
        };
        let today = today_out(&village, &core_::build_today(&nv));
        Ok((result, village_out(&village, &nv), today))
    }
}
