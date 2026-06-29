from __future__ import annotations

from dataclasses import dataclass
from enum import Enum, auto


class RoundResult(Enum):
    PLAYING = auto()
    WON = auto()
    LOST = auto()


@dataclass
class SessionState:
    """Estado independente da renderização, simples de testar."""

    total_fireflies: int
    seconds_remaining: float
    health: int
    rescued: int = 0
    score: int = 0
    result: RoundResult = RoundResult.PLAYING

    def tick(self, delta_time: float) -> None:
        if self.result is not RoundResult.PLAYING:
            return
        self.seconds_remaining = max(0.0, self.seconds_remaining - max(0.0, delta_time))
        if self.seconds_remaining == 0.0:
            self.result = RoundResult.LOST

    def rescue(self) -> bool:
        if self.result is not RoundResult.PLAYING or self.rescued >= self.total_fireflies:
            return False
        self.rescued += 1
        self.score += 100 + int(self.seconds_remaining)
        if self.rescued == self.total_fireflies:
            self.score += int(self.seconds_remaining) * 5 + self.health * 250
            self.result = RoundResult.WON
        return True

    def take_damage(self) -> bool:
        if self.result is not RoundResult.PLAYING:
            return False
        self.health = max(0, self.health - 1)
        self.score = max(0, self.score - 75)
        if self.health == 0:
            self.result = RoundResult.LOST
        return True
