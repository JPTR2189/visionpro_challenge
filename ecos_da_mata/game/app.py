from __future__ import annotations

import math
from enum import Enum, auto
from pathlib import Path

import pygame

from .entities import Boar, Firefly, Player
from .logic import RoundResult, SessionState
from .resources import Assets
from .settings import (
    COLORS,
    FPS,
    HEIGHT,
    INTERACTION_DISTANCE,
    ROUND_SECONDS,
    STARTING_HEALTH,
    TITLE,
    TOTAL_FIREFLIES,
    WIDTH,
)


class Scene(Enum):
    MENU = auto()
    INSTRUCTIONS = auto()
    PLAYING = auto()
    PAUSED = auto()
    RESULT = auto()


class GameApp:
    def __init__(self) -> None:
        pygame.init()
        try:
            if not pygame.mixer.get_init():
                pygame.mixer.init()
        except pygame.error:
            pass
        self.screen = pygame.display.set_mode((WIDTH, HEIGHT))
        pygame.display.set_caption(TITLE)
        self.clock = pygame.time.Clock()
        self.assets = Assets()
        self.font_small = pygame.font.SysFont("verdana", 18)
        self.font_medium = pygame.font.SysFont("verdana", 28, bold=True)
        self.font_large = pygame.font.SysFont("verdana", 52, bold=True)
        self.font_title = pygame.font.SysFont("georgia", 72, bold=True)
        self.running = True
        self.scene = Scene.MENU
        self.music_enabled = True
        self.fullscreen = False
        self.elapsed = 0.0
        self.message = ""
        self.message_time = 0.0
        self._start_music()
        self._new_round()

    def _start_music(self) -> None:
        if pygame.mixer.get_init() and self.music_enabled:
            pygame.mixer.music.play(-1)

    def _new_round(self) -> None:
        self.state = SessionState(TOTAL_FIREFLIES, ROUND_SECONDS, STARTING_HEALTH)
        self.player = Player(self.assets.images["player"], (100, 545))
        self.trees = [
            (80, 100), (190, 275), (315, 145), (465, 495), (595, 170),
            (700, 350), (840, 270), (875, 565), (360, 560), (740, 95),
        ]
        self.rocks = [(275, 370), (525, 270), (650, 555), (900, 410), (410, 250)]
        self.obstacles = [pygame.Rect(x - 25, y - 18, 50, 45) for x, y in self.trees]
        self.obstacles += [pygame.Rect(x - 24, y - 14, 48, 32) for x, y in self.rocks]
        self.obstacles += [
            pygame.Rect(-20, 0, 35, HEIGHT),
            pygame.Rect(WIDTH - 15, 0, 35, HEIGHT),
            pygame.Rect(0, -20, WIDTH, 35),
            pygame.Rect(0, HEIGHT - 15, WIDTH, 35),
        ]
        firefly_positions = [(145, 155), (485, 100), (825, 140), (235, 500), (595, 470), (805, 535)]
        self.fireflies = [
            Firefly(self.assets.images["firefly"], pygame.Vector2(position), index * 0.9)
            for index, position in enumerate(firefly_positions)
        ]
        self.boars = [
            Boar(self.assets.images["boar"], (120, 335), (380, 335), 100),
            Boar(self.assets.images["boar"], (565, 385), (880, 385), 118),
            Boar(self.assets.images["boar"], (620, 225), (850, 225), 92),
        ]
        self.message = "Encontre os 6 vaga-lumes e pressione E para resgatá-los."
        self.message_time = 5.0

    def _set_scene(self, scene: Scene) -> None:
        self.scene = scene
        self.assets.play("click", 0.55)

    def _button(self, label: str, center: tuple[int, int], width: int = 310) -> pygame.Rect:
        rect = pygame.Rect(0, 0, width, 55)
        rect.center = center
        hovered = rect.collidepoint(pygame.mouse.get_pos())
        fill = COLORS["mint"] if hovered else (28, 79, 60)
        text_color = COLORS["forest"] if hovered else COLORS["white"]
        pygame.draw.rect(self.screen, COLORS["shadow"], rect.move(0, 5), border_radius=10)
        pygame.draw.rect(self.screen, fill, rect, border_radius=10)
        pygame.draw.rect(self.screen, COLORS["mint"], rect, 2, border_radius=10)
        self._text(label, self.font_medium, text_color, rect.center)
        return rect

    def _text(
        self,
        text: str,
        font: pygame.font.Font,
        color: tuple[int, int, int],
        position: tuple[int, int],
        anchor: str = "center",
    ) -> pygame.Rect:
        surface = font.render(text, True, color)
        rect = surface.get_rect()
        setattr(rect, anchor, position)
        self.screen.blit(surface, rect)
        return rect

    def _toggle_music(self) -> None:
        self.music_enabled = not self.music_enabled
        if not pygame.mixer.get_init():
            return
        if self.music_enabled:
            pygame.mixer.music.play(-1)
        else:
            pygame.mixer.music.stop()

    def _toggle_fullscreen(self) -> None:
        self.fullscreen = not self.fullscreen
        flags = pygame.FULLSCREEN if self.fullscreen else 0
        self.screen = pygame.display.set_mode((WIDTH, HEIGHT), flags)

    def _handle_global_event(self, event: pygame.event.Event) -> bool:
        if event.type == pygame.QUIT:
            self.running = False
            return True
        if event.type == pygame.KEYDOWN and event.key == pygame.K_F11:
            self._toggle_fullscreen()
            return True
        if event.type == pygame.KEYDOWN and event.key == pygame.K_m:
            self._toggle_music()
            return True
        return False

    def _handle_menu_event(self, event: pygame.event.Event) -> None:
        if event.type == pygame.KEYDOWN:
            if event.key in (pygame.K_RETURN, pygame.K_SPACE):
                self._new_round()
                self._set_scene(Scene.PLAYING)
            elif event.key == pygame.K_h:
                self._set_scene(Scene.INSTRUCTIONS)
            elif event.key == pygame.K_ESCAPE:
                self.running = False
        if event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
            if pygame.Rect(325, 350, 310, 55).collidepoint(event.pos):
                self._new_round()
                self._set_scene(Scene.PLAYING)
            elif pygame.Rect(325, 420, 310, 55).collidepoint(event.pos):
                self._set_scene(Scene.INSTRUCTIONS)
            elif pygame.Rect(325, 490, 310, 55).collidepoint(event.pos):
                self.running = False

    def _handle_instructions_event(self, event: pygame.event.Event) -> None:
        if event.type == pygame.KEYDOWN:
            if event.key in (pygame.K_RETURN, pygame.K_SPACE):
                self._new_round()
                self._set_scene(Scene.PLAYING)
            elif event.key in (pygame.K_ESCAPE, pygame.K_BACKSPACE):
                self._set_scene(Scene.MENU)
        if event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
            if pygame.Rect(325, 535, 310, 55).collidepoint(event.pos):
                self._new_round()
                self._set_scene(Scene.PLAYING)

    def _nearest_firefly(self) -> Firefly | None:
        active = [item for item in self.fireflies if not item.rescued]
        if not active:
            return None
        nearest = min(active, key=lambda item: self.player.position.distance_squared_to(item.center))
        if self.player.position.distance_to(nearest.center) <= INTERACTION_DISTANCE:
            return nearest
        return None

    def _rescue_nearby(self) -> None:
        firefly = self._nearest_firefly()
        if firefly is None:
            self.message = "Aproxime-se do brilho de um vaga-lume."
            self.message_time = 1.6
            return
        if self.state.rescue():
            firefly.rescued = True
            self.assets.play("rescue", 0.8)
            remaining = self.state.total_fireflies - self.state.rescued
            self.message = "Todos estão a salvo!" if remaining == 0 else f"Vaga-lume resgatado! Faltam {remaining}."
            self.message_time = 2.0

    def _handle_play_event(self, event: pygame.event.Event) -> None:
        if event.type != pygame.KEYDOWN:
            return
        if event.key in (pygame.K_ESCAPE, pygame.K_p):
            self._set_scene(Scene.PAUSED)
        elif event.key == pygame.K_e:
            self._rescue_nearby()
        elif event.key in (pygame.K_LSHIFT, pygame.K_RSHIFT, pygame.K_SPACE):
            self.player.request_dash()

    def _handle_paused_event(self, event: pygame.event.Event) -> None:
        if event.type != pygame.KEYDOWN:
            return
        if event.key in (pygame.K_ESCAPE, pygame.K_p):
            self._set_scene(Scene.PLAYING)
        elif event.key == pygame.K_r:
            self._new_round()
            self._set_scene(Scene.PLAYING)
        elif event.key == pygame.K_q:
            self._set_scene(Scene.MENU)

    def _handle_result_event(self, event: pygame.event.Event) -> None:
        if event.type == pygame.KEYDOWN:
            if event.key in (pygame.K_r, pygame.K_RETURN, pygame.K_SPACE):
                self._new_round()
                self._set_scene(Scene.PLAYING)
            elif event.key == pygame.K_ESCAPE:
                self._set_scene(Scene.MENU)
        if event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
            if pygame.Rect(325, 458, 310, 55).collidepoint(event.pos):
                self._new_round()
                self._set_scene(Scene.PLAYING)
            elif pygame.Rect(325, 528, 310, 55).collidepoint(event.pos):
                self._set_scene(Scene.MENU)

    def handle_events(self) -> None:
        for event in pygame.event.get():
            if self._handle_global_event(event):
                continue
            if self.scene is Scene.MENU:
                self._handle_menu_event(event)
            elif self.scene is Scene.INSTRUCTIONS:
                self._handle_instructions_event(event)
            elif self.scene is Scene.PLAYING:
                self._handle_play_event(event)
            elif self.scene is Scene.PAUSED:
                self._handle_paused_event(event)
            elif self.scene is Scene.RESULT:
                self._handle_result_event(event)

    def update(self, delta_time: float) -> None:
        self.elapsed += delta_time
        self.message_time = max(0.0, self.message_time - delta_time)
        if self.scene is not Scene.PLAYING:
            return
        self.state.tick(delta_time)
        self.player.update(delta_time, pygame.key.get_pressed(), self.obstacles)
        for boar in self.boars:
            boar.update(delta_time)
            if boar.rect.colliderect(self.player.rect) and self.player.invulnerable <= 0:
                if self.state.take_damage():
                    self.assets.play("hit", 0.75)
                    self.player.invulnerable = 1.25
                    direction = self.player.position - boar.position
                    if direction.length_squared() > 0:
                        self.player.position += direction.normalize() * 45
                        self.player.rect.center = self.player.position
                    self.message = "Cuidado com os javalis! Você perdeu um coração."
                    self.message_time = 2.2
        if self.state.result is not RoundResult.PLAYING:
            if self.state.result is RoundResult.WON:
                self.assets.play("win", 0.9)
            self.scene = Scene.RESULT

    def _draw_background(self) -> None:
        tile = self.assets.images["ground"]
        for x in range(0, WIDTH, tile.get_width()):
            for y in range(0, HEIGHT, tile.get_height()):
                self.screen.blit(tile, (x, y))
        vignette = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
        pygame.draw.rect(vignette, (3, 19, 16, 35), vignette.get_rect(), 26)
        self.screen.blit(vignette, (0, 0))

    def _draw_world(self) -> None:
        self._draw_background()
        shrine = self.assets.images["shrine"]
        self.screen.blit(shrine, shrine.get_rect(midbottom=(480, 355)))
        self._text("Santuário", self.font_small, COLORS["cream"], (480, 375))
        for x, y in self.trees:
            image = self.assets.images["tree"]
            shadow = pygame.Rect(0, 0, 48, 15)
            shadow.center = (x, y + 22)
            pygame.draw.ellipse(self.screen, COLORS["shadow"], shadow)
            self.screen.blit(image, image.get_rect(midbottom=(x, y + 28)))
        for x, y in self.rocks:
            image = self.assets.images["rock"]
            self.screen.blit(image, image.get_rect(midbottom=(x, y + 22)))
        for firefly in self.fireflies:
            firefly.draw(self.screen, self.elapsed)
        for boar in self.boars:
            boar.draw(self.screen)
        self.player.draw(self.screen)
        nearest = self._nearest_firefly()
        if nearest is not None and self.scene is Scene.PLAYING:
            self._interaction_prompt("E  RESGATAR")
        self._draw_hud()

    def _interaction_prompt(self, label: str) -> None:
        rect = pygame.Rect(0, 0, 170, 38)
        rect.midbottom = (self.player.rect.centerx, self.player.rect.top - 8)
        pygame.draw.rect(self.screen, COLORS["panel"], rect, border_radius=9)
        pygame.draw.rect(self.screen, COLORS["gold"], rect, 2, border_radius=9)
        self._text(label, self.font_small, COLORS["gold"], rect.center)

    def _draw_hud(self) -> None:
        panel = pygame.Surface((WIDTH - 36, 66), pygame.SRCALPHA)
        pygame.draw.rect(panel, (8, 29, 26, 225), panel.get_rect(), border_radius=14)
        self.screen.blit(panel, (18, 16))
        heart = self.assets.images["heart"]
        for index in range(self.state.health):
            self.screen.blit(heart, (36 + index * 42, 28))
        firefly = self.assets.images["firefly"]
        self.screen.blit(pygame.transform.scale(firefly, (40, 40)), (194, 28))
        self._text(
            f"{self.state.rescued}/{self.state.total_fireflies}",
            self.font_medium,
            COLORS["gold"],
            (242, 48),
            "midleft",
        )
        self._text(f"PONTOS  {self.state.score:04d}", self.font_small, COLORS["cream"], (430, 49))
        seconds = math.ceil(self.state.seconds_remaining)
        time_color = COLORS["red"] if seconds <= 15 else COLORS["white"]
        self._text(f"TEMPO  {seconds:02d}s", self.font_medium, time_color, (805, 49))
        if self.message_time > 0:
            surface = self.font_small.render(self.message, True, COLORS["cream"])
            box = surface.get_rect(center=(WIDTH // 2, HEIGHT - 35)).inflate(34, 18)
            pygame.draw.rect(self.screen, (8, 29, 26), box, border_radius=9)
            pygame.draw.rect(self.screen, COLORS["mint"], box, 1, border_radius=9)
            self.screen.blit(surface, surface.get_rect(center=box.center))

    def _draw_menu(self) -> None:
        self._draw_background()
        logo = self.assets.images["logo_bg"]
        self.screen.blit(logo, logo.get_rect(center=(WIDTH // 2, 175)))
        self._text("ECOS", self.font_title, COLORS["white"], (WIDTH // 2, 145))
        self._text("DA MATA", self.font_large, COLORS["mint"], (WIDTH // 2, 207))
        self._text("Uma aventura de resgate na floresta", self.font_small, COLORS["cream"], (WIDTH // 2, 286))
        self._button("JOGAR", (WIDTH // 2, 377))
        self._button("COMO JOGAR", (WIDTH // 2, 447))
        self._button("SAIR", (WIDTH // 2, 517))
        self._text("ENTER: jogar   H: ajuda   M: áudio   F11: tela cheia", self.font_small, (156, 183, 166), (WIDTH // 2, 590))

    def _draw_instructions(self) -> None:
        self._draw_background()
        panel = pygame.Rect(120, 65, 720, 500)
        pygame.draw.rect(self.screen, COLORS["panel"], panel, border_radius=24)
        pygame.draw.rect(self.screen, COLORS["mint"], panel, 3, border_radius=24)
        self._text("COMO JOGAR", self.font_large, COLORS["mint"], (WIDTH // 2, 120))
        lines = [
            ("OBJETIVO", "Resgate os 6 vaga-lumes antes que o tempo acabe."),
            ("MOVER", "WASD ou setas direcionais"),
            ("INTERAGIR", "E, quando estiver perto de um vaga-lume"),
            ("CORRER", "SHIFT ou ESPAÇO (possui recarga)"),
            ("PAUSAR", "P ou ESC durante a partida"),
            ("ATENÇÃO", "Evite os javalis: cada colisão remove um coração."),
        ]
        y = 190
        for title, description in lines:
            self._text(title, self.font_small, COLORS["gold"], (180, y), "midleft")
            self._text(description, self.font_small, COLORS["cream"], (335, y), "midleft")
            y += 52
        self._button("COMEÇAR", (WIDTH // 2, 562))

    def _draw_overlay(self, title: str, subtitle: str) -> None:
        veil = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
        veil.fill((3, 20, 18, 195))
        self.screen.blit(veil, (0, 0))
        panel = pygame.Rect(230, 165, 500, 300)
        pygame.draw.rect(self.screen, COLORS["panel"], panel, border_radius=24)
        pygame.draw.rect(self.screen, COLORS["mint"], panel, 3, border_radius=24)
        self._text(title, self.font_large, COLORS["mint"], (WIDTH // 2, 235))
        self._text(subtitle, self.font_small, COLORS["cream"], (WIDTH // 2, 295))

    def _draw_paused(self) -> None:
        self._draw_world()
        self._draw_overlay("PAUSADO", "P/ESC: continuar   R: reiniciar   Q: menu")

    def _draw_result(self) -> None:
        self._draw_world()
        won = self.state.result is RoundResult.WON
        title = "FLORESTA EM HARMONIA!" if won else "A NOITE CHEGOU"
        subtitle = "Todos os vaga-lumes estão seguros." if won else "Tente outra rota e proteja seus corações."
        veil = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
        veil.fill((3, 20, 18, 205))
        self.screen.blit(veil, (0, 0))
        panel = pygame.Rect(200, 105, 560, 485)
        pygame.draw.rect(self.screen, COLORS["panel"], panel, border_radius=24)
        pygame.draw.rect(self.screen, COLORS["gold"] if won else COLORS["red"], panel, 3, border_radius=24)
        self._text(title, self.font_medium, COLORS["gold"] if won else COLORS["red"], (WIDTH // 2, 170))
        self._text(subtitle, self.font_small, COLORS["cream"], (WIDTH // 2, 218))
        self._text(f"PONTUAÇÃO  {self.state.score}", self.font_large, COLORS["white"], (WIDTH // 2, 305))
        self._text(
            f"Resgates: {self.state.rescued}/{self.state.total_fireflies}   Corações: {self.state.health}",
            self.font_small,
            COLORS["cream"],
            (WIDTH // 2, 360),
        )
        self._button("JOGAR NOVAMENTE", (WIDTH // 2, 485))
        self._button("MENU PRINCIPAL", (WIDTH // 2, 555))

    def draw(self) -> None:
        if self.scene is Scene.MENU:
            self._draw_menu()
        elif self.scene is Scene.INSTRUCTIONS:
            self._draw_instructions()
        elif self.scene is Scene.PLAYING:
            self._draw_world()
        elif self.scene is Scene.PAUSED:
            self._draw_paused()
        elif self.scene is Scene.RESULT:
            self._draw_result()
        pygame.display.flip()

    def run(self, screenshot: Path | None = None, smoke_test: bool = False) -> int:
        if screenshot or smoke_test:
            if smoke_test:
                self.scene = Scene.PLAYING
                self.update(1 / FPS)
            self.draw()
            if screenshot:
                screenshot.parent.mkdir(parents=True, exist_ok=True)
                pygame.image.save(self.screen, screenshot)
            pygame.quit()
            return 0
        while self.running:
            delta_time = min(self.clock.tick(FPS) / 1000.0, 0.05)
            self.handle_events()
            self.update(delta_time)
            self.draw()
        pygame.quit()
        return 0
