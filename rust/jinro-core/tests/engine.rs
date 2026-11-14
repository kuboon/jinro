//! Ported from core/jinro_test.mbt (one test per MoonBit test block).

use jinro_core::*;

fn act(actor: Cid, action_type: ActionType, target: Cid) -> Action {
    Action { actor, action_type, target: Some(target) }
}

fn has(acts: &[AvailableAction], f: fn(ActionType) -> bool) -> bool {
    acts.iter().any(|a| f(a.action_type))
}

fn day(v: &Village, actions: Vec<Action>) -> (Village, DayResult, Today) {
    let (nv, r) = process_day(v, &actions);
    let t = build_today(&nv);
    (nv, r, t)
}

#[test]
fn create_village_assigns_creatures() {
    let v = create_village(&vec![RoleType::Villager, RoleType::Wolf, RoleType::Seer]);
    let t = build_today(&v);
    assert_eq!(v.roles.len(), 3);
    assert_eq!(t.day_number, 0);
    assert_eq!(t.creature_statuses.len(), 3);
}

#[test]
fn seer_can_divine_from_day0() {
    let v = create_village(&vec![RoleType::Seer, RoleType::Villager]);
    let t = build_today(&v);
    assert!(has(&t.creature_statuses[0].available_actions, |a| matches!(a, ActionType::Divine)));
}

#[test]
fn villager_can_vote_from_day1() {
    let v = create_village(&vec![RoleType::Villager, RoleType::Villager]);
    let (_v1, _r1, t1) = day(&v, vec![]);
    assert!(has(&t1.creature_statuses[0].available_actions, |a| matches!(a, ActionType::Vote)));
    let t0 = build_today(&v);
    assert!(!has(&t0.creature_statuses[0].available_actions, |a| matches!(a, ActionType::Vote)));
}

#[test]
fn madman_is_on_wolves_team() {
    let v = create_village(&vec![RoleType::Madman, RoleType::Villager]);
    assert_eq!(build_today(&v).creature_statuses[0].team, Team::Wolves);
}

#[test]
fn vote_kills() {
    let v0 = create_village(&vec![RoleType::Villager; 3]);
    let (v1, _, _) = day(&v0, vec![]);
    let (_v2, r2, t2) = day(
        &v1,
        vec![act(0, ActionType::Vote, 1), act(1, ActionType::Vote, 1), act(2, ActionType::Vote, 1)],
    );
    assert_eq!(r2.deaths, vec![Death { creature: 1, cause: ActionType::Vote }]);
    assert_eq!(r2.voted, Some(1));
    assert_eq!(t2.creature_statuses[1].cause_of_death, Some(CauseOfDeath::Executed));
}

#[test]
fn vote_tie_executes_nobody() {
    let v0 = create_village(&vec![RoleType::Villager; 4]);
    let (_v1, r1, _) = day(
        &v0,
        vec![act(0, ActionType::Vote, 1), act(1, ActionType::Vote, 0)],
    );
    assert_eq!(r1.voted, None);
    assert!(r1.deaths.is_empty());
}

#[test]
fn medium_sees_executed_wolf() {
    let v0 = create_village(&vec![RoleType::Medium, RoleType::Wolf, RoleType::Villager]);
    let (v1, _, _) = day(&v0, vec![]);
    let (_v2, r2, _) = day(
        &v1,
        vec![act(0, ActionType::Vote, 1), act(2, ActionType::Vote, 1), act(1, ActionType::Vote, 2)],
    );
    assert!(r2.logs.iter().any(|l| matches!(l.action_type, ActionType::Medium)
        && l.actor == Some(0)
        && l.target == Some(1)
        && l.result == Some(LogResult::Wolf)));
}

#[test]
fn bite_kills_if_not_guarded() {
    let v0 = create_village(&vec![RoleType::Wolf, RoleType::Villager]);
    let (_v1, r1, t1) = day(&v0, vec![act(0, ActionType::Bite, 1)]);
    assert_eq!(r1.deaths, vec![Death { creature: 1, cause: ActionType::Bite }]);
    assert_eq!(t1.creature_statuses[1].cause_of_death, Some(CauseOfDeath::FoundDead));
}

#[test]
fn hamster_dies_when_divined() {
    let v0 = create_village(&vec![RoleType::Seer, RoleType::Hamster, RoleType::Villager]);
    let (_v1, r1, _) = day(&v0, vec![act(0, ActionType::Divine, 1)]);
    assert_eq!(r1.deaths, vec![Death { creature: 1, cause: ActionType::HamsterCurse }]);
    let has_public = r1.logs.iter().any(|l| l.receivers == Receivers::All
        && l.action_type == ActionType::Unknown
        && l.target == Some(1)
        && l.result == Some(LogResult::Dead));
    let has_afterall = r1.logs.iter().any(|l| l.receivers == Receivers::Afterall
        && l.action_type == ActionType::HamsterCurse
        && l.target == Some(1)
        && l.result == Some(LogResult::Dead));
    assert!(has_public && has_afterall);
}

#[test]
fn hamster_wins_solo_if_alive_at_end() {
    let v0 = create_village(&vec![RoleType::Hamster, RoleType::Wolf, RoleType::Villager]);
    let (v1, _, _) = day(&v0, vec![]);
    let (_v2, _r2, t2) = day(
        &v1,
        vec![act(0, ActionType::Vote, 1), act(2, ActionType::Vote, 1), act(1, ActionType::Vote, 2)],
    );
    assert_eq!(t2.winner, Some(Team::Hamsters));
}

#[test]
fn guard_prevents_bite() {
    let v0 = create_village(&vec![RoleType::Wolf, RoleType::Bodyguard, RoleType::Villager]);
    let (_v1, r1, _) = day(&v0, vec![act(1, ActionType::Guard, 2), act(0, ActionType::Bite, 2)]);
    assert!(r1.deaths.is_empty());
}

#[test]
fn bitch_has_love_and_fake_love_on_day1() {
    let v0 = create_village(&vec![RoleType::Bitch, RoleType::Villager]);
    let (_v1, _, t1) = day(&v0, vec![]);
    let acts = &t1.creature_statuses[0].available_actions;
    assert!(has(acts, |a| matches!(a, ActionType::Love)));
    assert!(has(acts, |a| matches!(a, ActionType::FakeLove)));
}

#[test]
fn fake_love_does_not_form_partnership() {
    let v0 = create_village(&vec![RoleType::Bitch, RoleType::Villager, RoleType::Wolf]);
    let (_v1, r1, _) = day(&v0, vec![act(0, ActionType::FakeLove, 1), act(2, ActionType::Bite, 1)]);
    assert_eq!(r1.deaths, vec![Death { creature: 1, cause: ActionType::Bite }]);
}

#[test]
fn bitch_real_love_can_win() {
    let v0 = create_village(&vec![RoleType::Bitch, RoleType::Villager, RoleType::Wolf]);
    let (v1, _, _) = day(&v0, vec![act(0, ActionType::Love, 1)]);
    let (_v2, _, t2) = day(&v1, vec![act(0, ActionType::Vote, 2), act(1, ActionType::Vote, 2)]);
    assert_eq!(t2.winner, Some(Team::Lovers));
}

#[test]
fn lover_suicide_when_partner_dies() {
    let v0 = create_village(&vec![RoleType::Lover, RoleType::Villager, RoleType::Wolf]);
    let (_v1, r1, _) = day(&v0, vec![act(0, ActionType::Love, 1), act(2, ActionType::Bite, 1)]);
    assert_eq!(
        r1.deaths,
        vec![
            Death { creature: 1, cause: ActionType::Bite },
            Death { creature: 0, cause: ActionType::LoversSuicide },
        ]
    );
}

#[test]
fn lovers_win_when_last_two() {
    let v0 = create_village(&vec![RoleType::Lover, RoleType::Villager, RoleType::Wolf]);
    let (v1, _, _) = day(&v0, vec![act(0, ActionType::Love, 1)]);
    let (_v2, _, t2) = day(&v1, vec![act(0, ActionType::Vote, 2), act(1, ActionType::Vote, 2)]);
    assert_eq!(t2.winner, Some(Team::Lovers));
}

#[test]
fn private_logs_are_private() {
    let v0 = create_village(&vec![RoleType::Seer, RoleType::Wolf, RoleType::Villager]);
    let (v1, _, t1) = day(&v0, vec![act(0, ActionType::Divine, 1)]);
    // seer sees the divine log, others don't
    assert_eq!(t1.creature_statuses[0].visible_logs.len(), 1);
    assert!(t1.creature_statuses[2].visible_logs.is_empty());
    assert_eq!(v1.days.len(), 1);
}

/// Documents the current behaviour, which disagrees with CORE_SPEC
/// ("hamster survives bite"). Flip this assertion when the rule is fixed.
#[test]
fn spec_gap_hamster_dies_to_bite() {
    let v0 = create_village(&vec![RoleType::Wolf, RoleType::Hamster, RoleType::Villager]);
    let (_v1, r1, _) = day(&v0, vec![act(0, ActionType::Bite, 1)]);
    assert_eq!(r1.deaths.len(), 1);
}
