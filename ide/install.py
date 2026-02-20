#!/usr/bin/env python3
"""
Rockit Editor Support — Universal Installer with Cinematic Moon Mission
Dark Matter Tech

Usage:
    curl -fsSL https://rustygits.com/Dark-Matter/moon/raw/branch/develop/ide/install.py | python3
    python3 ide/install.py
"""

import atexit
import math
import os
import platform
import random
import shutil
import signal
import subprocess
import sys
import time
import zipfile
from pathlib import Path

# ═══════════════════════════════════════════════════════════════════════
# ANSI
# ═══════════════════════════════════════════════════════════════════════

ESC = "\033"
HIDE_CURSOR = f"{ESC}[?25l"
SHOW_CURSOR = f"{ESC}[?25h"
CLEAR_SCREEN = f"{ESC}[2J{ESC}[H"
ALT_SCREEN_ON = f"{ESC}[?1049h"
ALT_SCREEN_OFF = f"{ESC}[?1049l"

RED = f"{ESC}[0;31m"
GREEN = f"{ESC}[0;32m"
YELLOW = f"{ESC}[0;33m"
BLUE = f"{ESC}[0;34m"
MAGENTA = f"{ESC}[0;35m"
CYAN = f"{ESC}[0;36m"
WHITE = f"{ESC}[1;37m"
GRAY = f"{ESC}[0;90m"
BOLD = f"{ESC}[1m"
DIM = f"{ESC}[2m"
RESET = f"{ESC}[0m"

BRED = f"{ESC}[1;31m"
BGREEN = f"{ESC}[1;32m"
BYELLOW = f"{ESC}[1;33m"
BCYAN = f"{ESC}[1;36m"
BBLUE = f"{ESC}[1;34m"
BWHITE = f"{ESC}[1;37m"
BMAGENTA = f"{ESC}[1;35m"

FPS = 15
FRAME_TIME = 1.0 / FPS


def _write(s):
    sys.stdout.write(s)
    sys.stdout.flush()


def restore_terminal():
    _write(SHOW_CURSOR + ALT_SCREEN_OFF)


atexit.register(restore_terminal)
signal.signal(signal.SIGINT, lambda *_: (restore_terminal(), sys.exit(1)))


# ═══════════════════════════════════════════════════════════════════════
# Math Helpers
# ═══════════════════════════════════════════════════════════════════════

def ease_out(t):
    """Cubic ease-out: fast start, gentle landing."""
    return 1.0 - (1.0 - min(max(t, 0), 1)) ** 3


def ease_in_out(t):
    """Smooth S-curve."""
    t = min(max(t, 0), 1)
    return 4 * t * t * t if t < 0.5 else 1 - (-2 * t + 2) ** 3 / 2


def lerp(a, b, t):
    return a + (b - a) * t


# ═══════════════════════════════════════════════════════════════════════
# Screen Buffer
# ═══════════════════════════════════════════════════════════════════════

class Screen:
    def __init__(self, w=80, h=40):
        self.w = w
        self.h = h
        self.cells = [' '] * (w * h)
        self.fg = [''] * (w * h)
        self.prev_lines = [None] * h

    def clear(self, ch=' ', color=''):
        for i in range(self.w * self.h):
            self.cells[i] = ch
            self.fg[i] = color

    def invalidate(self):
        self.prev_lines = [None] * self.h

    def put(self, x, y, ch, color=''):
        x, y = int(x), int(y)
        if 0 <= x < self.w and 0 <= y < self.h:
            idx = y * self.w + x
            self.cells[idx] = ch
            self.fg[idx] = color

    def text(self, x, y, s, color=''):
        for i, ch in enumerate(s):
            self.put(x + i, y, ch, color)

    def draw_sprite(self, x, y, sprite):
        """Transparent spaces."""
        lines = sprite['lines']
        colors = sprite.get('colors', [])
        for dy, line in enumerate(lines):
            row_colors = colors[dy] if dy < len(colors) else []
            for dx, ch in enumerate(line):
                if ch == ' ':
                    continue
                color = ''
                for cs, ce, cc in row_colors:
                    if cs <= dx < ce:
                        color = cc
                self.put(x + dx, y + dy, ch, color or WHITE)

    def draw_sprite_solid(self, x, y, sprite):
        """Opaque interior — fills between leftmost/rightmost chars per row."""
        lines = sprite['lines']
        colors = sprite.get('colors', [])
        for dy, line in enumerate(lines):
            left, right = -1, -1
            for dx, ch in enumerate(line):
                if ch != ' ':
                    if left < 0:
                        left = dx
                    right = dx
            if left >= 0:
                for dx in range(left, right + 1):
                    self.put(x + dx, y + dy, ' ', '')
        for dy, line in enumerate(lines):
            row_colors = colors[dy] if dy < len(colors) else []
            for dx, ch in enumerate(line):
                if ch == ' ':
                    continue
                color = ''
                for cs, ce, cc in row_colors:
                    if cs <= dx < ce:
                        color = cc
                self.put(x + dx, y + dy, ch, color or WHITE)

    def hline(self, x, y, length, ch='=', color=''):
        for i in range(length):
            self.put(x + i, y, ch, color)

    def render(self):
        for row in range(self.h):
            parts = []
            cur_color = None
            for col in range(self.w):
                idx = row * self.w + col
                ch = self.cells[idx]
                color = self.fg[idx]
                if color != cur_color:
                    parts.append(color if color else RESET)
                    cur_color = color
                parts.append(ch)
            parts.append(RESET)
            line = ''.join(parts)
            if line != self.prev_lines[row]:
                _write(f"{ESC}[{row + 1};1H{line}{ESC}[K")
                self.prev_lines[row] = line


def frame_sleep(t_start):
    elapsed = time.time() - t_start
    remaining = FRAME_TIME - elapsed
    if remaining > 0:
        time.sleep(remaining)


# ═══════════════════════════════════════════════════════════════════════
# Drawing Helpers
# ═══════════════════════════════════════════════════════════════════════

def generate_star_map(w, h, density=80, seed=42):
    rng = random.Random(seed)
    stars = []
    for _ in range(density):
        x = rng.randint(0, w - 1)
        y = rng.randint(0, h - 1)
        r = rng.random()
        if r < 0.55:
            ch, col = '.', DIM
        elif r < 0.75:
            ch, col = '+', GRAY
        elif r < 0.90:
            ch, col = '*', GRAY
        else:
            ch, col = '*', WHITE
        stars.append((x, y, ch, col))
    return stars


def draw_stars(screen, star_map, frame):
    for x, y, ch, col in star_map:
        # Twinkle: occasionally skip a star
        if (x * 3 + y * 7 + frame) % 11 == 0:
            continue
        # Occasionally brighten
        c = WHITE if (x * 7 + y * 3 + frame) % 37 == 0 else col
        screen.put(x, y, ch, c)


def draw_panel(screen, x, y, w, lines, border_color=DIM, text_color=WHITE):
    """Draw a box-bordered panel with text lines."""
    screen.text(x, y, '\u250c' + '\u2500' * (w - 2) + '\u2510', border_color)
    for i, line in enumerate(lines):
        padded = line[:w - 4].ljust(w - 4)
        screen.text(x, y + 1 + i, '\u2502 ' + padded + ' \u2502', border_color)
        # Overwrite text content with text_color
        screen.text(x + 2, y + 1 + i, padded, text_color)
    screen.text(x, y + 1 + len(lines), '\u2514' + '\u2500' * (w - 2) + '\u2518', border_color)


def draw_ground(screen, y, color=GREEN):
    if 0 <= y < screen.h:
        screen.hline(0, y, screen.w, '\u2550', color)
        # Launch pad
        for dx in range(32, 48):
            screen.put(dx, y, '\u2593', GRAY)
        # Pad markings
        screen.put(35, y, '[', BYELLOW)
        screen.put(44, y, ']', BYELLOW)


def draw_lunar_surface(screen, y, max_x=80):
    if y >= screen.h:
        return
    # Terrain line with craters
    terrain = "\u2584\u2584\u2584\u2584.  .\u2584\u2584\u2584\u2584\u2584.    .\u2584\u2584\u2584/\\\u2584\u2584\u2584.\u2584\u2584\u2584\u2584.  .\u2584\u2584\u2584\u2584.    .\u2584\u2584\u2584\u2584\u2584. .\u2584\u2584\u2584.\u2584\u2584\u2584\u2584.  .\u2584\u2584\u2584\u2584"
    for i, ch in enumerate(terrain[:max_x]):
        if ch != ' ':
            screen.put(i, y, ch, GRAY)
    # Regolith fill
    rng = random.Random(y * 1000)
    for dy in range(1, min(10, screen.h - y)):
        for dx in range(max_x):
            r = rng.random()
            if r < 0.06:
                screen.put(dx, y + dy, 'o', GRAY)
            elif r < 0.15:
                screen.put(dx, y + dy, '.', GRAY)
            elif r < 0.18:
                screen.put(dx, y + dy, '\u00b7', DIM)


def draw_cloud(screen, x, y, variant=0):
    clouds = [
        ["  .---.", " '     '", "  `---'"],
        [" .-.", "'   '", " `-'"],
        ["  .----.", " '      '", "  `----'"],
    ]
    c = clouds[variant % len(clouds)]
    for dy, line in enumerate(c):
        for dx, ch in enumerate(line):
            if ch != ' ':
                screen.put(int(x) + dx, int(y) + dy, ch, WHITE)


# ═══════════════════════════════════════════════════════════════════════
# Sprites
# ═══════════════════════════════════════════════════════════════════════

ROCKET_FULL = {
    'lines': [
        '     /\\',           # 0
        '    /  \\',          # 1
        '   / ** \\',         # 2
        '  /  **  \\',        # 3
        ' /________\\',       # 4
        ' |  [  ]  |',       # 5
        ' |  [  ]  |',       # 6
        ' |________|',       # 7
        ' |  *..*  |',       # 8
        ' |  *..*  |',       # 9
        ' |  *..*  |',       # 10
        ' |________|',       # 11
        '/|   ||   |\\',     # 12
        '/ |  ||  | \\',     # 13
        '/_|__||__|_\\',     # 14
        '  |__||__|',        # 15
        '     ||',           # 16
        '    /  \\',         # 17
        '   /    \\',        # 18
        "  '------'",        # 19
    ],
    'colors': [
        [(5, 7, BRED)],
        [(4, 8, BRED)],
        [(3, 9, WHITE), (5, 7, BYELLOW)],
        [(2, 10, WHITE), (5, 7, BYELLOW)],
        [(1, 11, WHITE)],
        [(1, 11, WHITE), (4, 8, CYAN)],
        [(1, 11, WHITE), (4, 8, CYAN)],
        [(1, 11, WHITE)],
        [(1, 11, WHITE), (4, 5, BRED), (5, 7, BBLUE), (7, 8, BRED)],
        [(1, 11, WHITE), (4, 5, BRED), (5, 7, BBLUE), (7, 8, BRED)],
        [(1, 11, WHITE), (4, 5, BRED), (5, 7, BBLUE), (7, 8, BRED)],
        [(1, 11, WHITE)],
        [(0, 12, GRAY), (5, 7, WHITE)],
        [(0, 12, GRAY), (5, 7, WHITE)],
        [(0, 12, GRAY), (5, 7, WHITE)],
        [(2, 10, GRAY), (5, 7, WHITE)],
        [(5, 7, GRAY)],
        [(4, 8, BYELLOW)],
        [(3, 9, BYELLOW)],
        [(2, 10, BYELLOW)],
    ],
}

EXHAUST_FRAMES = [
    {'lines': [
        "    \\  /",
        "     \\/",
        "      .",
    ], 'colors': [
        [(4, 8, BYELLOW)],
        [(5, 7, BYELLOW)],
        [(6, 7, YELLOW)],
    ]},
    {'lines': [
        "    \\  /",
        "     \\/",
        "    '..'",
        "      .",
    ], 'colors': [
        [(4, 8, BYELLOW)],
        [(5, 7, BYELLOW)],
        [(4, 8, YELLOW)],
        [(6, 7, DIM)],
    ]},
    {'lines': [
        "    \\  /",
        "     ><",
        "  .:|  |:.",
        " '::    ::'",
        "  '::  ::'",
        "    '::'",
        "      .",
    ], 'colors': [
        [(4, 8, BYELLOW)],
        [(5, 7, BYELLOW)],
        [(2, 10, YELLOW), (4, 8, BYELLOW)],
        [(1, 11, YELLOW), (3, 9, BRED)],
        [(2, 10, YELLOW), (4, 8, BRED)],
        [(4, 8, YELLOW), (5, 7, BRED)],
        [(6, 7, DIM)],
    ]},
    {'lines': [
        "    \\  /",
        "     ><",
        " .::|  |::.",
        "':::    :::'",
        " '::    ::'",
        "  '::  ::'",
        "    '::'",
        "      .",
    ], 'colors': [
        [(4, 8, BYELLOW)],
        [(5, 7, BYELLOW)],
        [(1, 11, YELLOW), (4, 8, BYELLOW)],
        [(0, 12, YELLOW), (1, 11, BRED)],
        [(1, 11, YELLOW), (3, 9, BRED)],
        [(2, 10, YELLOW), (4, 8, BRED)],
        [(4, 8, YELLOW), (5, 7, BRED)],
        [(6, 7, DIM)],
    ]},
]

ROCKET_MEDIUM = {
    'lines': [
        '  /\\', ' /  \\', '/____\\', '|[  ]|', '|*..*|',
        '|____|', '/|  |\\', '/_||_\\', ' |__|', ' /  \\', "'----'",
    ],
    'colors': [
        [(2, 4, BRED)], [(1, 5, BRED)], [(0, 6, WHITE)],
        [(0, 6, WHITE), (1, 5, CYAN)],
        [(0, 6, WHITE), (1, 2, BRED), (2, 4, BBLUE), (4, 5, BRED)],
        [(0, 6, WHITE)], [(0, 6, GRAY), (2, 4, WHITE)],
        [(0, 6, GRAY), (2, 4, WHITE)], [(1, 5, GRAY)],
        [(1, 5, BYELLOW)], [(0, 6, BYELLOW)],
    ],
}

ROCKET_SMALL = {
    'lines': [' /\\', '/  \\', '|[]|', '|..|', '/  \\', "'--'"],
    'colors': [
        [(1, 3, BRED)], [(0, 4, WHITE)], [(0, 4, WHITE), (1, 3, CYAN)],
        [(0, 4, WHITE), (1, 3, BBLUE)], [(0, 4, BYELLOW)], [(0, 4, BYELLOW)],
    ],
}

ROCKET_TINY = {
    'lines': ['/\\', '||', '\\/'],
    'colors': [[(0, 2, BRED)], [(0, 2, WHITE)], [(0, 2, BYELLOW)]],
}


ROCKET_LANDED = {
    'lines': [
        '     /\\', '    /  \\', '   / ** \\', '  /  **  \\',
        ' /________\\', ' |  [  ]  |', ' |  [  ]  |', ' |________|',
        ' |  *..*  |', ' |  *..*  |', ' |________|',
        '/|   ||   |\\', '/_|__||__|_\\',
        ' /   ||   \\', '/    ||    \\', '/====||====\\',
    ],
    'colors': [
        [(5, 7, BRED)], [(4, 8, BRED)],
        [(3, 9, WHITE), (5, 7, BYELLOW)], [(2, 10, WHITE), (5, 7, BYELLOW)],
        [(1, 11, WHITE)], [(1, 11, WHITE), (4, 8, CYAN)],
        [(1, 11, WHITE), (4, 8, CYAN)], [(1, 11, WHITE)],
        [(1, 11, WHITE), (4, 5, BRED), (5, 7, BBLUE), (7, 8, BRED)],
        [(1, 11, WHITE), (4, 5, BRED), (5, 7, BBLUE), (7, 8, BRED)],
        [(1, 11, WHITE)],
        [(0, 12, GRAY), (5, 7, WHITE)], [(0, 12, GRAY), (5, 7, WHITE)],
        [(1, 11, GRAY), (5, 7, WHITE)], [(0, 12, GRAY), (5, 7, WHITE)],
        [(0, 12, GRAY), (5, 7, WHITE)],
    ],
}

AMERICAN_FLAG = {
    'lines': [
        ' ________', '|*  =====|', '| * =====|', '|*  =====|',
        '|========|', '|________|', '   ||', '   ||',
    ],
    'colors': [
        [(1, 9, WHITE)],
        [(0, 1, WHITE), (1, 4, BBLUE), (4, 9, BRED), (9, 10, WHITE)],
        [(0, 1, WHITE), (1, 4, BBLUE), (4, 9, BRED), (9, 10, WHITE)],
        [(0, 1, WHITE), (1, 4, BBLUE), (4, 9, BRED), (9, 10, WHITE)],
        [(0, 1, WHITE), (1, 9, BRED), (9, 10, WHITE)],
        [(0, 10, WHITE)], [(3, 5, GRAY)], [(3, 5, GRAY)],
    ],
}

EARTH_LARGE = {
    'lines': [
        '           .------.',
        "         .'   ##   '.",
        "       .'  #####  #  '.",
        "      / ##  #####      \\",
        "     |    #####    ##   |",
        "     |  ##  ###  ##     |",
        "      \\  ###    ##     /",
        "       '.    ###     .'",
        "         '----------'",
    ],
    'colors': [
        [(11, 19, BCYAN)],
        [(9, 21, BCYAN), (14, 16, GREEN)],
        [(7, 23, BCYAN), (11, 16, GREEN), (18, 19, GREEN)],
        [(6, 24, BCYAN), (8, 10, GREEN), (12, 17, GREEN)],
        [(5, 25, BCYAN), (10, 15, GREEN), (19, 21, GREEN)],
        [(5, 25, BCYAN), (8, 10, GREEN), (12, 15, GREEN), (17, 19, GREEN)],
        [(6, 24, BCYAN), (9, 12, GREEN), (16, 18, GREEN)],
        [(7, 23, BCYAN), (13, 16, GREEN)],
        [(9, 21, BCYAN)],
    ],
}

EARTH_SMALL = {
    'lines': [' _._', '/~ \\', '|~~|', '\\__/'],
    'colors': [
        [(1, 4, BCYAN)], [(0, 4, BCYAN), (1, 2, GREEN)],
        [(0, 4, BCYAN), (1, 3, GREEN)], [(0, 4, BCYAN)],
    ],
}

MOON_SMALL = {
    'lines': [' _ ', '(o)', " ' "],
    'colors': [[(1, 2, BYELLOW)], [(0, 3, BYELLOW)], [(1, 2, BYELLOW)]],
}

MOON_LARGE = {
    'lines': [
        '      ___', '    /     \\', '   |  o    |',
        '   |    o  |', '   | o     |', '    \\_____/',
    ],
    'colors': [
        [(6, 9, BYELLOW)], [(4, 11, BYELLOW)], [(3, 12, BYELLOW)],
        [(3, 12, BYELLOW)], [(3, 12, BYELLOW)], [(4, 11, BYELLOW)],
    ],
}

# Block-letter digits for countdown
BLOCK_DIGITS = {
    '3': [' \u2588\u2588\u2588\u2588 ', '     \u2588', ' \u2588\u2588\u2588\u2588 ', '     \u2588', ' \u2588\u2588\u2588\u2588 '],
    '2': [' \u2588\u2588\u2588\u2588 ', '     \u2588', ' \u2588\u2588\u2588\u2588 ', ' \u2588    ', ' \u2588\u2588\u2588\u2588\u2588'],
    '1': ['   \u2588\u2588 ', '  \u2588\u2588\u2588 ', '   \u2588\u2588 ', '   \u2588\u2588 ', ' \u2588\u2588\u2588\u2588\u2588'],
}



def _generate_earth_surface(w=80, h=200):
    """Pre-compute scrollable Earth surface with recognizable continents.

    Map tiles every 50 rows. Columns: 0=180W, 20=90W, 40=0(Greenwich), 60=90E, 80=180E.
    Rows: 0=~70N, 25=equator, 50=~70S.
    """
    period = 50
    # Continent shapes as (center_x, center_y, radius_x, radius_y) ellipses
    continents = [
        # North America
        (14, 10, 8, 9),
        (9, 5, 5, 3),       # Alaska / N Canada
        (19, 7, 3, 3),      # East coast / Labrador
        (10, 18, 3, 3),     # Mexico
        (8, 20, 1, 2),      # Central America
        # South America
        (20, 28, 4, 8),
        (18, 25, 3, 3),     # Venezuela / Colombia
        (19, 22, 1, 2),     # Isthmus
        # Europe
        (41, 9, 5, 4),
        (37, 7, 2, 2),      # Britain
        (44, 5, 2, 3),      # Scandinavia
        # Africa
        (45, 25, 6, 10),
        (43, 18, 5, 4),     # N Africa / Sahara
        # Asia
        (58, 9, 12, 7),     # Main mass
        (65, 4, 6, 3),      # N Siberia
        (53, 17, 3, 4),     # India
        (63, 12, 4, 4),     # E China
        (68, 10, 2, 3),     # Japan
        (50, 14, 3, 3),     # Middle East
        # SE Asia / Oceania
        (64, 22, 3, 2),
        (67, 35, 5, 3),     # Australia
    ]

    surface = []
    for y in range(h):
        row = []
        my = y % period
        for x in range(w):
            min_d = 999.0
            for cx, cy, rx, ry in continents:
                dx = abs(x - cx)
                if dx > w // 2:
                    dx = w - dx
                dy = abs(my - cy)
                if dy > period // 2:
                    dy = period - dy
                d = (dx / max(rx, 0.1)) ** 2 + (dy / max(ry, 0.1)) ** 2
                if d < min_d:
                    min_d = d
            # Coastline noise for irregular edges
            noise = (math.sin(x * 0.5 + my * 0.7) * 0.15 +
                     math.sin(x * 1.3 - my * 0.4) * 0.1)
            min_d += noise

            if min_d < 0.65:
                row.append(('#', GREEN))
            elif min_d < 1.0:
                row.append(('.', GREEN))
            elif min_d < 1.4:
                row.append(('~', BCYAN))
            else:
                row.append(('\u2248', BLUE))
        surface.append(row)
    return surface


EARTH_SURFACE = _generate_earth_surface()


def _generate_clouds(w=80, h=200):
    """Pre-compute cloud layer — light wisps, not solid blocks."""
    clouds = []
    for y in range(h):
        row = []
        for x in range(w):
            v = (math.sin(x * 0.06 + y * 0.04) +
                 math.sin(x * 0.1 - y * 0.06))
            if v > 1.55:
                row.append('~')
            elif v > 1.4:
                row.append('.')
            else:
                row.append(None)
        clouds.append(row)
    return clouds


CLOUD_LAYER = _generate_clouds()


def draw_earth_topdown(screen, scroll, cloud_offset):
    """Draw scrolling Earth surface from orbit (top-down satellite view).
    Terrain scrolls downward so rocket (nose-up) flies in direction of travel."""
    for y in range(40):
        wy = (y - scroll) % 200
        for x in range(80):
            ch, col = EARTH_SURFACE[wy][x]
            screen.put(x, y, ch, col)
    # Cloud layer (parallax — scrolls slower, light white wisps)
    for y in range(40):
        wy = (y - cloud_offset) % 200
        for x in range(80):
            c = CLOUD_LAYER[wy][x]
            if c is not None:
                screen.put(x, y, c, WHITE)





# ═══════════════════════════════════════════════════════════════════════
# Scene Functions
# ═══════════════════════════════════════════════════════════════════════

STAR_MAP = generate_star_map(80, 40, density=80)


def scene_prelaunch(screen, editor_labels):
    """Rocket on pad with service tower. Title panel. Editor targets listed."""
    screen.invalidate()
    rocket_x, rocket_y = 34, 13
    ground_y = 33

    for f in range(55):
        t0 = time.time()
        screen.clear()
        draw_stars(screen, STAR_MAP, f)
        draw_ground(screen, ground_y)

        # Service tower (left of rocket)
        for ty in range(10, ground_y):
            screen.put(30, ty, '\u2502', GRAY)
            screen.put(31, ty, '\u2502', GRAY)
        screen.text(29, 10, '\u250c\u2500\u2500\u2510', GRAY)
        # Support arms
        if rocket_y + 5 < ground_y:
            screen.text(32, rocket_y + 5, '\u2500\u2500', GRAY)
            screen.text(32, rocket_y + 8, '\u2500\u2500', GRAY)

        screen.draw_sprite_solid(rocket_x, rocket_y, ROCKET_FULL)

        # Title panel (upper right)
        title_lines = [
            '',
            '  R O C K I T',
            '',
            '  Editor Support',
            '  Dark Matter Tech',
            '',
        ]
        draw_panel(screen, 50, 2, 28, title_lines, DIM, WHITE)

        # Status
        if f < 15:
            screen.text(52, 11, '\u25b8 Fueling up...', YELLOW)
        elif f < 30:
            screen.text(52, 11, '\u25b8 Systems check...', YELLOW)
        else:
            screen.text(52, 11, '\u2713 All systems go!', BGREEN)
            for i, label in enumerate(editor_labels):
                if f > 32 + i * 4:
                    screen.text(54, 13 + i, f'\u25b8 {label}', CYAN)

        screen.text(64, 0, 'PRE-LAUNCH', DIM)
        screen.render()
        frame_sleep(t0)


def scene_countdown(screen):
    """Giant block-number countdown with ignition flash."""
    screen.invalidate()
    rocket_x, rocket_y = 34, 13
    ground_y = 33

    for digit in ['3', '2', '1']:
        digit_lines = BLOCK_DIGITS[digit]
        for f in range(12):
            t0 = time.time()
            screen.clear()
            draw_stars(screen, STAR_MAP, 80 + f)
            draw_ground(screen, ground_y)
            screen.draw_sprite_solid(rocket_x, rocket_y, ROCKET_FULL)

            # Draw large block digit (right of rocket)
            for dy, line in enumerate(digit_lines):
                screen.text(54, 16 + dy, line, BYELLOW)

            screen.text(64, 0, 'COUNTDOWN', DIM)
            screen.render()
            frame_sleep(t0)

    # LIFTOFF! with screen flash
    # Flash white
    for f in range(2):
        t0 = time.time()
        screen.clear('\u2588', BWHITE)
        screen.render()
        frame_sleep(t0)

    # LIFTOFF text with shake
    for f in range(18):
        t0 = time.time()
        screen.clear()
        draw_stars(screen, STAR_MAP, 120 + f)
        draw_ground(screen, ground_y)

        rx = rocket_x + random.choice([-1, 0, 1])
        screen.draw_sprite_solid(rx, rocket_y, ROCKET_FULL)

        # Growing exhaust
        ei = min(f // 4, 3)
        screen.draw_sprite(rocket_x, rocket_y + 20, EXHAUST_FRAMES[ei])

        # Smoke at base
        rng = random.Random(f)
        for _ in range(f * 2):
            sx = 30 + rng.randint(0, 20)
            sy = ground_y + rng.choice([-1, 0])
            screen.put(sx, sy, rng.choice(['.', ':', '\u2591', '\u2592']), GRAY)

        screen.text(52, 17, 'L I F T O F F !', BRED)
        screen.text(64, 0, 'COUNTDOWN', DIM)
        screen.render()
        frame_sleep(t0)


def scene_launch(screen):
    """Rocket rises through atmosphere. Clouds, parallax, easing."""
    screen.invalidate()
    rocket_x = 34
    rocket_y = 13.0
    ground_y = 33.0
    cloud_positions = [(8, 26), (55, 30), (22, 23), (65, 21), (40, 27)]

    for f in range(60):
        t0 = time.time()
        screen.clear()

        # Sky gets darker as we ascend (fewer stars early, more later)
        draw_stars(screen, STAR_MAP, 130 + f)

        # Ground drops with ease-out
        t = f / 60.0
        ground_y = 33.0 + 40.0 * ease_out(t)
        if int(ground_y) < 45:
            draw_ground(screen, int(ground_y))

        # Smoke cloud lingers on pad
        if f < 25 and int(ground_y) < 42:
            rng = random.Random(f + 200)
            gy = int(ground_y)
            for _ in range(max(0, 20 - f)):
                sx = 28 + rng.randint(0, 24)
                sy = gy + rng.randint(-2, 0)
                if 0 <= sy < 40:
                    screen.put(sx, sy, rng.choice(['\u2591', '\u2592', '.', ':']), GRAY)

        # Clouds scroll down (parallax)
        for i, (cx, cy) in enumerate(cloud_positions):
            cloud_y = cy + f * (0.5 + i * 0.15)
            if 0 <= cloud_y < 38:
                draw_cloud(screen, cx, cloud_y, i)

        # Rocket rises with acceleration
        vel = 0.1 + 0.8 * ease_out(t)
        rocket_y -= vel
        ry = int(rocket_y)

        # Exhaust
        ex_idx = min(2 + (f % 2), 3)
        screen.draw_sprite(rocket_x, ry + 20, EXHAUST_FRAMES[ex_idx])
        screen.draw_sprite_solid(rocket_x, ry, ROCKET_FULL)

        screen.text(70, 0, 'LAUNCH', DIM)
        screen.render()
        frame_sleep(t0)


def scene_orbit_install(screen, targets, install_fn):
    """Orbital flight: Earth surface scrolling below, capsule flying right."""
    screen.invalidate()
    installed = []
    num = len(targets)
    total_frames = max(70, num * 15 + 30)
    interval = max(12, (total_frames - 20) // max(num, 1))
    next_install = 15

    for f in range(total_frames):
        t0 = time.time()

        if f == next_install and len(installed) < num:
            result = install_fn(targets[len(installed)])
            if result:
                installed.append(result)
            next_install += interval

        screen.clear()

        # Scrolling Earth surface fills the screen
        scroll = int(f * 0.7)
        cloud_off = int(f * 0.3)
        draw_earth_topdown(screen, scroll, cloud_off)

        # Rocket over terrain
        screen.draw_sprite_solid(37, 14, ROCKET_MEDIUM)

        # Phase label
        screen.text(63, 0, 'EARTH ORBIT', DIM)

        # Install status panel (upper right — room for many editors)
        if installed:
            panel_lines = ['  Installing...', '']
            for name in installed:
                panel_lines.append(f'  \u2713 {name}')
            if len(installed) == num:
                panel_lines[0] = '  All installed!'
            panel_lines.append('')
            draw_panel(screen, 50, 2, 28, panel_lines, DIM, GREEN)

        screen.render()
        frame_sleep(t0)

    return installed


def scene_tli(screen, installed):
    """TLI burn. Rocket flying upward with exhaust below, vertical star streaks."""
    screen.invalidate()

    for f in range(50):
        t0 = time.time()
        screen.clear()
        draw_stars(screen, STAR_MAP, 250 + f)

        # Vertical star streaks (falling downward = rocket flying up fast)
        rng = random.Random(f + 500)
        streak_count = min(f // 3, 10)
        for _ in range(streak_count):
            sx = rng.randint(0, 79)
            sy = rng.randint(0, 35)
            length = rng.randint(2, 3 + f // 6)
            for dy in range(length):
                if 0 <= sy + dy < 40:
                    screen.put(sx, sy + dy, '\u2502', DIM)

        # Earth below (shrinking as we leave)
        t = f / 50.0
        if t < 0.2:
            screen.draw_sprite_solid(30, 34, EARTH_SMALL)
        elif t < 0.45:
            screen.put(35, 38, 'o', BCYAN)
        elif t < 0.65:
            screen.put(35, 39, '.', BCYAN)

        # Rocket flying upward (nose up) — centered on screen
        rx, ry = 34, 2
        screen.draw_sprite_solid(rx, ry, ROCKET_FULL)

        # Exhaust below rocket (engine bell at row 19 of sprite)
        ei = min(2 + (f % 2), 3)
        screen.draw_sprite(rx, ry + 20, EXHAUST_FRAMES[ei])

        screen.text(66, 0, 'TLI BURN', DIM)
        screen.render()
        frame_sleep(t0)


def scene_lunar_approach(screen, installed):
    """Moon grows above, rocket shrinks rising toward it."""
    screen.invalidate()

    for f in range(45):
        t0 = time.time()
        screen.clear()
        draw_stars(screen, STAR_MAP, 290 + f)

        # Earth dot behind us
        if f < 20:
            screen.draw_sprite_solid(35, 35, EARTH_SMALL)
        elif f < 35:
            screen.put(37, 38, 'o', BCYAN)
        else:
            screen.put(38, 39, '.', BCYAN)

        # Moon grows from top
        if f < 12:
            screen.draw_sprite(37, 2, MOON_SMALL)
        elif f < 30:
            my = max(1, 4 - (f - 12) // 6)
            screen.draw_sprite_solid(28, my, MOON_LARGE)
        else:
            screen.draw_sprite_solid(25, 1, MOON_LARGE)

        # Rocket rises toward moon and shrinks
        if f < 15:
            ry = 22 - int(f * 0.5)
            screen.draw_sprite_solid(34, ry, ROCKET_FULL)
            screen.draw_sprite(34, ry + 20, EXHAUST_FRAMES[f % 2])
        elif f < 28:
            ry = 14 - int((f - 15) * 0.3)
            screen.draw_sprite_solid(35, ry, ROCKET_MEDIUM)
        elif f < 38:
            ry = 10 - int((f - 28) * 0.2)
            screen.draw_sprite_solid(36, ry, ROCKET_SMALL)
        else:
            ry = max(2, 8 - int((f - 38) * 0.3))
            screen.draw_sprite(37, ry, ROCKET_TINY)

        screen.text(58, 0, 'LUNAR APPROACH', DIM)
        screen.render()
        frame_sleep(t0)


def scene_descent(screen, installed):
    """Retro-thrust descent. Surface rises to meet rocket. Dust on contact."""
    screen.invalidate()
    surface_y = 48.0
    rocket_y = -5.0

    for f in range(55):
        t0 = time.time()
        screen.clear()
        draw_stars(screen, STAR_MAP, 330 + f)

        surface_y -= 0.3
        sy = int(surface_y)

        # Rocket descends with deceleration (ease-out)
        t = f / 55.0
        if t < 0.3:
            rocket_y += 0.55
        elif t < 0.6:
            rocket_y += 0.30
        elif t < 0.85:
            rocket_y += 0.12
        else:
            rocket_y += 0.02
        ry = int(rocket_y)

        if ry + 20 > sy:
            ry = sy - 20

        if sy < 42:
            draw_lunar_surface(screen, sy)

        # Dust on touchdown (drawn before rocket so rocket renders on top)
        if f > 49 and sy < 40:
            spread = (f - 49) * 3
            rng = random.Random(f)
            for _ in range(spread):
                dx = rng.randint(-spread, spread)
                px = 40 + dx
                if 0 <= px < 80:
                    screen.put(px, sy - 1, rng.choice(['.', '\u00b7']), GRAY)

        # Retro-thrust
        if f < 50 and ry + 20 < sy:
            ei = 2 + (f % 2)
            screen.draw_sprite(34, ry + 20, EXHAUST_FRAMES[ei])

        screen.draw_sprite_solid(34, ry, ROCKET_FULL)

        screen.text(69, 0, 'DESCENT', DIM)
        screen.render()
        frame_sleep(t0)

    # Brief shake on contact
    for f in range(4):
        t0 = time.time()
        screen.clear()
        draw_stars(screen, STAR_MAP, 390 + f)
        draw_lunar_surface(screen, sy)
        rx = 34 + random.choice([-1, 0, 1])
        screen.draw_sprite_solid(rx, ry, ROCKET_FULL)
        screen.text(69, 0, 'TOUCHDOWN', BGREEN)
        screen.render()
        frame_sleep(t0)

    time.sleep(0.5)


def scene_on_the_moon(screen, installed):
    """Split screen: moon landscape + results panel."""
    screen.invalidate()
    unique = list(dict.fromkeys(installed))
    left_stars = generate_star_map(39, 28, density=25, seed=99)

    for f in range(75):
        t0 = time.time()
        screen.clear()

        # Left half
        draw_stars(screen, left_stars, f)
        screen.draw_sprite_solid(5, 3, EARTH_SMALL)
        draw_lunar_surface(screen, 30, max_x=40)
        screen.draw_sprite_solid(12, 14, ROCKET_LANDED)

        # Flag plants after a beat
        if f > 12:
            screen.draw_sprite(28, 23, AMERICAN_FLAG)

        # Divider
        for y in range(40):
            screen.put(41, y, '\u2502', DIM)

        # Results panel (right half)
        if f > 5:
            screen.text(45, 3, '\u2550' * 32, BGREEN)
            screen.text(45, 4, '', BGREEN)
            screen.text(49, 4, 'MISSION COMPLETE', BGREEN)
            screen.text(45, 5, '\u2550' * 32, BGREEN)

        if f > 12:
            screen.text(45, 8, 'Installed Rockit support for:', WHITE)

        if f > 18:
            for i, editor in enumerate(unique):
                if f > 18 + i * 5:
                    screen.text(47, 11 + i, f'\u2713  {editor}', GREEN)

        bot = 11 + len(unique) + 2
        if f > 38:
            screen.text(45, bot, 'Restart your editor(s)', DIM)
            screen.text(45, bot + 1, 'to activate.', DIM)

        if f > 45:
            screen.text(45, bot + 4, 'R O C K I T', WHITE)
            screen.text(45, bot + 5, 'Dark Matter Tech', DIM)

        screen.render()
        frame_sleep(t0)

    time.sleep(3.0)


def scene_explosion(screen):
    """RUD — Rapid Unscheduled Disassembly. All installs failed."""
    screen.invalidate()
    rocket_x, rocket_y = 34, 10

    # Brief normal flight before the anomaly
    for f in range(15):
        t0 = time.time()
        screen.clear()
        draw_stars(screen, STAR_MAP, 200 + f)
        screen.draw_sprite_solid(rocket_x, rocket_y, ROCKET_FULL)
        ei = min(2 + (f % 2), 3)
        screen.draw_sprite(rocket_x, rocket_y + 20, EXHAUST_FRAMES[ei])
        screen.text(68, 0, 'ANOMALY', DIM)
        screen.render()
        frame_sleep(t0)

    # Shake + warning
    for f in range(10):
        t0 = time.time()
        screen.clear()
        draw_stars(screen, STAR_MAP, 215 + f)
        rx = rocket_x + random.choice([-2, -1, 0, 1, 2])
        ry = rocket_y + random.choice([-1, 0, 1])
        screen.draw_sprite_solid(rx, ry, ROCKET_FULL)
        screen.text(30, 2, '! ANOMALY DETECTED !', BRED)
        screen.text(68, 0, 'ANOMALY', BRED)
        screen.render()
        frame_sleep(t0)

    # Explosion — expanding debris
    cx, cy = 40, 19  # center of explosion
    debris_chars = ['*', '#', '@', '%', '&', '+', '!', '/', '\\', '|', '-']
    for f in range(30):
        t0 = time.time()
        screen.clear()
        draw_stars(screen, STAR_MAP, 225 + f)

        # Flash in first frames
        if f < 3:
            flash_ch = '\u2588' if f < 2 else '\u2592'
            flash_col = BYELLOW if f == 0 else BRED if f == 1 else YELLOW
            radius = 3 + f * 4
            for dy in range(-radius, radius + 1):
                for dx in range(-radius * 2, radius * 2 + 1):
                    if dx * dx // 4 + dy * dy <= radius * radius:
                        screen.put(cx + dx, cy + dy, flash_ch, flash_col)

        # Debris particles fly outward
        rng = random.Random(f * 13 + 42)
        spread = 2 + f * 1.5
        for _ in range(20 + f * 3):
            angle = rng.uniform(0, 6.28)
            dist = rng.uniform(0, spread)
            px = int(cx + math.cos(angle) * dist * 2)
            py = int(cy + math.sin(angle) * dist)
            if 0 <= px < 80 and 0 <= py < 40:
                ch = rng.choice(debris_chars)
                col = rng.choice([BRED, BYELLOW, YELLOW, WHITE, GRAY])
                if dist > spread * 0.7:
                    col = rng.choice([GRAY, DIM])
                screen.put(px, py, ch, col)

        if f > 10:
            screen.text(25, 2, 'MISSION FAILURE', BRED)
        if f > 18:
            screen.text(22, 4, 'Installation unsuccessful.', DIM)

        screen.text(68, 0, 'FAILURE', BRED)
        screen.render()
        frame_sleep(t0)

    # Hold on failure screen
    time.sleep(3.0)


def show_no_editors(screen):
    screen.clear()
    draw_stars(screen, STAR_MAP, 0)
    screen.draw_sprite_solid(34, 10, ROCKET_FULL)
    panel = [
        '', '  R O C K I T', '  Editor Support', '',
        '  No supported editors', '  detected.', '',
        '  Supports:', '    VS Code, Vim, Neovim,',
        '    JetBrains, Visual Studio', '',
    ]
    draw_panel(screen, 52, 5, 26, panel, DIM, CYAN)
    screen.render()
    _write(SHOW_CURSOR)
    time.sleep(3)


# ═══════════════════════════════════════════════════════════════════════
# Platform / Detection / Installation (unchanged)
# ═══════════════════════════════════════════════════════════════════════

SYSTEM = platform.system()
HOME = Path.home()

def detect_platform():
    if SYSTEM == "Darwin": return "macos"
    elif SYSTEM == "Linux": return "linux"
    elif SYSTEM == "Windows" or os.name == "nt": return "windows"
    return "unknown"

PLATFORM = detect_platform()
IDE_DIR = None

def find_editor_files():
    global IDE_DIR
    try:
        script_dir = Path(__file__).resolve().parent
        if (script_dir / "vscode" / "package.json").exists():
            IDE_DIR = script_dir; return
    except NameError: pass
    cwd = Path.cwd()
    if (cwd / "ide" / "vscode" / "package.json").exists():
        IDE_DIR = cwd / "ide"; return
    if (cwd.parent / "ide" / "vscode" / "package.json").exists():
        IDE_DIR = cwd.parent / "ide"; return
    repo_url = os.environ.get("ROCKIT_REPO_URL", "https://github.com/Dark-Matter/moon.git")
    if not shutil.which("git"):
        print(f"{RED}error:{RESET} git is required."); sys.exit(1)
    import tempfile
    work_dir = Path(tempfile.mkdtemp(prefix="rockit-editor-"))
    atexit.register(lambda: shutil.rmtree(work_dir, ignore_errors=True))
    try:
        subprocess.run(["git", "clone", "--depth", "1", "--filter=blob:none", "--sparse", repo_url, str(work_dir)], capture_output=True, check=True)
        subprocess.run(["git", "sparse-checkout", "set", "ide"], cwd=work_dir, capture_output=True, check=True)
        IDE_DIR = work_dir / "ide"
    except subprocess.CalledProcessError:
        print(f"{RED}error:{RESET} Failed to clone repository."); sys.exit(1)

def detect_all():
    targets = []
    targets += detect_vscode("code", "VS Code")
    targets += detect_vscode("code-insiders", "VS Code Insiders")
    targets += detect_vim()
    targets += detect_neovim()
    targets += detect_jetbrains()
    targets += detect_visual_studio()
    return targets

def detect_vscode(variant, label):
    ext_dir = HOME / (".vscode-insiders" if variant == "code-insiders" else ".vscode") / "extensions"
    if not shutil.which(variant) and not ext_dir.exists(): return []
    if not (IDE_DIR / "vscode" / "package.json").exists(): return []
    return [("vscode", variant, label)]

def detect_vim():
    vim_dir = HOME / ("vimfiles" if PLATFORM == "windows" else ".vim")
    if not shutil.which("vim") and not vim_dir.exists(): return []
    if not (IDE_DIR / "vim" / "syntax" / "rockit.vim").exists(): return []
    return [("vim", "", "Vim")]

def detect_neovim():
    nvim_config = HOME / ".config" / "nvim" if PLATFORM in ("macos", "linux") else Path(os.environ.get("LOCALAPPDATA", HOME / "AppData" / "Local")) / "nvim"
    if not shutil.which("nvim") and not nvim_config.exists(): return []
    if not (IDE_DIR / "vim" / "syntax" / "rockit.vim").exists(): return []
    return [("neovim", "", "Neovim")]

KNOWN_IDE_PREFIXES = ["IntelliJIdea", "IdeaIC", "WebStorm", "CLion", "PyCharm", "GoLand", "Rider", "RubyMine", "PhpStorm", "DataGrip", "DataSpell", "AndroidStudio", "Fleet", "Writerside"]
IDE_FRIENDLY = {"IntelliJIdea": "IntelliJ IDEA", "IdeaIC": "IntelliJ IDEA CE", "WebStorm": "WebStorm", "CLion": "CLion", "PyCharm": "PyCharm", "GoLand": "GoLand", "Rider": "Rider", "Fleet": "Fleet", "RubyMine": "RubyMine", "PhpStorm": "PhpStorm", "DataGrip": "DataGrip", "DataSpell": "DataSpell", "Writerside": "Writerside", "AndroidStudio": "Android Studio"}

def detect_jetbrains():
    base_dirs = []
    if PLATFORM == "macos": base_dirs = [HOME / "Library" / "Application Support" / "JetBrains"]
    elif PLATFORM == "linux": base_dirs = [HOME / ".local" / "share" / "JetBrains", HOME / ".config" / "JetBrains"]
    elif PLATFORM == "windows":
        base_dirs = [Path(os.environ.get("APPDATA", HOME / "AppData" / "Roaming")) / "JetBrains"]
    targets, seen = [], set()
    for base in base_dirs:
        if not base.exists(): continue
        for ide_dir in sorted(base.iterdir(), reverse=True):
            if not ide_dir.is_dir(): continue
            if not (ide_dir / "plugins").exists(): continue
            for prefix in KNOWN_IDE_PREFIXES:
                if ide_dir.name.startswith(prefix) and prefix not in seen:
                    seen.add(prefix)
                    targets.append(("jetbrains", str(ide_dir), IDE_FRIENDLY.get(prefix, ide_dir.name)))
                    break
    return targets

def detect_visual_studio():
    if PLATFORM != "windows": return []
    docs = HOME / "Documents"
    if not docs.exists(): return []
    return [("visualstudio", str(d), "Visual Studio") for d in docs.iterdir() if d.is_dir() and d.name.startswith("Visual Studio ")]

def install_target(target):
    kind, arg1, label = target
    if kind == "vscode": return install_vscode(arg1, label)
    elif kind == "vim": return install_vim()
    elif kind == "neovim": return install_neovim()
    elif kind == "jetbrains": return install_jetbrains(arg1, label)
    elif kind == "visualstudio": return install_visualstudio(arg1)
    return None

def install_vscode(variant, label):
    ext_dir = HOME / (".vscode-insiders" if variant == "code-insiders" else ".vscode") / "extensions"
    src = IDE_DIR / "vscode"
    target = ext_dir / "darkmattertech.rockit-lang-0.1.0"
    if target.exists(): shutil.rmtree(target)
    target.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src / "package.json", target / "package.json")
    shutil.copy2(src / "language-configuration.json", target / "language-configuration.json")
    for sub in ["syntaxes", "snippets", "icons"]:
        sub_src = src / sub
        if sub_src.exists(): shutil.copytree(sub_src, target / sub, dirs_exist_ok=True)
    return label

def install_vim():
    vim_dir = HOME / ("vimfiles" if PLATFORM == "windows" else ".vim")
    src = IDE_DIR / "vim"
    (vim_dir / "ftdetect").mkdir(parents=True, exist_ok=True)
    (vim_dir / "syntax").mkdir(parents=True, exist_ok=True)
    shutil.copy2(src / "ftdetect" / "rockit.vim", vim_dir / "ftdetect" / "rockit.vim")
    shutil.copy2(src / "syntax" / "rockit.vim", vim_dir / "syntax" / "rockit.vim")
    return "Vim"

def install_neovim():
    nvim_site = HOME / ".local" / "share" / "nvim" / "site" if PLATFORM in ("macos", "linux") else Path(os.environ.get("LOCALAPPDATA", HOME / "AppData" / "Local")) / "nvim-data" / "site"
    src = IDE_DIR / "vim"
    (nvim_site / "ftdetect").mkdir(parents=True, exist_ok=True)
    (nvim_site / "syntax").mkdir(parents=True, exist_ok=True)
    shutil.copy2(src / "ftdetect" / "rockit.vim", nvim_site / "ftdetect" / "rockit.vim")
    shutil.copy2(src / "syntax" / "rockit.vim", nvim_site / "syntax" / "rockit.vim")
    return "Neovim"

def install_jetbrains(ide_dir_str, friendly):
    plugins_dir = Path(ide_dir_str) / "plugins"
    dist_dir = IDE_DIR / "intellij-rockit" / "build" / "distributions"
    plugin_zip = None
    if dist_dir.exists():
        zips = list(dist_dir.glob("*.zip"))
        if zips: plugin_zip = zips[0]
    if not plugin_zip:
        gradlew = IDE_DIR / "intellij-rockit" / "gradlew"
        if gradlew.exists():
            subprocess.run([str(gradlew), "buildPlugin", "-q"], cwd=IDE_DIR / "intellij-rockit", capture_output=True)
            zips = list(dist_dir.glob("*.zip")) if dist_dir.exists() else []
            if zips: plugin_zip = zips[0]
    if plugin_zip:
        with zipfile.ZipFile(plugin_zip, 'r') as zf: zf.extractall(plugins_dir)
        return friendly
    return None

def install_visualstudio(vs_dir_str):
    ext_dir = Path(vs_dir_str) / "Extensions" / "DarkMatterTech" / "Rockit"
    ext_dir.mkdir(parents=True, exist_ok=True)
    syntaxes = IDE_DIR / "vscode" / "syntaxes"
    if syntaxes.exists():
        shutil.copytree(syntaxes, ext_dir / "syntaxes", dirs_exist_ok=True)
        return "Visual Studio"
    return None


# ═══════════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════════

def main():
    if not sys.stdout.isatty():
        find_editor_files()
        targets = detect_all()
        if not targets:
            print("No supported editors detected."); return
        for t in targets:
            result = install_target(t)
            if result: print(f"  Installed: {result}")
        print("\nRestart your editor(s) to activate.")
        return

    _write(ALT_SCREEN_ON + HIDE_CURSOR + CLEAR_SCREEN)

    find_editor_files()
    targets = detect_all()

    if not targets:
        show_no_editors(Screen(80, 40)); return

    # Deduplicate
    seen = set()
    unique_targets = []
    for t in targets:
        if t[2] not in seen:
            seen.add(t[2]); unique_targets.append(t)
    targets = unique_targets

    screen = Screen(80, 40)
    labels = [t[2] for t in targets]

    scene_prelaunch(screen, labels)
    scene_countdown(screen)
    scene_launch(screen)
    installed = scene_orbit_install(screen, targets, install_target)

    if not installed:
        # All installs failed — RUD
        scene_explosion(screen)
        _write(SHOW_CURSOR + ALT_SCREEN_OFF)
        print()
        print(f"  {BRED}Installation failed.{RESET}")
        print(f"  No editors were successfully configured.")
        print()
        return

    scene_tli(screen, installed)
    scene_lunar_approach(screen, installed)
    scene_descent(screen, installed)
    scene_on_the_moon(screen, installed)

    _write(SHOW_CURSOR + ALT_SCREEN_OFF)

    unique = list(dict.fromkeys(installed))
    print()
    print(f"  {BGREEN}Rockit editor support installed!{RESET}")
    print()
    for e in unique:
        print(f"    {GREEN}\u2713{RESET}  {e}")
    print()
    print(f"  Restart your editor(s) to activate.")
    print()


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        _write(SHOW_CURSOR + ALT_SCREEN_OFF)
        print("\n  Mission aborted.")
        sys.exit(1)
