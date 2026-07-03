from game.logic import RoundResult, SessionState


def test_initial_state_is_playable() -> None:
    state = SessionState(total_fireflies=6, seconds_remaining=100.0, health=3)
    assert state.result is RoundResult.PLAYING
    assert state.rescued == 0
    assert state.score == 0


def test_timer_causes_defeat_without_becoming_negative() -> None:
    state = SessionState(total_fireflies=6, seconds_remaining=0.25, health=3)
    state.tick(1.0)
    assert state.seconds_remaining == 0
    assert state.result is RoundResult.LOST


def test_rescuing_every_firefly_causes_victory() -> None:
    state = SessionState(total_fireflies=2, seconds_remaining=50.0, health=3)
    assert state.rescue()
    assert state.result is RoundResult.PLAYING
    assert state.rescue()
    assert state.result is RoundResult.WON
    assert state.score > 200


def test_cannot_score_after_round_has_finished() -> None:
    state = SessionState(total_fireflies=1, seconds_remaining=20.0, health=1)
    state.rescue()
    score = state.score
    assert not state.rescue()
    assert state.score == score


def test_damage_removes_health_and_eventually_causes_defeat() -> None:
    state = SessionState(total_fireflies=6, seconds_remaining=60.0, health=2, score=100)
    assert state.take_damage()
    assert state.health == 1
    assert state.score == 25
    assert state.take_damage()
    assert state.health == 0
    assert state.result is RoundResult.LOST
