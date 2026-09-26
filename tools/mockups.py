#!/usr/bin/env python3
"""Draws the Umbra frames as SVG, from the numbers the addon actually uses.

    python tools/mockups.py

Writes into assets/design/. Nothing here is a screenshot: it is the geometry
in `Core/Defaults.lua` drawn a second time, so a sheet is only as true as this
file is kept in step with that one. Every metric below is a copy, and the
derived numbers are copies of the functions rather than of their results —
`FrameHeight`, `StackOffset`, `AuraBlockHeight` and the two layout sets are
reimplemented, not written down, for the same reason the Lua derives them: a
number copied out of seven metrics goes stale the moment one of them changes.

What a sheet may therefore claim is geometry — an edge is three pixels, a
column of four members is 294 tall — and what it may not claim is anything
the client decides at runtime: fonts, the spell art in an icon, what a
portrait model looks like. Those are drawn as stand-ins and labelled as such.
"""

import math
import os

# --- Core/Defaults.lua, Umbra.metrics -------------------------------------

M = {
    'classEdge': 3,
    'portrait': 38,
    'gap': 2,
    'inset': 4,
    'groupSpacing': 6,
    'nameHeight': 13,
    'healthHeight': 20,
    'powerHeight': 4,
    'pipHeight': 4,
    'castbarHeight': 14,
    'valueWidth': 40,
    'auraSize': 26,
    'auraSpacing': 2,
    'auraUnderline': 2,
    'auraPerRow': 8,
    'auraFontSize': 11,
    'fontSize': 12,
    'classBarAlpha': 0.6,
    'rangeAlpha': 0.45,
    'barShade': 0.28,
    'barGloss': 0.12,
}

# The aura row sets the frame width, not the other way round.
M['width'] = M['auraPerRow'] * M['auraSize'] + (M['auraPerRow'] - 1) * M['auraSpacing']

# --- Core/Defaults.lua, Umbra.colors --------------------------------------

C = {
    'health': (78, 122, 85),
    'portraitGround': (35, 43, 60),
    'cast': (168, 124, 51),
    'auraHelpful': (141, 151, 171),
    'auraHarmful': (178, 93, 93),
    'healPrediction': (78, 122, 85, 0.55),
    'absorb': (154, 179, 214, 0.65),
    'healAbsorb': (139, 56, 66, 0.75),
    'background': (20, 25, 37, 0.96),
    'border': (11, 14, 21),
    'text': (230, 233, 240),
    'muted': (141, 151, 171),
    'accent': (117, 220, 196),
    'mana': (35, 106, 196),
}

# The client's, not ours — used so a sheet shows a real class color rather
# than a swatch standing in for one.
CLASS = {
    'WARRIOR': (198, 155, 109), 'PALADIN': (244, 140, 186),
    'HUNTER': (170, 211, 114), 'ROGUE': (255, 244, 104),
    'PRIEST': (255, 255, 255), 'DEATHKNIGHT': (196, 30, 58),
    'SHAMAN': (0, 112, 221), 'MAGE': (63, 199, 235),
    'WARLOCK': (135, 136, 238), 'MONK': (0, 255, 150),
    'DRUID': (255, 124, 10), 'DEMONHUNTER': (163, 48, 201),
    'EVOKER': (51, 147, 127),
}

HOSTILE = (199, 64, 64)

# --- Core/Defaults.lua, Umbra.frames --------------------------------------

SMALL = {'nameHeight': 11, 'healthHeight': 14, 'portrait': 28, 'fontSize': 11}

FRAMES = {
    'player': {'castbar': True, 'classPower': True, 'powerValue': True,
               'owns': {'pet'}, 'auras': {'helpful': 16, 'harmful': 8}},
    'target': {'castbar': True, 'powerValue': True,
               'owns': {'targettarget'}, 'auras': {'helpful': 8, 'harmful': 16}},
    'pet': dict(SMALL),
    'targettarget': dict(SMALL),
    'party': dict(SMALL, header=True, castbar=True, powerValue=True,
                  auraSize=14, auraDuration=False, auras={'harmful': 8}),
    'boss': dict(SMALL, castbar=True),
}

LAYOUTS = {
    'classic': {'above': ['pet', 'targettarget'], 'below': ['helpful', 'harmful']},
    'modern': {'above': ['targettarget', 'helpful'], 'below': ['pet', 'harmful']},
}

PARTY_COUNT = 4   # MAX_PARTY_MEMBERS
BOSS_COUNT = 5    # MAX_BOSS_FRAMES


def cfg(name):
    """A frame's config, falling back to the shared metrics like the metatable."""
    merged = dict(M)
    merged.update(FRAMES[name])
    return merged


# --- The derivations, reimplemented ---------------------------------------

def frame_height(c):
    h = c['nameHeight'] + c['gap'] + c['healthHeight'] + c['gap'] + c['powerHeight']
    if c.get('classPower'):
        h += c['gap'] + c['pipHeight']
    return h


def castbar_reach(c):
    return c['gap'] + c['castbarHeight'] if c.get('castbar') else 0


def aura_per_row(c):
    step = c['auraSize'] + c['auraSpacing']
    return max(1, (c['width'] + c['auraSpacing']) // step)


def aura_button_height(c):
    return c['auraSize'] + c['gap'] + c['auraUnderline']


def aura_block_height(c, count):
    rows = math.ceil(count / aura_per_row(c))
    return rows * (aura_button_height(c) + c['auraSpacing']) - c['auraSpacing']


def stack_height(c, entry):
    if entry in c.get('owns', ()):
        return frame_height(cfg(entry))
    count = c.get('auras', {}).get(entry)
    return aura_block_height(c, count) if count else None


def stack_offset(c, layout, side, entry=None):
    offset = castbar_reach(c) if side == 'below' else 0
    for name in layout[side]:
        if name == entry:
            return offset + c['gap']
        h = stack_height(c, name)
        if h:
            offset += c['gap'] + h
    return None if entry else offset


def group_slot_height(c, layout):
    return (stack_offset(c, layout, 'above') + frame_height(c)
            + stack_offset(c, layout, 'below'))


def column_height(c, layout, count):
    return (count * group_slot_height(c, layout)
            + (count - 1) * c['groupSpacing'])


# --- Where each set puts its frames ---------------------------------------

def points(name):
    """The same arithmetic Core/Defaults.lua does, per set.

    Returns {unit: (anchor, x, y)} in UIParent's own coordinates, where the
    anchor names which corner of the frame the pair fixes — exactly as the
    Lua's points do.
    """
    layout = LAYOUTS[name]
    player, target = cfg('player'), cfg('target')
    pet, glance, party = cfg('pet'), cfg('targettarget'), cfg('party')
    pet_h = frame_height(pet)
    out = {}

    if name == 'classic':
        inset, column = 16, 64
        player_y = -(inset + stack_offset(player, layout, 'above', 'pet') + pet_h)
        target_x = inset + player['width'] + column
        glance_y = (player_y + stack_offset(target, layout, 'above', 'targettarget')
                    + frame_height(glance))
        out['pet'] = ('TOPLEFT', inset, -inset)
        out['player'] = ('TOPLEFT', inset, player_y)
        out['target'] = ('TOPLEFT', target_x, player_y)
        out['targettarget'] = ('TOPLEFT', target_x, glance_y)
        out['party'] = ('TOPLEFT', inset,
                        player_y - frame_height(player)
                        - stack_offset(player, layout, 'below') - column)
    else:
        baseline, spread, inset = 260, 250, 16
        pet_y = baseline - stack_offset(player, layout, 'below', 'pet') - pet_h
        glance_y = (baseline + frame_height(target)
                    + stack_offset(target, layout, 'above', 'targettarget'))
        out['player'] = ('BOTTOM', -spread, baseline)
        out['target'] = ('BOTTOM', spread, baseline)
        out['pet'] = ('BOTTOM', -spread, pet_y)
        out['targettarget'] = ('BOTTOM', spread, glance_y)
        out['party'] = ('LEFT', inset, 0)

    boss = cfg('boss')
    reach = frame_height(boss) + stack_offset(boss, layout, 'below')
    step = reach + boss['gap'] * 2
    half = ((BOSS_COUNT - 1) * step + reach) / 2
    for i in range(BOSS_COUNT):
        out['boss%d' % (i + 1)] = ('TOPRIGHT', -16, half - i * step)

    return out


# --- SVG ------------------------------------------------------------------

def rgb(c, alpha=None):
    r, g, b = c[0], c[1], c[2]
    a = alpha if alpha is not None else (c[3] if len(c) > 3 else None)
    if a is None:
        return 'rgb(%d,%d,%d)' % (r, g, b)
    return 'rgba(%d,%d,%d,%.3f)' % (r, g, b, a)


#[[ Why the annotation type is scaled and the drawings are not
# A sheet is read where it is embedded, and GitHub fits a README image to a
# column around 880 wide. A 1420-wide sheet is therefore shown at 0.62, and
# an 11 px label arrives as 7 px — which is what these sheets were, and what
# made them unreadable at the one size anyone sees them at.
#
# So two things move in opposite directions. The drawings come down a scale
# step, which takes the canvases to roughly the column width, and the
# annotation type goes up by TYPE. The UI's own text is untouched: a 12 px
# label inside a 47 px frame is a fact about the addon, and scaling it would
# make the sheet claim something false.
#]]
TYPE = 1.34

PAPER = (9, 11, 17)
RULE = (44, 52, 70)
LABEL = (126, 138, 160)


class Sheet:
    """An SVG canvas that draws in frame units and scales once at the end."""

    def __init__(self, width, height, title, subtitle=''):
        self.w, self.h = width, height
        self.parts = []
        self.title, self.subtitle = title, subtitle

    def add(self, s):
        self.parts.append(s)

    def rect(self, x, y, w, h, fill, extra=''):
        if w <= 0 or h <= 0:
            return
        self.add('<rect x="%.2f" y="%.2f" width="%.2f" height="%.2f" fill="%s"%s/>'
                 % (x, y, w, h, fill, (' ' + extra) if extra else ''))

    def text(self, x, y, s, size=12, fill=None, anchor='start', weight='400',
             family='ui', opacity=None, spacing=None):
        fam = ('font-family="Inter,Segoe UI,Helvetica,Arial,sans-serif"'
               if family == 'ui' else
               'font-family="JetBrains Mono,SFMono-Regular,Consolas,monospace"')
        o = ' opacity="%.2f"' % opacity if opacity is not None else ''
        ls = ' letter-spacing="%.2f"' % spacing if spacing is not None else ''
        self.add('<text x="%.2f" y="%.2f" %s font-size="%.1f" fill="%s" '
                 'text-anchor="%s" font-weight="%s"%s%s>%s</text>'
                 % (x, y, fam, size, fill or rgb(LABEL), anchor, weight, o, ls,
                    escape(s)))

    def line(self, x1, y1, x2, y2, stroke=None, width=1, dash=None):
        d = ' stroke-dasharray="%s"' % dash if dash else ''
        self.add('<line x1="%.2f" y1="%.2f" x2="%.2f" y2="%.2f" stroke="%s" '
                 'stroke-width="%.2f"%s/>'
                 % (x1, y1, x2, y2, stroke or rgb(RULE), width, d))

    def save(self, path):
        head = [
            '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" '
            'viewBox="0 0 %d %d" role="img" aria-label="%s">'
            % (self.w, self.h, self.w, self.h, escape(self.title)),
            '<title>%s</title>' % escape(self.title),
            defs(),
            '<rect width="%d" height="%d" fill="%s"/>' % (self.w, self.h, rgb(PAPER)),
        ]
        body = '\n'.join(head + self.parts + ['</svg>', ''])
        with open(path, 'w', encoding='utf-8', newline='\n') as fh:
            fh.write(body)
        print('  %s  %d x %d' % (os.path.relpath(path), self.w, self.h))


def escape(s):
    return (s.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;'))


def defs():
    """The bar shading and the absorb hatch, as the addon builds them.

    The shade is one texture over the whole bar with a VERTICAL gradient —
    white at `barGloss` on top, black at `barShade` at the bottom. The hatch
    is the 32x32 tile in Media, whose stripe repeats every 8 pixels.
    """
    return (
        '<defs>'
        '<linearGradient id="shade" x1="0" y1="0" x2="0" y2="1">'
        '<stop offset="0" stop-color="#ffffff" stop-opacity="%.2f"/>'
        '<stop offset="1" stop-color="#000000" stop-opacity="%.2f"/>'
        '</linearGradient>'
        '<pattern id="hatch" width="24" height="24" patternUnits="userSpaceOnUse" '
        'patternTransform="rotate(45)">'
        '<rect width="24" height="24" fill="none"/>'
        '<rect width="10" height="24" fill="#ffffff" fill-opacity="0.45"/>'
        '</pattern>'
        '</defs>' % (M['barGloss'], M['barShade'])
    )


# --- Drawing one frame ----------------------------------------------------

def bar(sheet, x, y, w, h, color, fill=1.0, alpha=None, shade=True):
    """A StatusBar: border underneath, the fill, the shade over both.

    The shade lies over the whole bar rather than over the fill, so a bar that
    carries the prediction surfaces as well asks for it once, after them.
    """
    sheet.rect(x, y, w, h, rgb(C['border']))
    if fill > 0:
        sheet.rect(x, y, w * fill, h, rgb(color, alpha))
    if shade:
        sheet.rect(x, y, w, h, 'url(#shade)')


def draw_frame(sheet, x, y, unit, s, *, color, name, health=0.72, power=0.55,
               pips=None, health_value=None, health_percent=None,
               power_value=None, role=None, cast=None, class_health=False,
               heal=0.0, absorb=0.0, heal_absorb=0.0, alpha=1.0, portrait=True):
    """One frame at scale `s`, laid out exactly as Layouts/Shared.lua lays it.

    Returns the frame's height in frame units, so callers can stack.
    """
    c = cfg(unit)
    w, h = c['width'], frame_height(c)
    column_x = c['classEdge'] + c['gap'] + c['portrait'] + c['gap']
    column_w = w - column_x - c['inset']
    health_y = c['nameHeight'] + c['gap']
    power_y = health_y + c['healthHeight'] + c['gap']
    pip_y = power_y + c['powerHeight'] + c['gap']
    value_right = c['inset'] * 2

    g = '<g transform="translate(%.2f,%.2f) scale(%.4f)"%s>' % (
        x, y, s, ' opacity="%.2f"' % alpha if alpha < 1 else '')
    sheet.add(g)

    # background, class edge, portrait ground and tint
    sheet.rect(0, 0, w, h, rgb(C['background']))
    sheet.rect(0, 0, c['classEdge'], h, rgb(color))

    px = c['portraitX'] = c['classEdge'] + c['gap']
    if portrait:
        sheet.rect(px, 0, c['portrait'], h, rgb(C['portraitGround']))
        # A stand-in for the model, clipped to the column: a silhouette, so
        # nobody reads a face into a sheet that cannot have one.
        clip = 'clip%d' % (id(sheet) % 100000 + len(sheet.parts))
        sheet.add('<clipPath id="%s"><rect x="%.2f" y="0" width="%.2f" '
                  'height="%.2f"/></clipPath>' % (clip, px, c['portrait'], h))
        cx = px + c['portrait'] / 2
        head = c['portrait'] * 0.19
        cy = h * 0.40
        sheet.add('<g clip-path="url(#%s)" opacity="0.42">' % clip)
        sheet.add('<circle cx="%.2f" cy="%.2f" r="%.2f" fill="%s"/>'
                  % (cx, cy, head, rgb(color)))
        sheet.add('<ellipse cx="%.2f" cy="%.2f" rx="%.2f" ry="%.2f" fill="%s"/>'
                  % (cx, cy + head * 2.5, head * 2.4, head * 1.5, rgb(color)))
        sheet.add('</g>')
        sheet.rect(px, 0, c['portrait'], h, rgb(color, 0.13))

    role_w = (c['nameHeight'] + c['gap']) if c.get('header') else 0
    name_x = column_x + role_w
    name_w = column_w - role_w

    if role_w and role:
        rx, ry, rs = column_x, 0, c['nameHeight']
        sheet.rect(rx, ry, rs, rs, rgb(C['border']))
        mark = {'TANK': rgb((110, 160, 220)), 'HEALER': rgb((110, 200, 140)),
                'DAMAGER': rgb((214, 120, 110))}[role]
        if role == 'TANK':
            sheet.add('<path d="M %.2f %.2f l %.2f 0 l 0 %.2f l %.2f %.2f l %.2f %.2f Z" '
                      'fill="%s"/>' % (rx + 2, ry + 2, rs - 4, rs * 0.42,
                                       -(rs - 4) / 2, rs * 0.32,
                                       -(rs - 4) / 2, -rs * 0.32, mark))
        elif role == 'HEALER':
            t = rs * 0.24
            sheet.rect(rx + (rs - t) / 2, ry + 2, t, rs - 4, mark)
            sheet.rect(rx + 2, ry + (rs - t) / 2, rs - 4, t, mark)
        else:
            sheet.add('<path d="M %.2f %.2f l %.2f %.2f l %.2f %.2f Z" fill="%s"/>'
                      % (rx + 2.5, ry + rs - 2.5, rs - 5, -(rs - 5),
                         0, rs - 5, mark))

    if c.get('powerValue') and power_value:
        name_w = (w - value_right - c['valueWidth'] - c['gap']) - name_x
        sheet.text(w - value_right, c['nameHeight'] - 3, power_value,
                   size=c['fontSize'], fill=rgb(C['mana']), anchor='end',
                   weight='600')

    sheet.text(name_x, c['nameHeight'] - 3, name, size=c['fontSize'],
               fill=rgb(color), weight='600')

    # health, and the three surfaces on it
    fill_color = color if class_health else C['health']
    fill_alpha = M['classBarAlpha'] if class_health else None
    surfaces = bool(heal or absorb or heal_absorb)
    bar(sheet, column_x, health_y, column_w, c['healthHeight'],
        fill_color, health, fill_alpha, shade=not surfaces)

    if heal:
        sheet.rect(column_x + column_w * health, health_y,
                   min(column_w * heal, column_w * (1 - health)),
                   c['healthHeight'], rgb(C['healPrediction']))
    if absorb:
        ax = column_x + column_w * min(1.0, health + heal)
        aw = min(column_w * absorb, column_x + column_w - ax)
        sheet.rect(ax, health_y, aw, c['healthHeight'], rgb(C['absorb']))
        sheet.rect(ax, health_y, aw, c['healthHeight'], 'url(#hatch)')
    if heal_absorb:
        hw = column_w * heal_absorb
        sheet.rect(column_x + column_w * health - hw, health_y, hw,
                   c['healthHeight'], rgb(C['healAbsorb']))
    if surfaces:
        sheet.rect(column_x, health_y, column_w, c['healthHeight'], 'url(#shade)')

    if health_value:
        sheet.text(column_x + c['inset'], health_y + c['healthHeight'] - 6,
                   health_value, size=c['fontSize'], fill=rgb(C['text']))
    if health_percent:
        sheet.text(w - value_right, health_y + c['healthHeight'] - 6,
                   health_percent, size=c['fontSize'], fill=rgb(C['text']),
                   anchor='end')

    # power hairline
    bar(sheet, column_x, power_y, column_w, c['powerHeight'], C['mana'], power)

    if c.get('classPower') and pips:
        shown, filled = pips
        slot = (column_w - (shown - 1) * c['gap']) / shown
        for i in range(shown):
            bar(sheet, column_x + i * (slot + c['gap']), pip_y, slot,
                c['pipHeight'], C['accent'], 1.0 if i < filled else 0.0)

    sheet.add('</g>')

    if c.get('castbar') and cast:
        label, time, progress = cast
        cy = y + (h + c['gap']) * s
        sheet.add('<g transform="translate(%.2f,%.2f) scale(%.4f)"%s>'
                  % (x, cy, s, ' opacity="%.2f"' % alpha if alpha < 1 else ''))
        bar(sheet, 0, 0, w, c['castbarHeight'], C['cast'], progress)
        sheet.text(c['inset'], c['castbarHeight'] - 4, label, size=c['fontSize'],
                   fill=rgb(C['text']))
        sheet.text(w - c['inset'], c['castbarHeight'] - 4, time,
                   size=c['fontSize'], fill=rgb(C['muted']), anchor='end')
        sheet.add('</g>')

    return h


def draw_aura_row(sheet, x, y, s, count, *, harmful, size=None, dispel=None,
                  duration=True, alpha=1.0, per_row=None):
    """A row of aura buttons: the icon, the gap, and the line underneath."""
    c = cfg('player')
    icon = size or c['auraSize']
    under = c['auraUnderline']
    step = icon + c['auraSpacing']
    per_row = per_row or max(1, (c['width'] + c['auraSpacing']) // step)

    sheet.add('<g transform="translate(%.2f,%.2f) scale(%.4f)"%s>'
              % (x, y, s, ' opacity="%.2f"' % alpha if alpha < 1 else ''))
    for i in range(count):
        col, row = i % per_row, i // per_row
        bx = col * step
        by = row * (icon + c['gap'] + under + c['auraSpacing'])
        sheet.rect(bx, by, icon, icon, rgb(C['border']))
        # Stand-in for spell art: the client's, and not ours to draw.
        sheet.rect(bx + 1, by + 1, icon - 2, icon - 2,
                   rgb(C['muted'], 0.13 + 0.05 * ((i * 7) % 4)))
        line = C['auraHarmful'] if harmful else C['auraHelpful']
        if dispel and i in dispel:
            line = dispel[i]
        sheet.rect(bx, by + icon + c['gap'], icon, under, rgb(line))
        if duration and icon >= 26:
            sheet.text(bx + icon / 2, by + icon / 2 + 4, '%ds' % (4 + i * 3),
                       size=c['auraFontSize'], fill=rgb(C['text']),
                       anchor='middle', opacity=0.85)
    sheet.add('</g>')
    rows = math.ceil(count / per_row)
    return rows * (icon + c['gap'] + under + c['auraSpacing']) - c['auraSpacing']


def caption(sheet, x, y, eyebrow, title, body=None, width=340):
    sheet.text(x, y, eyebrow.upper(), size=10 * TYPE, fill=rgb(C['accent']),
               weight='600', spacing=1.4)
    sheet.text(x, y + 26 * TYPE, title, size=17 * TYPE, fill=rgb(C['text']),
               weight='600')
    if body:
        for i, line in enumerate(wrap(body, width, 12 * TYPE)):
            sheet.text(x, y + (50 + i * 18) * TYPE, line, size=12 * TYPE,
                       fill=rgb(LABEL))


def wrap(text, width, size):
    out, line = [], ''
    for word in text.split():
        probe = (line + ' ' + word).strip()
        if len(probe) * size * 0.52 > width and line:
            out.append(line)
            line = word
        else:
            line = probe
    if line:
        out.append(line)
    return out


def callout(sheet, x1, y1, x2, label, value=None, label_y=None):
    """A dot on the element, an elbow out to the margin, and two lines of text.

    `label_y` lets a caller spread labels that sit closer together than their
    text does — the leader bends rather than the rows being moved.
    """
    y2 = y1 if label_y is None else label_y
    out = 1 if x2 > x1 else -1
    knee = x1 + 14 * out
    sheet.add('<polyline points="%.2f,%.2f %.2f,%.2f %.2f,%.2f %.2f,%.2f" '
              'fill="none" stroke="%s" stroke-width="1"/>'
              % (x1, y1, knee, y1, x2 - 12 * out, y2, x2, y2, rgb(RULE)))
    sheet.add('<circle cx="%.2f" cy="%.2f" r="2" fill="%s"/>'
              % (x1, y1, rgb(C['accent'], 0.8)))
    anchor = 'start' if out > 0 else 'end'
    pad = 8 * out
    sheet.text(x2 + pad, y2 - 1, label, size=12 * TYPE, fill=rgb(C['text']),
               anchor=anchor)
    if value:
        sheet.text(x2 + pad, y2 + 16 * TYPE, value, size=11 * TYPE,
                   fill=rgb(LABEL), anchor=anchor, family='mono')


# --- Sheet 1: what a frame is made of -------------------------------------

def sheet_anatomy(out):
    s = 2
    c = cfg('player')
    buffs_h = aura_block_height(c, 8)
    above = stack_offset(c, LAYOUTS['modern'], 'above', 'helpful')

    ay = 200
    fx = 270
    fy = ay + (buffs_h + above) * s
    fw = c['width'] * s

    sheet = Sheet(980, 540, 'Umbra Unit Frames — frame anatomy')
    caption(sheet, 48, 52, 'Umbra Unit Frames',
            'What a frame is made of',
            'The player frame at twice its size, with the buff row above it '
            'as the modern set hangs it. Every rectangle is the one '
            'Layouts/Shared.lua places, at the size Core/Defaults.lua gives '
            'it — drawn from those numbers rather than photographed.',
            width=884)

    draw_aura_row(sheet, fx, ay, s, 8, harmful=False,
                  dispel={2: CLASS['PRIEST']})

    draw_frame(sheet, fx, fy, 'player', s,
               color=CLASS['MAGE'], name='Umbrastra', health=0.72, power=0.58,
               pips=(5, 3), health_value='412k', health_percent='72%',
               power_value='58%',
               cast=('Arcane Blast', '1.4', 0.62))

    h = frame_height(c)
    right = fx + fw
    left_x, right_x = fx - 44, right + 44

    # Left: the row above the frame, and the two columns that run its full
    # height. Right: the rows, in the order they are stacked. A label needs
    # more room than the row it points at, so the leader bends.
    callout(sheet, fx, ay + (c['auraSize'] / 2) * s, left_x,
            'Aura icon', '26 px, art inset 1', label_y=ay + 8)
    callout(sheet, fx, ay + (c['auraSize'] + c['gap']
                             + c['auraUnderline'] / 2) * s, left_x,
            'Aura underline', '2 px, dispel color', label_y=ay + 52)
    callout(sheet, fx + (c['classEdge'] + c['gap'] + c['portrait'] / 2) * s,
            fy + h * s * 0.32, left_x,
            'Portrait column', '38 x %d px' % h, label_y=fy + 34)
    callout(sheet, fx + c['classEdge'] * s / 2, fy + h * s * 0.72, left_x,
            'Class edge', '3 px, full height', label_y=fy + 88)

    rows = [
        (c['nameHeight'] / 2, 'Name and power value',
         'name 13 px, value 40 px', fy + 8),
        (c['nameHeight'] + c['gap'] + c['healthHeight'] / 2, 'Health',
         '20 px, rgb 78/122/85', fy + 60),
        (c['nameHeight'] + c['gap'] + c['healthHeight'] + c['gap']
         + c['powerHeight'] / 2, 'Power hairline', '4 px, the resource',
         fy + 112),
        (h - c['pipHeight'] / 2, 'Class power',
         '4 px, split by max', fy + 164),
        (h + c['gap'] + c['castbarHeight'] / 2, 'Cast bar',
         '14 px, the frame width', fy + 216),
    ]
    for oy, label, value, ly in rows:
        callout(sheet, right, fy + oy * s, right_x, label, value, label_y=ly)

    # the width rule, under everything
    ruler_y = fy + (h + c['gap'] + c['castbarHeight']) * s + 40
    sheet.line(fx, ruler_y, fx + fw, ruler_y, stroke=rgb(RULE))
    sheet.line(fx, ruler_y - 5, fx, ruler_y + 5, stroke=rgb(RULE))
    sheet.line(fx + fw, ruler_y - 5, fx + fw, ruler_y + 5, stroke=rgb(RULE))
    sheet.text(fx + fw / 2, ruler_y + 24,
               'width 222 px = 8 icons x 26 + 7 gaps x 2', size=11 * TYPE,
               fill=rgb(LABEL), anchor='middle', family='mono')
    sheet.text(fx + fw / 2, ruler_y + 46,
               'The aura row sets the frame width, not the other way round.',
               size=12 * TYPE, fill=rgb(C['muted']), anchor='middle')

    sheet.save(os.path.join(out, 'frame-anatomy.svg'))


# --- Sheet 2 and 3: the two sets on a screen ------------------------------

SCREEN_W, SCREEN_H = 1365, 768   # UIParent at the default scale, 16:9


def resolve(anchor, x, y, w, h):
    """A UIParent point turned into a top-left corner on the screen."""
    if anchor == 'TOPLEFT':
        return x, -y
    if anchor == 'TOPRIGHT':
        return SCREEN_W + x - w, SCREEN_H / 2 - y
    if anchor == 'BOTTOM':
        return SCREEN_W / 2 + x - w / 2, SCREEN_H - y - h
    if anchor == 'LEFT':
        return x, SCREEN_H / 2 - y - h / 2
    raise ValueError(anchor)


def sheet_layout(out, which):
    layout = LAYOUTS[which]
    pts = points(which)
    s = 0.62
    ox, oy = 48, 186
    sheet = Sheet(int(SCREEN_W * s) + 96, int(SCREEN_H * s) + 268,
                  'Umbra Unit Frames — the %s set' % which)

    blurb = {
        'modern': 'The arrangement Dragonflight introduced. Player and target '
                  'meet in the lower third, buffs above them, the pet under '
                  'the cast bar and the debuffs under the pet. The party '
                  'column goes to the left edge, centred on it: it is about '
                  'four other people and does not belong in that gathering.',
        'classic': 'Where the player frame lived before Dragonflight. The pet '
                   'is the topmost thing in the stack, so both aura rows hang '
                   'below, and the party column hangs under the player\'s '
                   'whole block rather than under the frame.',
    }[which]
    caption(sheet, 48, 52, '/uuf layout ' + which,
            'The %s set' % which, blurb, width=int(SCREEN_W * s) - 20)

    # the screen
    sheet.rect(ox, oy, SCREEN_W * s, SCREEN_H * s, rgb((13, 16, 24)))
    sheet.add('<rect x="%.2f" y="%.2f" width="%.2f" height="%.2f" fill="none" '
              'stroke="%s" stroke-width="1"/>'
              % (ox, oy, SCREEN_W * s, SCREEN_H * s, rgb(RULE)))
    sheet.line(ox + SCREEN_W * s / 2, oy, ox + SCREEN_W * s / 2, oy + SCREEN_H * s,
               stroke=rgb(RULE), width=1, dash='3 7')
    sheet.line(ox, oy + SCREEN_H * s / 2, ox + SCREEN_W * s, oy + SCREEN_H * s / 2,
               stroke=rgb(RULE), width=1, dash='3 7')
    sheet.text(ox + 12, oy + SCREEN_H * s - 12,
               'UIParent 1365 x 768 — the default scale on a 16:9 screen',
               size=10 * TYPE, fill=rgb(RULE), family='mono')

    def place(unit, **kw):
        c = cfg(unit if unit in FRAMES else unit.rstrip('0123456789'))
        anchor, x, y = pts[unit]
        fx, fy = resolve(anchor, x, y, c['width'], frame_height(c))
        draw_frame(sheet, ox + fx * s, oy + fy * s,
                   unit if unit in FRAMES else unit.rstrip('0123456789'), s, **kw)
        return fx, fy, c

    player = cfg('player')
    target = cfg('target')

    fx, fy, _ = place('player', color=CLASS['MAGE'], name='Umbrastra',
                      health=0.72, power=0.58, pips=(5, 3),
                      health_value='412k', health_percent='72%',
                      power_value='58%', cast=('Arcane Blast', '1.4', 0.62))
    tx, ty, _ = place('target', color=HOSTILE, name='Ancient Protector',
                      health=0.44, power=0.9, health_value='2.1M',
                      health_percent='44%', power_value='90%',
                      heal=0.09, absorb=0.07,
                      cast=('Crush', '2.8', 0.35))
    place('pet', color=CLASS['MAGE'], name='Water Elemental', health=1.0,
          power=0.8)
    place('targettarget', color=CLASS['WARRIOR'], name='Ironhide', health=0.61,
          power=0.3)

    # the aura rows, anchored the way Layouts/Auras.lua anchors them
    for unit, c, fxx, fyy in (('player', player, fx, fy), ('target', target, tx, ty)):
        for key, harmful in (('helpful', False), ('harmful', True)):
            count = c['auras'][key]
            h = aura_block_height(c, count)
            if key in layout['above']:
                off = stack_offset(c, layout, 'above', key)
                ay = fyy - off - h
            else:
                off = stack_offset(c, layout, 'below', key)
                ay = fyy + frame_height(c) + off
            draw_aura_row(sheet, ox + fxx * s, oy + ay * s, s, count,
                          harmful=harmful, duration=False)

    # the party column, on its own header spacing
    party = cfg('party')
    anchor, px, py = pts['party']
    slot = group_slot_height(party, layout)
    col_h = column_height(party, layout, PARTY_COUNT)
    cx, cy = resolve(anchor, px, py, party['width'], col_h)
    members = [('Thornhide', CLASS['DRUID'], 'TANK', 0.86, 1.0),
               ('Lightwell', CLASS['PRIEST'], 'HEALER', 0.97, 1.0),
               ('Stormfang', CLASS['SHAMAN'], 'DAMAGER', 0.64, 1.0),
               ('Ashvault', CLASS['WARLOCK'], 'DAMAGER', 0.41, M['rangeAlpha'])]
    for i, (nm, col, role, hp, alpha) in enumerate(members):
        my = cy + i * (slot + party['groupSpacing'])
        draw_frame(sheet, ox + cx * s, oy + my * s, 'party', s, color=col,
                   name=nm, health=hp, power=0.7, role=role, alpha=alpha,
                   health_percent='%d%%' % round(hp * 100),
                   power_value='70%',
                   cast=('Regrowth', '1.1', 0.5) if i == 1 else None)
        below = stack_offset(party, layout, 'below', 'harmful')
        draw_aura_row(sheet, ox + cx * s,
                      oy + (my + frame_height(party) + below) * s, s,
                      3 if i else 1, harmful=True, size=party['auraSize'],
                      duration=False, alpha=alpha,
                      per_row=aura_per_row(party))

    # the boss column, identical in both sets
    for i in range(BOSS_COUNT):
        unit = 'boss%d' % (i + 1)
        anchor, bx, by = pts[unit]
        c = cfg('boss')
        rx, ry = resolve(anchor, bx, by, c['width'], frame_height(c))
        draw_frame(sheet, ox + rx * s, oy + ry * s, 'boss', s, color=HOSTILE,
                   name='Encounter %d' % (i + 1), health=0.9 - i * 0.14,
                   power=0.5, health_percent='%d%%' % round((0.9 - i * 0.14) * 100),
                   cast=('Shadow Bolt', '1.9', 0.4) if i == 0 else None)

    # a legend for the two columns that are conditional
    ly = oy + SCREEN_H * s + 38
    legend = (('Party column', '4 x %d + 3 x %d = %d tall'
               % (slot, party['groupSpacing'], col_h)),
              ('Boss column', 'as many as MAX_BOSS_FRAMES'),
              ('Range fading', 'alpha %.2f, the portrait too' % M['rangeAlpha']))
    step = (SCREEN_W * s) / len(legend)
    for i, (label, note) in enumerate(legend):
        x = 52 + i * step
        sheet.add('<circle cx="%.2f" cy="%.2f" r="3.5" fill="%s"/>'
                  % (x, ly - 5, rgb(C['accent'])))
        sheet.text(x + 14, ly, label, size=12 * TYPE, fill=rgb(C['text']),
                   weight='600')
        sheet.text(x + 14, ly + 22, note, size=11 * TYPE, fill=rgb(LABEL))

    sheet.save(os.path.join(out, 'layout-%s.svg' % which))


# --- Sheet 4: the party column --------------------------------------------

def sheet_party(out):
    s = 2
    layout = LAYOUTS['modern']
    party = cfg('party')
    slot = group_slot_height(party, layout)
    below = stack_offset(party, layout, 'below', 'harmful')
    fx, fy = 56, 196

    sheet = Sheet(980,
                  int(fy + PARTY_COUNT * (slot + party['groupSpacing']) * s + 40),
                  'Umbra Unit Frames — the party column')
    caption(sheet, 48, 56, '/uuf group', 'The party column',
            'Four members at twice their size. The client creates these '
            'children, assigns their units and re-sorts them; what Umbra '
            'decides is what one member looks like and how much room it '
            'takes.', width=860)

    members = [('Thornhide', CLASS['DRUID'], 'TANK', 0.86, 1.0, 2),
               ('Lightwell', CLASS['PRIEST'], 'HEALER', 0.97, 1.0, 1),
               ('Stormfang', CLASS['SHAMAN'], 'DAMAGER', 0.64, 1.0, 4),
               ('Ashvault', CLASS['WARLOCK'], 'DAMAGER', 0.41,
                M['rangeAlpha'], 3)]

    for i, (nm, col, role, hp, alpha, debuffs) in enumerate(members):
        my = fy + i * (slot + party['groupSpacing']) * s
        draw_frame(sheet, fx, my, 'party', s, color=col, name=nm, health=hp,
                   power=0.7, role=role, alpha=alpha,
                   health_percent='%d%%' % round(hp * 100),
                   power_value='70%',
                   cast=('Regrowth', '1.1', 0.5) if i == 1 else None)
        draw_aura_row(sheet, fx, my + (frame_height(party) + below) * s, s,
                      debuffs, harmful=True, size=party['auraSize'],
                      duration=False, alpha=alpha,
                      per_row=aura_per_row(party),
                      dispel={0: CLASS['PRIEST']} if i == 2 else None)

    right = fx + party['width'] * s + 56
    notes = [
        ('Role, left of the name',
         'The client\'s own icon, %d x %d. The space is reserved on every '
         'member whether or not there is one, so the names stay in one column.'
         % (party['nameHeight'], party['nameHeight'])),
        ('Debuffs at %d px' % party['auraSize'],
         'Half what a single frame uses, and no duration label — at this size '
         'the label covers the icon. The row holds what fits the width: %d.'
         % aura_per_row(party)),
        ('One member is %d tall' % slot,
         'The frame (%d), its cast bar (%d) and the debuff row (%d). The '
         'header\'s spacing, the column\'s height and the stand-ins all ask '
         'one function for this.'
         % (frame_height(party), castbar_reach(party),
            aura_block_height(party, 8) + party['gap'])),
        ('Out of range fades',
         'Alpha %.2f, the portrait with it. Class color and identity stay '
         'intact rather than going grey.' % M['rangeAlpha']),
    ]
    for i, (title, body) in enumerate(notes):
        y = 200 + i * 128
        sheet.line(right - 24, y - 13, right - 10, y - 13, stroke=rgb(C['accent']))
        sheet.text(right, y - 8, title, size=13 * TYPE, fill=rgb(C['text']),
                   weight='600')
        for j, line in enumerate(wrap(body, 392, 12 * TYPE)):
            sheet.text(right, y + 16 + j * 21, line, size=12 * TYPE,
                       fill=rgb(LABEL))

    sheet.save(os.path.join(out, 'party-column.svg'))


# --- Sheet 5: the surfaces on a bar, and the lines under an icon ----------

def sheet_states(out):
    s = 2
    c = cfg('target')
    column_x = c['classEdge'] + c['gap'] + c['portrait'] + c['gap']
    column_w = c['width'] - column_x - c['inset']
    bw = column_w * s

    # The bars take the full width and the underlines go beneath them rather
    # than beside: side by side, each description had a third of the sheet
    # and ran to four lines that met the row below.
    text_w, bar_x = 392, 468
    sheet = Sheet(980, 832, 'Umbra Unit Frames — bar and aura states')
    caption(sheet, 48, 52, 'Design principles',
            'Told apart without reading a number',
            'Three surfaces share the health bar, and one line sits under '
            'every aura icon. Each is drawn here at the color and the size '
            'the addon gives it.', width=884)

    states = [
        ('Health', 'One neutral green whatever the unit is. Nothing is '
         'derived from the value, so the bar behaves the same inside an '
         'encounter as outside one.', dict(health=0.62)),
        ('Incoming healing', 'The health color again at 55%: health that is '
         'not there yet belongs to the same quantity.',
         dict(health=0.62, heal=0.2)),
        ('Damage absorb', 'Not health at all, so a color of its own, hatched '
         'to read as a shield laid over the bar.',
         dict(health=0.62, absorb=0.24)),
        ('Heal absorb', 'The one that eats backwards into health already '
         'there, and the only one of the three that is bad news.',
         dict(health=0.62, heal_absorb=0.22)),
        ('/uuf health class', "The unit's color on the bar as well, at alpha "
         '%.1f, so the two numbers on it stay legible.' % M['classBarAlpha'],
         dict(health=0.62, class_health=True)),
    ]

    for i, (title, body, kw) in enumerate(states):
        y = 208 + i * 90
        sheet.text(48, y - 8, title, size=12.5 * TYPE, fill=rgb(C['text']),
                   weight='600')
        for j, line in enumerate(wrap(body, text_w, 11 * TYPE)):
            sheet.text(48, y + 16 + j * 19, line, size=11 * TYPE,
                       fill=rgb(LABEL))

        sheet.add('<g transform="translate(%d,%.2f) scale(%d)">'
                  % (bar_x, y - 22, s))
        fill = kw.get('class_health') and CLASS['SHAMAN'] or C['health']
        alpha = M['classBarAlpha'] if kw.get('class_health') else None
        bar(sheet, 0, 0, column_w, c['healthHeight'], fill, kw['health'],
            alpha, shade=False)
        if kw.get('heal'):
            sheet.rect(column_w * kw['health'], 0, column_w * kw['heal'],
                       c['healthHeight'], rgb(C['healPrediction']))
        if kw.get('absorb'):
            ax = column_w * kw['health']
            sheet.rect(ax, 0, column_w * kw['absorb'], c['healthHeight'],
                       rgb(C['absorb']))
            sheet.rect(ax, 0, column_w * kw['absorb'], c['healthHeight'],
                       'url(#hatch)')
        if kw.get('heal_absorb'):
            hw = column_w * kw['heal_absorb']
            sheet.rect(column_w * kw['health'] - hw, 0, hw, c['healthHeight'],
                       rgb(C['healAbsorb']))
        sheet.rect(0, 0, column_w, c['healthHeight'], 'url(#shade)')
        sheet.text(c['inset'], c['healthHeight'] - 6, '1.4M',
                   size=c['fontSize'], fill=rgb(C['text']))
        sheet.text(column_w - c['inset'] * 2, c['healthHeight'] - 6, '62%',
                   size=c['fontSize'], fill=rgb(C['text']), anchor='end')
        sheet.add('</g>')

    # the underlines, across the foot of the sheet
    uy = 700
    sheet.line(48, uy - 46, 932, uy - 46, stroke=rgb(RULE))
    sheet.text(48, uy - 18, 'The line under an icon', size=12.5 * TYPE,
               fill=rgb(C['text']), weight='600')
    lines = [('Helpful', C['auraHelpful'], 'no dispel type'),
             ('Harmful', C['auraHarmful'], 'no dispel type'),
             ('Magic', (51, 147, 255), "the client's own"),
             ('Poison', (0, 255, 0), "the client's own"),
             ('Curse', (160, 32, 240), "the client's own")]
    step = 884 / len(lines)
    for i, (label, col, note) in enumerate(lines):
        x = 48 + i * step
        sheet.add('<g transform="translate(%.2f,%.2f) scale(%d)">' % (x, uy, s))
        sheet.rect(0, 0, M['auraSize'], M['auraSize'], rgb(C['border']))
        sheet.rect(1, 1, M['auraSize'] - 2, M['auraSize'] - 2,
                   rgb(C['muted'], 0.16))
        sheet.rect(0, M['auraSize'] + M['gap'], M['auraSize'],
                   M['auraUnderline'], rgb(col))
        sheet.add('</g>')
        lx = x + M['auraSize'] * s + 14
        sheet.text(lx, uy + 26, label, size=12 * TYPE, fill=rgb(C['text']))
        sheet.text(lx, uy + 46, note, size=10.5 * TYPE, fill=rgb(LABEL))

    sheet.save(os.path.join(out, 'bar-states.svg'))


# --- Sheet 6: the options window ------------------------------------------

#[[ The window's own numbers, copied from Core/Options.lua
# Drawn before the window existed and kept in step with it since, like the
# frames: `OPT` below is a copy of the constants at the top of that file and
# the walk in `options_layout` is a copy of its `Add` calls. Its colors are
# the addon's, and its controls are the settings `/uuf` already takes.
#
# The geometry is the window's own, in its pixels, and the sheet scales it
# once like a frame: a 12 px label is a claim about the window. The type is
# the client's and stands in here, as it does on every sheet.
#]]
OPT = {
    'width': 280,
    'pad': 12,
    'header': 36,
    'segment': 22,
    'box': 14,
    'button': 22,
    'label': 10,
    'font': 12,
    'title': 13,
    'footer': 9,
}

VERSION = '0.5.1'

OPTION_ROWS = [
    ('section', 'Layout'),
    ('segment', 'layout', ('Modern', 'Classic')),
    ('section', 'Health bar'),
    ('segment', 'health', ('Neutral', 'Class color')),
    ('section', 'Blizzard frames'),
    ('check', 'auras', 'Hide Blizzard buffs & debuffs'),
    ('check', 'group', 'Hide Blizzard group manager'),
    ('section', 'Display'),
    ('check', 'minimap', 'Show minimap button'),
    ('section', 'Frames'),
]


def options_layout():
    """Where each row starts, in window pixels, and how tall the window is."""
    o = OPT
    y = o['header']
    rows = []
    for row in OPTION_ROWS:
        kind = row[0]
        if kind == 'section':
            y += 14
            rows.append((y, row))
            y += 8
        elif kind == 'segment':
            rows.append((y, row))
            y += o['segment'] + 8
        else:
            rows.append((y, row))
            y += o['box'] + 10
    # The two buttons stand under their own heading rather than under a
    # rule: "Frames" says what they move and reset, so their labels can be
    # one word.
    buttons = y
    footer = buttons + o['button'] + 22
    return rows, buttons, footer + 12


def draw_options(sheet, x, y, s, *, state=None, notes=None):
    """The window at scale `s`. `state` holds the values and what is refused.

    Returns the window's height in its own pixels.
    """
    o = OPT
    state = state or {}
    refused = state.get('refused', {})
    # A note says why without taking the control away: the layout in a fight
    # is kept and applied when it ends, so it stays live.
    said = state.get('notes', {})
    rows, buttons, height = options_layout()
    w = o['width']
    left = C_EDGE + o['pad']
    inner = w - left - o['pad']

    sheet.add('<g transform="translate(%.2f,%.2f) scale(%.4f)">' % (x, y, s))

    # the window: border, ground, and the accent edge where a frame has its
    # class edge — the interface's color at the place a unit keeps its own
    sheet.rect(-1, -1, w + 2, height + 2, rgb(C['border']))
    sheet.rect(0, 0, w, height, rgb(C['background']))
    sheet.rect(0, 0, C_EDGE, height, rgb(C['accent']))

    sheet.text(left, 23, 'Umbra Unit Frames', size=o['title'],
               fill=rgb(C['text']), weight='600')
    cx, cy, cs = w - o['pad'] - 12, 12, 12
    sheet.rect(cx - 3, cy - 3, cs + 6, cs + 6, rgb(C['border']))
    sheet.line(cx, cy, cx + cs, cy + cs, stroke=rgb(C['muted']), width=1.5)
    sheet.line(cx + cs, cy, cx, cy + cs, stroke=rgb(C['muted']), width=1.5)
    sheet.line(C_EDGE, o['header'], w, o['header'], stroke=rgb(C['muted'], 0.18))

    for ry, row in rows:
        kind = row[0]
        if kind == 'section':
            sheet.text(left, ry, row[1].upper(), size=o['label'],
                       fill=rgb(C['muted']), weight='600', spacing=1.2)
            continue

        key = row[1]
        why = refused.get(key)

        if kind == 'segment':
            choices = row[2]
            chosen = state.get(key, 0)
            gap = 2
            sw = (inner - gap * (len(choices) - 1)) / len(choices)
            for i, label in enumerate(choices):
                sx = left + i * (sw + gap)
                on = i == chosen
                sheet.rect(sx, ry, sw, o['segment'], rgb(C['border']))
                if on:
                    # The chosen side carries a line under it, the same two
                    # pixels an aura icon has: one mark, meaning "this one".
                    sheet.rect(sx, ry, sw, o['segment'], rgb(C['accent'], 0.12))
                    sheet.rect(sx, ry + o['segment'] - 2, sw, 2, rgb(C['accent']))
                sheet.text(sx + sw / 2, ry + 15, label, size=o['font'],
                           fill=rgb(C['accent'] if on else C['muted']),
                           anchor='middle', weight='600' if on else '400')
            if why:
                sheet.rect(left, ry, inner, o['segment'], rgb(C['background'], 0.55))
                sheet.rect(left, ry, inner, o['segment'], 'url(#hatch-fine)')
        else:
            on = state.get(key, False)
            b = o['box']
            sheet.rect(left, ry, b, b, rgb(C['border']))
            sheet.add('<rect x="%.2f" y="%.2f" width="%.2f" height="%.2f" '
                      'fill="none" stroke="%s" stroke-width="1"/>'
                      % (left + 0.5, ry + 0.5, b - 1, b - 1, rgb(C['muted'], 0.35)))
            if on:
                # A filled square inset in the box, the shape of a class
                # power pip — no tick, which would be the client's art.
                sheet.rect(left + 3, ry + 3, b - 6, b - 6, rgb(C['accent']))
            sheet.text(left + b + 8, ry + 11, row[2], size=o['font'],
                       fill=rgb(C['muted'] if why else C['text']),
                       opacity=0.6 if why else None)
            if why:
                sheet.rect(left, ry, b, b, 'url(#hatch-fine)')

        why = why or said.get(key)
        if why:
            sheet.text(w - o['pad'], ry - 4 if kind == 'segment' else ry + 11,
                       why, size=o['label'], fill=rgb(C['auraHarmful']),
                       anchor='end')


    unlocked = state.get('unlocked')
    bw = (inner - 6) / 2
    for i, label in enumerate(('Lock' if unlocked else 'Unlock', 'Reset')):
        bx = left + i * (bw + 6)
        sheet.rect(bx, buttons, bw, o['button'], rgb(C['border']))
        hot = i == 0 and unlocked
        if hot:
            sheet.rect(bx, buttons + o['button'] - 2, bw, 2, rgb(C['accent']))
        sheet.text(bx + bw / 2, buttons + 15, label, size=o['font'],
                   fill=rgb(C['accent'] if hot else C['text']), anchor='middle',
                   opacity=0.45 if (i == 0 and refused.get('unlock')) else None)
        if i == 0 and refused.get('unlock'):
            sheet.rect(bx, buttons, bw, o['button'], 'url(#hatch-fine)')

    fy = height - 12
    sheet.text(left, fy, '/uuf help  ·  v%s' % VERSION, size=o['footer'],
               fill=rgb(C['muted']), opacity=0.7)
    sheet.text(w - o['pad'], fy, '♥ by krebs3r', size=o['footer'],
               fill=rgb(C['muted']), opacity=0.7, anchor='end')

    sheet.add('</g>')

    if notes:
        sheet.text(x, y + (height + 1) * s + 30, notes, size=11 * TYPE,
                   fill=rgb(LABEL))
    return height


C_EDGE = M['classEdge']


def sheet_options(out):
    s = 1.5
    rows, buttons, height = options_layout()
    o = OPT
    w = o['width'] * s
    top = 206
    row2 = top + height * s + 150

    sheet = Sheet(980, int(row2 + height * s + 232),
                  'Umbra Unit Frames — the options window')
    # A refused control is struck through with the hatch tile, finer than the
    # absorb's, so it reads as "not now" rather than as a shield.
    sheet.add('<defs><pattern id="hatch-fine" width="6" height="6" '
              'patternUnits="userSpaceOnUse" patternTransform="rotate(45)">'
              '<rect width="2" height="6" fill="#ffffff" fill-opacity="0.16"/>'
              '</pattern></defs>')
    caption(sheet, 48, 52, 'Options · /uuf',
            'The options window',
            'What /uuf already sets, in one small window: Soundstone\'s shape '
            '— a title, sections, switches, two actions and a quiet footer — '
            'in Umbra\'s own colors. Every control takes effect where you '
            'stand, without a reload, as the command does today.',
            width=884)

    fx = 48
    normal = {'layout': 0, 'health': 0, 'auras': True, 'group': True,
              'minimap': False}
    draw_options(sheet, fx, top, s, state=normal)

    right = fx + w
    lx = right + 44
    ys = {row[1]: ry for ry, row in rows if row[0] != 'section'}

    notes = [
        (top + 18 * s, 'Title, close, Escape',
         'accent edge where a frame has its class edge'),
        (top + (ys['layout'] + 11) * s, 'Segmented switch',
         'the chosen side carries a 2 px line'),
        (top + (ys['auras'] + 7) * s, 'Checkboxes of its own',
         'the same on all five clients'),
        (top + (buttons + 11) * s, 'Unlock turns into Lock',
         'while the frames can be dragged'),
    ]
    for py, label, value in notes:
        callout(sheet, right, py, lx, label, value)

    # the two states the window has to show, under the first
    sheet.text(48, row2 - 58, 'Two states it has to show', size=12.5 * TYPE,
               fill=rgb(C['text']), weight='600')
    sheet.line(48, row2 - 92, 932, row2 - 92, stroke=rgb(RULE))

    combat = dict(normal, unlocked=False,
                  notes={'layout': 'applies after combat'},
                  refused={'unlock': True})
    draw_options(sheet, 48, row2, s, state=combat)
    forever = dict(normal, group=False,
                   refused={'group': 'not on this client'})
    second = 980 - 48 - w
    draw_options(sheet, second, row2, s, state=forever)

    for x, title, body in (
            (48, 'In combat',
             'The mover is refused, as /uuf unlock refuses it. The layout '
             'stays live: one picked now is applied when the fight ends.'),
            (second, 'On WoW: Forever',
             'The party column steps back on that client, so the switch for '
             'Blizzard\'s group manager has nothing to hand over.')):
        by = row2 + height * s + 32
        sheet.text(x, by, title, size=12 * TYPE, fill=rgb(C['text']),
                   weight='600')
        for j, line in enumerate(wrap(body, w, 11 * TYPE)):
            sheet.text(x, by + 22 + j * 19, line, size=11 * TYPE,
                       fill=rgb(LABEL))

    # where it opens
    ly = row2 + height * s + 196
    doors = (('/uuf', 'on its own, no argument'),
             ('Addon compartment', 'where the client has one'),
             ('Options › AddOns', 'a page with one button'),
             ('Minimap button', 'where there is none'))
    sheet.line(48, ly - 36, 932, ly - 36, stroke=rgb(RULE))
    step = 884 / len(doors)
    for i, (label, note) in enumerate(doors):
        x = 52 + i * step
        sheet.add('<circle cx="%.2f" cy="%.2f" r="3.5" fill="%s"/>'
                  % (x, ly - 5, rgb(C['accent'])))
        sheet.text(x + 14, ly, label, size=12 * TYPE, fill=rgb(C['text']),
                   weight='600')
        sheet.text(x + 14, ly + 22, note, size=10.5 * TYPE, fill=rgb(LABEL))

    sheet.save(os.path.join(out, 'options-window.svg'))


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out = os.path.join(root, 'assets', 'design')
    os.makedirs(out, exist_ok=True)

    print('umbra mockups — width %d, player %d tall, party slot %d'
          % (M['width'], frame_height(cfg('player')),
             group_slot_height(cfg('party'), LAYOUTS['modern'])))

    sheet_anatomy(out)
    sheet_layout(out, 'modern')
    sheet_layout(out, 'classic')
    sheet_party(out)
    sheet_states(out)
    sheet_options(out)


if __name__ == '__main__':
    main()
