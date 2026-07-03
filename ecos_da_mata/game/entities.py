from __future__ import annotations

import math
from dataclasses import dataclass

import pygame

from .settings import (
    DASH_COOLDOWN,
    DASH_DURATION,
    DASH_MULTIPLIER,
    INVULNERABILITY_TIME,
    PLAYER_SPEED,
)


def move_with_collisions(
    rect: pygame.Rect,
    position: pygame.Vector2,
    velocity: pygame.Vector2,
    delta_time: float,
    obstacles: list[pygame.Rect],
) -> None:
    position.x += velocity.x * delta_time
    rect.centerx = round(position.x)
    for obstacle in obstacles:
        if rect.colliderect(obstacle):
            if velocity.x > 0:
                rect.right = obstacle.left
            elif velocity.x < 0:
                rect.left = obstacle.right
            position.x = rect.centerx

    position.y += velocity.y * delta_time
    rect.centery = round(position.y)
    for obstacle in obstacles:
        if rect.colliderect(obstacle):
            if velocity.y > 0:
                rect.bottom = obstacle.top
            elif velocity.y < 0:
                rect.top = obstacle.bottom
            position.y = rect.centery


class Player:
    def __init__(self, image: pygame.Surface, position: tuple[int, int]) -> None:
        self.image = image
        self.position = pygame.Vector2(position)
        self.rect = pygame.Rect(0, 0, 34, 42)
        self.rect.center = position
        self.velocity = pygame.Vector2()
        self.facing = pygame.Vector2(0, 1)
        self.dash_time = 0.0
        self.dash_cooldown = 0.0
        self.invulnerable = 0.0
        self.walk_time = 0.0

    def request_dash(self) -> None:
        if self.dash_cooldown <= 0 and self.velocity.length_squared() > 0:
            self.dash_time = DASH_DURATION
            self.dash_cooldown = DASH_COOLDOWN

    def update(
        self,
        delta_time: float,
        keys: pygame.key.ScancodeWrapper,
        obstacles: list[pygame.Rect],
    ) -> None:
        direction = pygame.Vector2(
            int(keys[pygame.K_d] or keys[pygame.K_RIGHT])
            - int(keys[pygame.K_a] or keys[pygame.K_LEFT]),
            int(keys[pygame.K_s] or keys[pygame.K_DOWN])
            - int(keys[pygame.K_w] or keys[pygame.K_UP]),
        )
        if direction.length_squared() > 0:
            direction = direction.normalize()
            self.facing = direction
            self.walk_time += delta_time * 10
        self.velocity = direction * PLAYER_SPEED
        if self.dash_time > 0:
            self.velocity *= DASH_MULTIPLIER
        self.dash_time = max(0.0, self.dash_time - delta_time)
        self.dash_cooldown = max(0.0, self.dash_cooldown - delta_time)
        self.invulnerable = max(0.0, self.invulnerable - delta_time)
        move_with_collisions(self.rect, self.position, self.velocity, delta_time, obstacles)

    def draw(self, screen: pygame.Surface) -> None:
        if self.invulnerable > 0 and int(self.invulnerable * 10) % 2 == 0:
            return
        bob = int(math.sin(self.walk_time) * 2) if self.velocity.length_squared() else 0
        target = self.image.get_rect(midbottom=(self.rect.centerx, self.rect.bottom + 7 + bob))
        shadow = pygame.Rect(0, 0, 34, 12)
        shadow.center = (self.rect.centerx, self.rect.bottom + 1)
        pygame.draw.ellipse(screen, (5, 25, 21, 110), shadow)
        screen.blit(self.image, target)


@dataclass
class Firefly:
    image: pygame.Surface
    position: pygame.Vector2
    phase: float
    rescued: bool = False

    @property
    def center(self) -> pygame.Vector2:
        return self.position

    def draw(self, screen: pygame.Surface, time: float) -> None:
        if self.rescued:
            return
        pulse = 12 + int((math.sin(time * 4 + self.phase) + 1) * 4)
        glow = pygame.Surface((pulse * 2, pulse * 2), pygame.SRCALPHA)
        pygame.draw.circle(glow, (251, 232, 96, 50), (pulse, pulse), pulse)
        bob = math.sin(time * 3 + self.phase) * 5
        center = (round(self.position.x), round(self.position.y + bob))
        screen.blit(glow, glow.get_rect(center=center))
        screen.blit(self.image, self.image.get_rect(center=center))


class Boar:
    def __init__(
        self,
        image: pygame.Surface,
        start: tuple[int, int],
        end: tuple[int, int],
        speed: float,
    ) -> None:
        self.image = image
        self.position = pygame.Vector2(start)
        self.start = pygame.Vector2(start)
        self.end = pygame.Vector2(end)
        self.target = self.end
        self.speed = speed
        self.rect = pygame.Rect(0, 0, 46, 34)
        self.rect.center = start

    def update(self, delta_time: float) -> None:
        offset = self.target - self.position
        if offset.length() < 6:
            self.target = self.start if self.target == self.end else self.end
            offset = self.target - self.position
        if offset.length_squared() > 0:
            self.position += offset.normalize() * self.speed * delta_time
            self.rect.center = (round(self.position.x), round(self.position.y))

    def draw(self, screen: pygame.Surface) -> None:
        shadow = pygame.Rect(0, 0, 44, 12)
        shadow.center = (self.rect.centerx, self.rect.bottom)
        pygame.draw.ellipse(screen, (5, 25, 21), shadow)
        screen.blit(self.image, self.image.get_rect(midbottom=(self.rect.centerx, self.rect.bottom + 5)))
