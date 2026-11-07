//! Jinro (werewolf) rule engine core.
//!
//! This crate is a port of the MoonBit `core/` package. It is deliberately
//! written in the subset of safe Rust that Charon + Aeneas translate to Lean:
//!
//! - creatures are identified by their index in `Village::roles` (no strings),
//! - no `HashMap`, no trait objects, no closures, no iterators,
//! - loops are plain `while` loops with no `return`/`break` inside nested loops
//!   (inner loops are factored out into their own functions),
//! - enum equality is done with `match`, not with derived `PartialEq`.
//!
//! The engine is stateless: a `Village` is the full history (roles + days),
//! and everything else (who is alive, who won, who can do what) is derived
//! from it.

#![no_std]
extern crate alloc;

use alloc::vec;
use alloc::vec::Vec;

/// Index of a creature in `Village::roles`.
pub type Cid = usize;

#[derive(Clone, Copy)]
#[cfg_attr(feature = "derive", derive(Debug, PartialEq))]
pub enum Team {
    Villagers,
    Wolves,
    Lovers,
    Hamsters,
}

#[derive(Clone, Copy)]
#[cfg_attr(feature = "derive", derive(Debug, PartialEq))]
pub enum RoleType {
    Villager,
    Seer,
    Bodyguard,
    Wolf,
    Madman,
    Lover,
    Bitch,
    Medium,
    Hamster,
}

#[derive(Clone, Copy)]
#[cfg_attr(feature = "derive", derive(Debug, PartialEq))]
pub enum ActionType {
    Vote,
    Bite,
    /// Public cause of death that hides the true cause.
    Unknown,
    Guard,
    Divine,
    Love,
    FakeLove,
    LoversSuicide,
    Medium,
    HamsterCurse,
}

#[derive(Clone, Copy)]
#[cfg_attr(feature = "derive", derive(Debug, PartialEq))]
pub enum CauseOfDeath {
    Executed,
    FoundDead,
}

#[derive(Clone, Copy)]
#[cfg_attr(feature = "derive", derive(Debug, PartialEq))]
pub enum LogResult {
    Dead,
    Guarded,
    Partnered,
    Wolf,
    NonWolf,
}

#[derive(Clone)]
#[cfg_attr(feature = "derive", derive(Debug, PartialEq))]
pub enum Receivers {
    /// Visible to everyone during the game.
    All,
    /// Visible to everyone once the game is over.
    Afterall,
    /// Visible only to the listed creatures.
    Only(Vec<Cid>),
}

#[derive(Clone)]
#[cfg_attr(feature = "derive", derive(Debug, PartialEq))]
pub struct Action {
    pub actor: Cid,
    pub action_type: ActionType,
    pub target: Option<Cid>,
}

#[derive(Clone)]
#[cfg_attr(feature = "derive", derive(Debug, PartialEq))]
pub struct Log {
    pub receivers: Receivers,
    pub action_type: ActionType,
    pub actor: Option<Cid>,
    pub target: Option<Cid>,
    pub result: Option<LogResult>,
}

#[derive(Clone)]
#[cfg_attr(feature = "derive", derive(Debug, PartialEq))]
pub struct Day {
    pub actions: Vec<Action>,
    pub logs: Vec<Log>,
}

#[derive(Clone)]
#[cfg_attr(feature = "derive", derive(Debug, PartialEq))]
pub struct Village {
    pub roles: Vec<RoleType>,
    pub days: Vec<Day>,
}

#[derive(Clone)]
#[cfg_attr(feature = "derive", derive(Debug, PartialEq))]
pub struct AvailableAction {
    pub action_type: ActionType,
    pub targets: Vec<Cid>,
}

/// Reference to a log: `village.days[day].logs[index]`.
#[derive(Clone, Copy)]
#[cfg_attr(feature = "derive", derive(Debug, PartialEq))]
pub struct LogRef {
    pub day: usize,
    pub index: usize,
}

#[derive(Clone)]
#[cfg_attr(feature = "derive", derive(Debug, PartialEq))]
pub struct CreatureStatus {
    pub role: RoleType,
    pub team: Team,
    pub available_actions: Vec<AvailableAction>,
    pub cause_of_death: Option<CauseOfDeath>,
    /// Logs this creature is allowed to see right now.
    pub visible_logs: Vec<LogRef>,
}

#[derive(Clone)]
#[cfg_attr(feature = "derive", derive(Debug, PartialEq))]
pub struct Today {
    pub day_number: usize,
    pub winner: Option<Team>,
    pub creature_statuses: Vec<CreatureStatus>,
}

#[derive(Clone, Copy)]
#[cfg_attr(feature = "derive", derive(Debug, PartialEq))]
pub struct Death {
    pub creature: Cid,
    /// True cause (Vote, Bite, LoversSuicide, HamsterCurse).
    pub cause: ActionType,
}

#[derive(Clone)]
#[cfg_attr(feature = "derive", derive(Debug, PartialEq))]
pub struct DayResult {
    pub voted: Option<Cid>,
    pub deaths: Vec<Death>,
    pub logs: Vec<Log>,
}

// ---------------------------------------------------------------------------
// Small predicates (explicit matches instead of derived PartialEq)
// ---------------------------------------------------------------------------

pub fn is_vote(a: ActionType) -> bool {
    match a {
        ActionType::Vote => true,
        _ => false,
    }
}

pub fn is_wolves(t: Team) -> bool {
    match t {
        Team::Wolves => true,
        _ => false,
    }
}

pub fn is_dead_result(r: Option<LogResult>) -> bool {
    match r {
        Some(LogResult::Dead) => true,
        _ => false,
    }
}

pub fn opt_eq(a: Option<Cid>, b: Option<Cid>) -> bool {
    match a {
        Some(x) => match b {
            Some(y) => x == y,
            None => false,
        },
        None => match b {
            Some(_) => false,
            None => true,
        },
    }
}

pub fn contains(ids: &Vec<Cid>, id: Cid) -> bool {
    let mut i = 0;
    let mut found = false;
    while i < ids.len() {
        if ids[i] == id {
            found = true;
        }
        i += 1;
    }
    found
}

// ---------------------------------------------------------------------------
// Roles
// ---------------------------------------------------------------------------

pub fn team_of(r: RoleType) -> Team {
    match r {
        RoleType::Wolf | RoleType::Madman => Team::Wolves,
        RoleType::Lover | RoleType::Bitch => Team::Lovers,
        // NOTE: the MoonBit implementation keeps the hamster on the villagers
        // team for counting purposes and only overrides the final winner.
        _ => Team::Villagers,
    }
}

/// Used by divine/medium. Matches MoonBit: any Wolves-team role (incl. madman).
pub fn is_wolf_role(v: &Village, id: Cid) -> bool {
    if id < v.roles.len() {
        is_wolves(team_of(v.roles[id]))
    } else {
        false
    }
}

fn can_vote(day_number: usize) -> bool {
    day_number >= 1
}

pub fn can_do_action(r: RoleType, a: ActionType, day_number: usize) -> bool {
    match a {
        ActionType::Vote => can_vote(day_number),
        ActionType::Divine => match r {
            RoleType::Seer => true,
            _ => false,
        },
        ActionType::Guard => match r {
            RoleType::Bodyguard => day_number >= 1,
            _ => false,
        },
        ActionType::Bite => match r {
            RoleType::Wolf => day_number >= 1,
            _ => false,
        },
        ActionType::Love => match r {
            RoleType::Lover | RoleType::Bitch => day_number == 1,
            _ => false,
        },
        ActionType::FakeLove => match r {
            RoleType::Bitch => day_number == 1,
            _ => false,
        },
        _ => false,
    }
}

// ---------------------------------------------------------------------------
// Life and death (derived from public logs)
// ---------------------------------------------------------------------------

/// A public (`All`) log saying `id` is dead.
pub fn is_public_death_of(l: &Log, id: Cid) -> bool {
    match l.receivers {
        Receivers::All => is_dead_result(l.result) && opt_eq(l.target, Some(id)),
        _ => false,
    }
}

/// First public death log for `id` in `logs`, if any.
pub fn public_death_in_logs(logs: &Vec<Log>, id: Cid) -> Option<ActionType> {
    let mut i = 0;
    let mut found: Option<ActionType> = None;
    while i < logs.len() {
        match found {
            None => {
                if is_public_death_of(&logs[i], id) {
                    found = Some(logs[i].action_type);
                }
            }
            Some(_) => {}
        }
        i += 1;
    }
    found
}

/// Public action type of the death of `id` (Vote or Unknown), if dead.
pub fn public_death(v: &Village, id: Cid) -> Option<ActionType> {
    let mut d = 0;
    let mut found: Option<ActionType> = None;
    while d < v.days.len() {
        match found {
            None => found = public_death_in_logs(&v.days[d].logs, id),
            Some(_) => {}
        }
        d += 1;
    }
    found
}

pub fn is_alive(v: &Village, id: Cid) -> bool {
    match public_death(v, id) {
        None => true,
        Some(_) => false,
    }
}

pub fn cause_of_death(v: &Village, id: Cid) -> Option<CauseOfDeath> {
    match public_death(v, id) {
        None => None,
        Some(ActionType::Vote) => Some(CauseOfDeath::Executed),
        Some(_) => Some(CauseOfDeath::FoundDead),
    }
}

pub fn alive_ids(v: &Village) -> Vec<Cid> {
    let mut out = Vec::new();
    let mut c = 0;
    while c < v.roles.len() {
        if is_alive(v, c) {
            out.push(c);
        }
        c += 1;
    }
    out
}

pub fn alive_ids_except(v: &Village, except: Cid) -> Vec<Cid> {
    let mut out = Vec::new();
    let mut c = 0;
    while c < v.roles.len() {
        if c != except && is_alive(v, c) {
            out.push(c);
        }
        c += 1;
    }
    out
}

pub fn alive_non_wolf_ids(v: &Village) -> Vec<Cid> {
    let mut out = Vec::new();
    let mut c = 0;
    while c < v.roles.len() {
        if is_alive(v, c) && !is_wolves(team_of(v.roles[c])) {
            out.push(c);
        }
        c += 1;
    }
    out
}

// ---------------------------------------------------------------------------
// Lovers
// ---------------------------------------------------------------------------

/// A love log forms a partnership only if it is shared with both sides.
/// (Fake love is shown to the target only, so it never forms one.)
pub fn partnership_of_log(l: &Log) -> Option<(Cid, Cid)> {
    match l.action_type {
        ActionType::Love => match l.result {
            Some(LogResult::Partnered) => match l.actor {
                Some(a) => match l.target {
                    Some(t) => match &l.receivers {
                        Receivers::Only(rs) => {
                            if contains(rs, a) && contains(rs, t) {
                                Some((a, t))
                            } else {
                                None
                            }
                        }
                        _ => None,
                    },
                    None => None,
                },
                None => None,
            },
            _ => None,
        },
        _ => None,
    }
}

pub fn partner_in_logs(logs: &Vec<Log>, id: Cid) -> Option<Cid> {
    let mut i = 0;
    let mut found: Option<Cid> = None;
    while i < logs.len() {
        match found {
            None => match partnership_of_log(&logs[i]) {
                Some((a, t)) => {
                    if a == id {
                        found = Some(t);
                    } else if t == id {
                        found = Some(a);
                    }
                }
                None => {}
            },
            Some(_) => {}
        }
        i += 1;
    }
    found
}

/// Partner of `id`: today's logs first, then past days in order.
pub fn partner_of(v: &Village, day_logs: &Vec<Log>, id: Cid) -> Option<Cid> {
    let mut found = partner_in_logs(day_logs, id);
    let mut d = 0;
    while d < v.days.len() {
        match found {
            None => found = partner_in_logs(&v.days[d].logs, id),
            Some(_) => {}
        }
        d += 1;
    }
    found
}

// ---------------------------------------------------------------------------
// Available actions
// ---------------------------------------------------------------------------

fn push_if(out: &mut Vec<AvailableAction>, enabled: bool, a: ActionType, targets: Vec<Cid>) {
    if enabled {
        out.push(AvailableAction { action_type: a, targets });
    }
}

pub fn available_actions(v: &Village, id: Cid, day_number: usize) -> Vec<AvailableAction> {
    let mut out = Vec::new();
    if !is_alive(v, id) || id >= v.roles.len() {
        return out;
    }
    let r = v.roles[id];
    push_if(&mut out, can_do_action(r, ActionType::Vote, day_number), ActionType::Vote, alive_ids_except(v, id));
    match r {
        RoleType::Seer => push_if(
            &mut out,
            can_do_action(r, ActionType::Divine, day_number),
            ActionType::Divine,
            alive_ids_except(v, id),
        ),
        RoleType::Bodyguard => push_if(
            &mut out,
            can_do_action(r, ActionType::Guard, day_number),
            ActionType::Guard,
            alive_ids(v),
        ),
        RoleType::Wolf => push_if(
            &mut out,
            can_do_action(r, ActionType::Bite, day_number),
            ActionType::Bite,
            alive_non_wolf_ids(v),
        ),
        RoleType::Lover => push_if(
            &mut out,
            can_do_action(r, ActionType::Love, day_number),
            ActionType::Love,
            alive_ids_except(v, id),
        ),
        RoleType::Bitch => {
            push_if(
                &mut out,
                can_do_action(r, ActionType::Love, day_number),
                ActionType::Love,
                alive_ids_except(v, id),
            );
            push_if(
                &mut out,
                can_do_action(r, ActionType::FakeLove, day_number),
                ActionType::FakeLove,
                alive_ids_except(v, id),
            );
        }
        _ => {}
    }
    out
}

// ---------------------------------------------------------------------------
// Day resolution
// ---------------------------------------------------------------------------

/// Accumulated effects while resolving one day.
#[derive(Clone)]
pub struct DayState {
    pub logs: Vec<Log>,
    pub deaths: Vec<Death>,
}

pub fn is_dying(st: &DayState, id: Cid) -> bool {
    let mut i = 0;
    let mut found = false;
    while i < st.deaths.len() {
        if st.deaths[i].creature == id {
            found = true;
        }
        i += 1;
    }
    found
}

pub fn add_death(st: &mut DayState, id: Cid, cause: ActionType) {
    if !is_dying(st, id) {
        st.deaths.push(Death { creature: id, cause });
    }
}

fn private_log(actor: Cid, a: ActionType, target: Option<Cid>, result: LogResult) -> Log {
    let mut rs = Vec::new();
    rs.push(actor);
    Log {
        receivers: Receivers::Only(rs),
        action_type: a,
        actor: Some(actor),
        target,
        result: Some(result),
    }
}

fn love_log(actor: Cid, target: Cid, real: bool) -> Log {
    let mut rs = Vec::new();
    if real {
        rs.push(actor);
    }
    rs.push(target);
    Log {
        receivers: Receivers::Only(rs),
        action_type: ActionType::Love,
        actor: Some(actor),
        target: Some(target),
        result: Some(LogResult::Partnered),
    }
}

pub fn first_guard_target(actions: &Vec<Action>) -> Option<Cid> {
    let mut i = 0;
    let mut found: Option<Cid> = None;
    let mut done = false;
    while i < actions.len() {
        if !done {
            match actions[i].action_type {
                ActionType::Guard => {
                    found = actions[i].target;
                    done = true;
                }
                _ => {}
            }
        }
        i += 1;
    }
    found
}

/// Effect of one submitted action, according to the actor's role.
/// Like the MoonBit version, actions are not validated against
/// `available_actions` here.
pub fn resolve_action(v: &Village, st: &mut DayState, a: &Action, guarded: Option<Cid>) {
    if a.actor >= v.roles.len() {
        return;
    }
    let role = v.roles[a.actor];
    match a.action_type {
        ActionType::Bite => match role {
            RoleType::Wolf => match a.target {
                Some(t) => {
                    if opt_eq(guarded, Some(t)) {
                        st.logs.push(private_log(a.actor, ActionType::Bite, Some(t), LogResult::Guarded));
                    } else {
                        // NOTE: matches MoonBit. CORE_SPEC says a hamster
                        // survives a bite, but this kills it.
                        st.logs.push(private_log(a.actor, ActionType::Bite, Some(t), LogResult::Dead));
                        add_death(st, t, ActionType::Bite);
                    }
                }
                None => {}
            },
            _ => {}
        },
        ActionType::Divine => match role {
            RoleType::Seer => match a.target {
                Some(t) => {
                    let res = if is_wolf_role(v, t) { LogResult::Wolf } else { LogResult::NonWolf };
                    st.logs.push(private_log(a.actor, ActionType::Divine, Some(t), res));
                    if t < v.roles.len() {
                        match v.roles[t] {
                            RoleType::Hamster => add_death(st, t, ActionType::HamsterCurse),
                            _ => {}
                        }
                    }
                }
                None => {}
            },
            _ => {}
        },
        ActionType::Guard => match role {
            RoleType::Bodyguard => {
                st.logs.push(private_log(a.actor, ActionType::Guard, a.target, LogResult::Guarded));
            }
            _ => {}
        },
        ActionType::Love => match role {
            RoleType::Lover | RoleType::Bitch => match a.target {
                Some(t) => st.logs.push(love_log(a.actor, t, true)),
                None => {}
            },
            _ => {}
        },
        ActionType::FakeLove => match role {
            RoleType::Bitch => match a.target {
                Some(t) => st.logs.push(love_log(a.actor, t, false)),
                None => {}
            },
            _ => {}
        },
        _ => {}
    }
}

pub fn resolve_actions(v: &Village, st: &mut DayState, actions: &Vec<Action>, guarded: Option<Cid>) {
    let mut i = 0;
    while i < actions.len() {
        resolve_action(v, st, &actions[i], guarded);
        i += 1;
    }
}

/// Executed creature: unique target with the most votes (ties: nobody).
pub fn compute_vote_death(actions: &Vec<Action>, n: usize) -> Option<Cid> {
    let mut counts: Vec<u32> = vec![0; n];
    let mut i = 0;
    while i < actions.len() {
        if is_vote(actions[i].action_type) {
            match actions[i].target {
                Some(t) => {
                    if t < n && counts[t] < u32::MAX {
                        counts[t] += 1;
                    }
                }
                None => {}
            }
        }
        i += 1;
    }
    let mut max: u32 = 0;
    let mut best: Option<Cid> = None;
    let mut tie = false;
    let mut c = 0;
    while c < n {
        if counts[c] > max {
            max = counts[c];
            best = Some(c);
            tie = false;
        } else if counts[c] == max && max > 0 {
            tie = true;
        }
        c += 1;
    }
    if tie {
        None
    } else {
        best
    }
}

/// Medium learns whether the executed creature was a wolf.
pub fn notify_execution(v: &Village, st: &mut DayState, executed: Cid) {
    let res = if is_wolf_role(v, executed) { LogResult::Wolf } else { LogResult::NonWolf };
    let mut c = 0;
    while c < v.roles.len() {
        if is_alive(v, c) && !is_dying(st, c) {
            match v.roles[c] {
                RoleType::Medium => st.logs.push(private_log(c, ActionType::Medium, Some(executed), res)),
                _ => {}
            }
        }
        c += 1;
    }
}

/// Lovers follow their partner in death.
pub fn notify_death(v: &Village, st: &mut DayState, dead: Cid) {
    let mut c = 0;
    while c < v.roles.len() {
        if is_alive(v, c) && !is_dying(st, c) {
            match v.roles[c] {
                RoleType::Lover | RoleType::Bitch => match partner_of(v, &st.logs, c) {
                    Some(p) => {
                        if p == dead {
                            add_death(st, c, ActionType::LoversSuicide);
                        }
                    }
                    None => {}
                },
                _ => {}
            }
        }
        c += 1;
    }
}

/// Process the death chain. `st.deaths` can grow while we iterate, but every
/// added death is a distinct creature, so the loop runs at most
/// `v.roles.len()` times (this is one of the properties to prove in Lean).
pub fn resolve_death_chain(v: &Village, st: &mut DayState) {
    let mut i = 0;
    while i < st.deaths.len() {
        let dead = st.deaths[i].creature;
        notify_death(v, st, dead);
        i += 1;
    }
}

/// In-game, only executions are revealed; other causes look the same.
pub fn public_death_action(true_cause: ActionType) -> ActionType {
    match true_cause {
        ActionType::Bite | ActionType::LoversSuicide | ActionType::HamsterCurse => ActionType::Unknown,
        _ => true_cause,
    }
}

pub fn publish_deaths(st: &mut DayState) {
    let mut i = 0;
    while i < st.deaths.len() {
        let d = st.deaths[i];
        st.logs.push(Log {
            receivers: Receivers::All,
            action_type: public_death_action(d.cause),
            actor: None,
            target: Some(d.creature),
            result: Some(LogResult::Dead),
        });
        st.logs.push(Log {
            receivers: Receivers::Afterall,
            action_type: d.cause,
            actor: None,
            target: Some(d.creature),
            result: Some(LogResult::Dead),
        });
        i += 1;
    }
}

/// Resolve one full cycle (night actions + vote) and append it to the village.
pub fn process_day(v: &Village, actions: &Vec<Action>) -> (Village, DayResult) {
    let mut st = DayState { logs: Vec::new(), deaths: Vec::new() };
    let guarded = first_guard_target(actions);
    resolve_actions(v, &mut st, actions, guarded);

    let voted = compute_vote_death(actions, v.roles.len());
    match voted {
        Some(t) => {
            add_death(&mut st, t, ActionType::Vote);
            notify_execution(v, &mut st, t);
        }
        None => {}
    }

    resolve_death_chain(v, &mut st);
    publish_deaths(&mut st);

    let mut nv = v.clone();
    nv.days.push(Day { actions: actions.clone(), logs: st.logs.clone() });
    (nv, DayResult { voted, deaths: st.deaths, logs: st.logs })
}

// ---------------------------------------------------------------------------
// Victory
// ---------------------------------------------------------------------------

pub fn base_winner(v: &Village) -> Option<Team> {
    let alive = alive_ids(v);
    let mut lovers_win = false;
    if alive.len() == 2 {
        let a = alive[0];
        let b = alive[1];
        let empty = Vec::new();
        lovers_win = opt_eq(partner_of(v, &empty, a), Some(b)) && opt_eq(partner_of(v, &empty, b), Some(a));
    }
    if lovers_win {
        return Some(Team::Lovers);
    }
    let mut wolves: usize = 0;
    let mut others: usize = 0;
    let mut c = 0;
    while c < v.roles.len() {
        if is_alive(v, c) {
            match team_of(v.roles[c]) {
                Team::Wolves => wolves += 1,
                Team::Lovers => {}
                _ => others += 1,
            }
        }
        c += 1;
    }
    if wolves == 0 {
        Some(Team::Villagers)
    } else if wolves >= others {
        Some(Team::Wolves)
    } else {
        None
    }
}

pub fn hamster_alive(v: &Village) -> bool {
    let mut c = 0;
    let mut found = false;
    while c < v.roles.len() {
        match v.roles[c] {
            RoleType::Hamster => {
                if is_alive(v, c) {
                    found = true;
                }
            }
            _ => {}
        }
        c += 1;
    }
    found
}

pub fn winner(v: &Village) -> Option<Team> {
    match base_winner(v) {
        None => None,
        Some(t) => {
            if hamster_alive(v) {
                Some(Team::Hamsters)
            } else {
                Some(t)
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Views
// ---------------------------------------------------------------------------

pub fn can_see(l: &Log, viewer: Cid, game_over: bool) -> bool {
    match &l.receivers {
        Receivers::All => true,
        Receivers::Afterall => game_over,
        Receivers::Only(rs) => contains(rs, viewer),
    }
}

fn visible_in_day(out: &mut Vec<LogRef>, day: &Day, d: usize, viewer: Cid, game_over: bool) {
    let mut i = 0;
    while i < day.logs.len() {
        if can_see(&day.logs[i], viewer, game_over) {
            out.push(LogRef { day: d, index: i });
        }
        i += 1;
    }
}

pub fn visible_logs(v: &Village, viewer: Cid, game_over: bool) -> Vec<LogRef> {
    let mut out = Vec::new();
    let mut d = 0;
    while d < v.days.len() {
        visible_in_day(&mut out, &v.days[d], d, viewer, game_over);
        d += 1;
    }
    out
}

pub fn build_today(v: &Village) -> Today {
    let day_number = v.days.len();
    let w = winner(v);
    let game_over = match w {
        Some(_) => true,
        None => false,
    };
    let mut statuses = Vec::new();
    let mut c = 0;
    while c < v.roles.len() {
        let r = v.roles[c];
        statuses.push(CreatureStatus {
            role: r,
            team: team_of(r),
            available_actions: available_actions(v, c, day_number),
            cause_of_death: cause_of_death(v, c),
            visible_logs: visible_logs(v, c, game_over),
        });
        c += 1;
    }
    Today { day_number, winner: w, creature_statuses: statuses }
}

pub fn create_village(roles: &Vec<RoleType>) -> Village {
    Village { roles: roles.clone(), days: Vec::new() }
}
