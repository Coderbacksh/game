#!/usr/bin/env python3
"""Generate the Life of Grimoire VFX texture pack (assets/textures/*.png).

Every texture is greyscale-on-transparent (white RGB, detail in alpha and
slight grey shading) so a ParticleEmitter/Beam Color tints it: black for ink,
white for light, crimson for InfernoSeal, cyan for FrostRequiem.

Flipbooks are laid out row by row, left to right, matching Roblox's
ParticleFlipbookLayout Grid4x4 / Grid8x8. Max size is 1024x1024 (the Roblox
upload limit).

Usage (from the repo root):  pip install pillow numpy && python3 tools/make_textures.py
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "textures")
RNG = np.random.default_rng(7)


# ---------------------------------------------------------------- helpers
def value_noise(size, cells, rng):
    """Smooth value noise: random grid upsampled with bicubic filtering."""
    grid = rng.random((cells + 3, cells + 3)).astype(np.float32)
    img = Image.fromarray((grid * 255).astype(np.uint8), "L")
    scale = size / cells
    big = img.resize((int((cells + 3) * scale), int((cells + 3) * scale)), Image.BICUBIC)
    arr = np.asarray(big, dtype=np.float32) / 255.0
    off = int(scale)
    return arr[off : off + size, off : off + size]


def fbm(size, rng, base=4, octaves=6, persistence=0.55):
    total = np.zeros((size, size), np.float32)
    amp, norm = 1.0, 0.0
    cells = base
    for _ in range(octaves):
        total += value_noise(size, cells, rng) * amp
        norm += amp
        amp *= persistence
        cells *= 2
        if cells > size // 2:
            break
    return total / norm


def sample(field, x, y):
    """Bilinear sample of a 2D field at float pixel coords (wraps around)."""
    h, w = field.shape
    x = np.mod(x, w - 1)
    y = np.mod(y, h - 1)
    x0 = np.floor(x).astype(int)
    y0 = np.floor(y).astype(int)
    fx = x - x0
    fy = y - y0
    a = field[y0, x0]
    b = field[y0, x0 + 1]
    c = field[y0 + 1, x0]
    d = field[y0 + 1, x0 + 1]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def grid_coords(n):
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    u = (x + 0.5) / n * 2 - 1
    v = (y + 0.5) / n * 2 - 1
    return u, v


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def to_rgba(alpha, shade=None):
    """alpha (0..1) and optional shade (0..1 grey) -> RGBA image."""
    alpha = np.clip(alpha, 0, 1)
    shade = np.ones_like(alpha) if shade is None else np.clip(shade, 0, 1)
    rgb = (shade * 255).astype(np.uint8)
    a = (alpha * 255).astype(np.uint8)
    return Image.fromarray(np.dstack([rgb, rgb, rgb, a]), "RGBA")


def sheet(frames, grid):
    size = frames[0].size[0]
    out = Image.new("RGBA", (size * grid, size * grid), (255, 255, 255, 0))
    for i, f in enumerate(frames):
        out.paste(f, ((i % grid) * size, (i // grid) * size))
    return out


def glow_layer(img_l, radius, strength):
    """Add a blurred copy of an L-mode stroke image for a soft glow."""
    blurred = img_l.filter(ImageFilter.GaussianBlur(radius))
    a = np.asarray(img_l, np.float32) / 255
    b = np.asarray(blurred, np.float32) / 255
    return np.clip(a + b * strength, 0, 1)


def save(img, name):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name)
    img.save(path, optimize=True)
    print(f"  {name:22s} {img.size[0]}x{img.size[1]}  {os.path.getsize(path) // 1024} KB")


# ---------------------------------------------------------------- textures
def smoke_flipbook(name, frames=64, grid=8, frame=128, seed=1):
    """Billowing ink smoke: a cluster of drifting lobes (metaballs) carved
    by domain-warped fbm. Starts dense, expands, curls and breaks up into
    wisps before fading out. Noise is always sampled well inside its field
    (no wrapping), so there are no seams."""
    rng = np.random.default_rng(seed)
    big = 1024
    mid = big / 2
    n1 = fbm(big, rng, base=5, octaves=8)
    n2 = fbm(big, rng, base=10, octaves=6)
    warp = fbm(big, rng, base=3, octaves=5)
    lobes = [(rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), rng.uniform(0.3, 0.5), rng.uniform(0, math.tau)) for _ in range(9)]
    u, v = grid_coords(frame)
    out = []
    for i in range(frames):
        t = i / (frames - 1)
        grow = 0.75 + 0.4 * t ** 0.7
        field = np.zeros_like(u)
        for lx, ly, lr, la in lobes:
            cx = (lx + math.cos(la) * 0.14 * t) * grow
            cy = (ly + math.sin(la) * 0.14 * t - 0.1 * t) * grow
            rad = lr * grow
            field += np.exp(-(((u - cx) ** 2 + (v - cy) ** 2) / (rad * rad)))
        px, py = u * 180, v * 180  # centred pixel offsets, |p| <= 180
        wv = sample(warp, mid + px * 0.8 + t * 40, mid + py * 0.8 - t * 40) - 0.5
        wv2 = sample(warp, mid - 200 + py * 0.8, mid + 150 + px * 0.8) - 0.5
        d = sample(n1, mid + px + wv * 160 + t * 50, mid + py + wv2 * 160 - t * 80)
        d2 = sample(n2, mid + px * 1.3 - wv2 * 90, mid + py * 1.3 + wv * 90 + t * 60)
        detail = d * 0.55 + d2 * 0.45
        body = np.minimum(field, 1.5) * (0.35 + 1.6 * (detail - 0.35) * (1 + 0.8 * t))
        erode = 0.15 + 0.55 * t ** 1.2  # breaks up into wisps as it ages
        alpha = smoothstep(erode, erode + 0.3, body)
        alpha *= 1 - smoothstep(0.8, 1.0, np.maximum(np.abs(u), np.abs(v)))  # never touch the cell edge
        alpha *= 1 - t ** 4
        shade = 0.6 + 0.4 * smoothstep(0.35, 0.75, d2) - 0.12 * (u + v)
        out.append(to_rgba(alpha, shade))
    save(sheet(out, grid), name)


def wisp_flipbook(name, frames=16, grid=4, frame=256, seed=2):
    """Ink tendrils: several tapered curling strokes that unfurl then fade."""
    rng = np.random.default_rng(seed)
    curves = []
    for _ in range(5):
        start = rng.uniform(-0.2, 0.2, 2)
        a0 = rng.uniform(0, math.tau)
        curl = rng.uniform(2.5, 5.0) * rng.choice([-1, 1])
        length = rng.uniform(0.7, 1.1)
        width = rng.uniform(0.035, 0.07)
        curves.append((start, a0, curl, length, width))
    noise = fbm(frame, rng, base=6, octaves=5)
    out = []
    for i in range(frames):
        t = i / (frames - 1)
        ss = 3
        img = Image.new("L", (frame * ss, frame * ss), 0)
        dr = ImageDraw.Draw(img)
        for start, a0, curl, length, width in curves:
            steps = 60
            reveal = min(1, 0.25 + t * 1.4)
            x, y = start
            ang = a0
            pts = []
            for s in range(int(steps * reveal)):
                k = s / steps
                ang += curl / steps * (0.4 + k)
                x += math.cos(ang) * length / steps
                y += math.sin(ang) * length / steps
                pts.append((x, y, width * (1 - k) ** 0.8))
            for (x1, y1, w1), (x2, y2, _) in zip(pts, pts[1:]):
                px = lambda q: (q * 0.5 + 0.5) * frame * ss
                dr.line([px(x1), px(y1), px(x2), px(y2)], fill=255, width=max(1, int(w1 * frame * ss)))
        img = img.resize((frame, frame), Image.LANCZOS).filter(ImageFilter.GaussianBlur(1.2))
        a = np.asarray(img, np.float32) / 255
        a = a * (0.65 + 0.7 * noise) * (1 - t ** 2.2)
        out.append(to_rgba(a, 0.75 + 0.25 * noise))
    save(sheet(out, grid), name)


def jagged(dr, x1, y1, x2, y2, rng, segs, amp, width, fill):
    pts = [(x1, y1)]
    dx, dy = x2 - x1, y2 - y1
    length = math.hypot(dx, dy) or 1
    nx, ny = -dy / length, dx / length
    for s in range(1, segs):
        k = s / segs
        o = rng.uniform(-amp, amp) * math.sin(math.pi * k)
        pts.append((x1 + dx * k + nx * o, y1 + dy * k + ny * o))
    pts.append((x2, y2))
    dr.line(pts, fill=fill, width=width, joint="curve")
    return pts


def spark_flipbook(name, frames=16, grid=4, frame=256, seed=3):
    """Electric spark: hot core with jagged arcs that change every frame."""
    rng = np.random.default_rng(seed)
    out = []
    u, v = grid_coords(frame)
    r = np.sqrt(u * u + v * v)
    for i in range(frames):
        t = i / (frames - 1)
        ss = 2
        n = frame * ss
        img = Image.new("L", (n, n), 0)
        dr = ImageDraw.Draw(img)
        c = n / 2
        for _ in range(rng.integers(4, 8)):
            a = rng.uniform(0, math.tau)
            L = n * rng.uniform(0.22, 0.48) * (1 - 0.4 * t)
            pts = jagged(dr, c, c, c + math.cos(a) * L, c + math.sin(a) * L, rng, 7, n * 0.05, max(2, int(n * 0.012)), 255)
            if rng.random() < 0.6:  # fork
                k = rng.integers(2, len(pts) - 1)
                bx, by = pts[k]
                b = a + rng.uniform(-1, 1)
                jagged(dr, bx, by, bx + math.cos(b) * L * 0.4, by + math.sin(b) * L * 0.4, rng, 4, n * 0.03, max(1, int(n * 0.007)), 220)
        img = img.resize((frame, frame), Image.LANCZOS)
        a = glow_layer(img, 6, 1.4)
        core = np.exp(-(r / (0.12 * (1 - 0.5 * t))) ** 2)
        alpha = np.clip(a + core, 0, 1) * (1 - t ** 3)
        out.append(to_rgba(alpha))
    save(sheet(out, grid), name)


def ember_flipbook(name, frames=16, grid=4, frame=256, seed=4):
    """Flickering ember with a short soft tail and a few spark specks."""
    rng = np.random.default_rng(seed)
    u, v = grid_coords(frame)
    out = []
    for i in range(frames):
        t = i / (frames - 1)
        flick = 0.75 + 0.25 * math.sin(i * 2.1) + rng.uniform(-0.1, 0.1)
        core = np.exp(-((u / 0.09) ** 2 + ((v + 0.05) / 0.12) ** 2)) * flick
        tail = np.exp(-((u / 0.05) ** 2)) * np.exp(-(((v - 0.25) / 0.3) ** 2)) * (v > -0.05) * 0.55
        halo = np.exp(-((u * u + v * v) / 0.12)) * 0.3
        specks = np.zeros_like(u)
        for _ in range(3):
            sx, sy = rng.uniform(-0.5, 0.5, 2)
            specks += np.exp(-(((u - sx) / 0.025) ** 2 + ((v - sy) / 0.025) ** 2)) * rng.uniform(0.3, 0.8)
        alpha = np.clip(core + tail + halo + specks * (1 - t), 0, 1) * (1 - t ** 4)
        out.append(to_rgba(alpha))
    save(sheet(out, grid), name)


def fire_flipbook(name, frames=64, grid=8, frame=128, seed=5):
    """Spiky flame tongues: teardrop mask * upward-advected turbulent noise."""
    rng = np.random.default_rng(seed)
    big = 512
    n1 = fbm(big, rng, base=4, octaves=7)
    n2 = fbm(big, rng, base=8, octaves=5)
    u, v = grid_coords(frame)
    out = []
    for i in range(frames):
        t = i / (frames - 1)
        # v: -1 top .. 1 bottom. Flame base sits low, tongues lick upward.
        y = (v + 1) / 2  # 0 top .. 1 bottom
        width = 0.18 + 0.42 * y ** 1.6
        sx = u * 120 + 256
        sy = v * 120 + 256 + t * 220  # scroll noise upward over the life
        turb = sample(n1, sx, sy) - 0.5
        fine = sample(n2, sx * 2, sy * 2 + t * 300) - 0.5
        uu = u + turb * 0.45 * (1 - y) + fine * 0.15
        mask = 1 - smoothstep(width * 0.6, width, np.abs(uu))
        height_cut = smoothstep(0.02 + 0.25 * t, 0.35 + 0.2 * t, y + turb * 0.5)
        base_fade = 1 - smoothstep(0.88, 1.0, y)
        alpha = mask * height_cut * base_fade
        alpha = smoothstep(0.15, 0.55, alpha + fine * 0.6) * (1 - t ** 2.5)
        shade = 0.6 + 0.4 * (1 - np.abs(uu) / np.maximum(width, 1e-3)) * y
        out.append(to_rgba(alpha, shade))
    save(sheet(out, grid), name)


def shard_flipbook(name, frames=16, grid=4, frame=256, seed=6):
    """A sharp angular fragment tumbling, with a bright rim and faceting."""
    rng = np.random.default_rng(seed)
    base = []
    sides = 5
    for k in range(sides):
        a = k / sides * math.tau + rng.uniform(-0.3, 0.3)
        rad = rng.uniform(0.35, 0.95) * (1.6 if k == 0 else 1)
        base.append((a, rad))
    out = []
    for i in range(frames):
        t = i / frames
        rot = t * math.tau
        squash = 0.35 + 0.65 * abs(math.cos(rot * 0.5))  # tumble in depth
        ss = 3
        n = frame * ss
        c = n / 2
        poly = [(c + math.cos(a + rot) * r * n * 0.42 * squash, c + math.sin(a + rot) * r * n * 0.42) for a, r in base]
        fill = Image.new("L", (n, n), 0)
        ImageDraw.Draw(fill).polygon(poly, fill=150)
        rim = Image.new("L", (n, n), 0)
        dr = ImageDraw.Draw(rim)
        dr.line(poly + [poly[0]], fill=255, width=int(n * 0.02))
        dr.line([poly[0], (c, c), poly[2]], fill=200, width=int(n * 0.008))  # facet lines
        fill = fill.resize((frame, frame), Image.LANCZOS)
        rim = rim.resize((frame, frame), Image.LANCZOS)
        a = np.maximum(np.asarray(fill, np.float32) / 255, glow_layer(rim, 3, 0.6))
        shade = 0.55 + 0.45 * (np.asarray(rim, np.float32) / 255)
        out.append(to_rgba(a, shade))
    save(sheet(out, grid), name)


def flare(name, n=512):
    """Soft core + long anamorphic horizontal streak + faint star rays."""
    u, v = grid_coords(n)
    r = np.sqrt(u * u + v * v)
    ang = np.arctan2(v, u)
    core = np.exp(-(r / 0.12) ** 2)
    halo = np.exp(-(r / 0.45) ** 2) * 0.35
    streak = np.exp(-(v / 0.018) ** 2) * np.exp(-(np.abs(u) / 0.75) ** 1.5)
    rays = (np.abs(np.cos(ang * 6)) ** 40) * np.exp(-(r / 0.5) ** 2) * 0.35
    ring = np.exp(-(((r - 0.62) / 0.012) ** 2)) * 0.12
    save(to_rgba(core + halo + streak + rays + ring), name)


def ring(name, n=512, seed=8):
    """Shockwave ring: sharp bright edge, noisy breakup, soft inner wash."""
    rng = np.random.default_rng(seed)
    u, v = grid_coords(n)
    r = np.sqrt(u * u + v * v)
    ang = np.arctan2(v, u)
    noise = fbm(n, rng, base=8, octaves=5)
    # Sample noise on a circle (cos/sin) so the breakup has no seam.
    circ = fbm(256, rng, base=6, octaves=4)
    angular = sample(circ, 128 + np.cos(ang) * 90, 128 + np.sin(ang) * 90)
    edge = np.exp(-(((r - 0.86) / 0.025) ** 2))
    inner = smoothstep(0.35, 0.86, r) * (1 - smoothstep(0.86, 0.9, r)) * 0.35
    breakup = smoothstep(0.25, 0.65, angular * 0.6 + noise * 0.4)
    save(to_rgba((edge + inner * noise) * (0.4 + 0.6 * breakup)), name)


def crack(name, n=1024, seed=9):
    """Radial ground cracks: branching jagged fractures + hairline detail."""
    rng = np.random.default_rng(seed)
    ss = 2
    N = n * ss
    img = Image.new("L", (N, N), 0)
    dr = ImageDraw.Draw(img)
    c = N / 2

    def branch(x, y, ang, length, width, depth):
        steps = 10
        for _ in range(steps):
            ang += rng.uniform(-0.35, 0.35)
            seg = length / steps
            nx, ny = x + math.cos(ang) * seg, y + math.sin(ang) * seg
            dr.line([x, y, nx, ny], fill=255, width=max(1, int(width)))
            if depth > 0 and rng.random() < 0.22:
                branch(nx, ny, ang + rng.choice([-1, 1]) * rng.uniform(0.4, 1.0), length * 0.45, width * 0.55, depth - 1)
            x, y = nx, ny
            width *= 0.88

    for k in range(11):
        a = k / 11 * math.tau + rng.uniform(-0.2, 0.2)
        branch(c, c, a, N * rng.uniform(0.32, 0.47), N * 0.014, 3)
    # concentric impact fractures
    for rr in (0.08, 0.16):
        pts = []
        for k in range(48):
            a = k / 48 * math.tau
            pr = N * rr * rng.uniform(0.9, 1.1)
            pts.append((c + math.cos(a) * pr, c + math.sin(a) * pr))
        for p1, p2 in zip(pts, pts[1:] + pts[:1]):
            if rng.random() < 0.7:
                dr.line([p1, p2], fill=200, width=max(1, int(N * 0.004)))
    img = img.resize((n, n), Image.LANCZOS)
    a = glow_layer(img, 2.5, 0.5)
    u, v = grid_coords(n)
    r = np.sqrt(u * u + v * v)
    a = np.clip(a + np.exp(-(r / 0.12) ** 2) * 0.5, 0, 1) * (1 - smoothstep(0.8, 1.0, r))
    save(to_rgba(a), name)


def glyph_strokes(dr, cx, cy, size, rng, width):
    """Procedural rune: 3-5 strokes snapped to a 3x3 lattice."""
    pts = [(cx + (i % 3 - 1) * size / 2, cy + (i // 3 - 1) * size / 2 * 1.3) for i in range(9)]
    stem = rng.choice([1, 4, 7, 3, 5])
    dr.line([pts[1], pts[7]], fill=255, width=width) if stem in (1, 4, 7) else None
    for _ in range(rng.integers(3, 6)):
        a, b = rng.choice(9, 2, replace=False)
        dr.line([pts[a], pts[b]], fill=255, width=width)


def rune(name, n=1024, seed=10):
    """Rune seal: double rings, 7-point star, ticks and a ring of glyphs."""
    rng = np.random.default_rng(seed)
    ss = 2
    N = n * ss
    img = Image.new("L", (N, N), 0)
    dr = ImageDraw.Draw(img)
    c = N / 2
    w = max(2, int(N * 0.006))

    def circle(rad, width):
        dr.ellipse([c - rad, c - rad, c + rad, c + rad], outline=255, width=width)

    circle(N * 0.48, w * 2)
    circle(N * 0.455, w)
    circle(N * 0.36, w)
    circle(N * 0.33, w * 2)
    circle(N * 0.12, w)
    star = [(c + math.cos(k / 7 * math.tau - math.pi / 2) * N * 0.33, c + math.sin(k / 7 * math.tau - math.pi / 2) * N * 0.33) for k in range(7)]
    for k in range(7):
        dr.line([star[k], star[(k + 3) % 7]], fill=255, width=w)
    for k in range(56):
        a = k / 56 * math.tau
        r1, r2 = N * 0.455, N * (0.44 if k % 4 else 0.425)
        dr.line([c + math.cos(a) * r1, c + math.sin(a) * r1, c + math.cos(a) * r2, c + math.sin(a) * r2], fill=255, width=w)
    for k in range(16):  # glyph band between the rings
        a = k / 16 * math.tau
        gx, gy = c + math.cos(a) * N * 0.395, c + math.sin(a) * N * 0.395
        glyph_strokes(dr, gx, gy, N * 0.04, rng, w)
    img = img.resize((n, n), Image.LANCZOS)
    save(to_rgba(glow_layer(img, 5, 0.8)), name)


def glyph(name, n=256, seed=11):
    rng = np.random.default_rng(seed)
    ss = 4
    N = n * ss
    img = Image.new("L", (N, N), 0)
    dr = ImageDraw.Draw(img)
    glyph_strokes(dr, N / 2, N / 2, N * 0.55, rng, int(N * 0.05))
    dr.ellipse([N * 0.08, N * 0.08, N * 0.92, N * 0.92], outline=255, width=int(N * 0.025))
    img = img.resize((n, n), Image.LANCZOS)
    save(to_rgba(glow_layer(img, 6, 1.0)), name)


def crescent(name, w=1024, h=256, seed=12):
    """Beam texture for the slash: U runs along the blade, V across it.
    Bright cutting edge on one side, wind streaks trailing into ink."""
    rng = np.random.default_rng(seed)
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    uu = x / (w - 1)
    vv = y / (h - 1)
    streak_noise = np.asarray(Image.fromarray((rng.random((64, 8)) * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC), np.float32) / 255
    taper = np.clip(np.sin(np.pi * uu), 0, 1) ** 0.6  # thin at the tips
    edge = np.exp(-(((vv - 0.3) / 0.05) ** 2))  # hot cutting edge
    body = smoothstep(0.25, 0.35, vv) * (1 - smoothstep(0.35, 0.95, vv)) * (0.4 + 0.6 * streak_noise)
    alpha = np.clip(edge + body * 0.8, 0, 1) * taper
    shade = 1 - smoothstep(0.35, 0.95, vv) * 0.6  # fades toward the inky back edge
    save(to_rgba(alpha, shade), name)


def snow(name, n=128):
    u, v = grid_coords(n)
    r = np.sqrt(u * u + v * v)
    ang = np.arctan2(v, u)
    arms = (np.abs(np.cos(ang * 3)) ** 30) * np.exp(-(r / 0.6) ** 2)
    core = np.exp(-(r / 0.18) ** 2)
    halo = np.exp(-(r / 0.5) ** 2) * 0.25
    save(to_rgba(core + arms * 0.8 + halo), name)


def main():
    print(f"Writing textures to {os.path.relpath(OUT, ROOT)}/")
    smoke_flipbook("Smoke_8x8.png")
    wisp_flipbook("InkWisp_4x4.png")
    spark_flipbook("Spark_4x4.png")
    flare("Flare.png")
    ring("Ring.png")
    crack("Crack.png")
    shard_flipbook("Shard_4x4.png")
    rune("Rune.png")
    glyph("Glyph.png")
    crescent("Crescent.png")
    snow("Snow.png")
    ember_flipbook("Ember_4x4.png")
    fire_flipbook("Fire_8x8.png")


if __name__ == "__main__":
    main()
