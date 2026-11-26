"""Procedural placeholder generators: one function per archetype.

These build clean, readable grey-box models from simple shapes so the game
has something to show before final art exists. Final art replaces them
(docs/04-art-pipeline.md). Every generator gets (spec, palette) and builds
objects in the current scene. Models face -Y (the front), with z = 0 as ground.

Parts the game animates are named "turret" (turns about its vertical axis)
and "barrel" (tilts up and down), with origins set at their pivots. A
negative X rotation raises the front (-Y) of a part.
"""

from sf_common import TEAM_MATERIAL, box, cylinder, empty, get_material, set_origin, sphere


def _materials(spec, palette):
    faction = palette["factions"][spec["faction"]]
    return {
        "body": get_material(f"{spec['faction']}_body", faction["body"], roughness=0.8),
        "accent": get_material(f"{spec['faction']}_accent", [c * 0.8 for c in faction["body"]], roughness=0.8),
        "dark": get_material("dark", (0.07, 0.07, 0.07), roughness=0.9),
        "metal": get_material("metal", (0.25, 0.26, 0.27), roughness=0.5, metallic=0.6),
        "team": get_material(TEAM_MATERIAL, palette["team_color_preview"], roughness=0.6),
        "glass": get_material("glass", (0.12, 0.18, 0.22), roughness=0.2),
    }


def tracked(spec, palette):
    """Tracked vehicle: tank, howitzer or tracked troop carrier."""
    m = _materials(spec, palette)
    length, width, height = spec["length"], spec["width"], spec["height"]
    track_w = width * 0.22
    track_h = height * 0.45
    hull_h = height * 0.45
    hull = box("hull", (width * 0.78, length * 0.94, hull_h), (0, 0, track_h * 0.8 + hull_h / 2), m["body"])
    for side, sx in (("l", -1), ("r", 1)):
        box(f"track_{side}", (track_w, length, track_h), (sx * (width - track_w) / 2, 0, track_h / 2), m["dark"], hull)
    hull_top = track_h * 0.8 + hull_h
    _extras(spec, m, hull, width, length, hull_top)
    if not spec.get("turret", True):
        # No turret to carry the team color: put panels on the hull sides.
        for side, sx in (("l", -1), ("r", 1)):
            box(f"team_panel_{side}", (0.05, length * 0.5, hull_h * 0.5), (sx * (width * 0.39 + 0.03), 0, track_h * 0.8 + hull_h / 2), m["team"], hull)
        return
    ts = spec.get("turret_scale", 1.0)
    t_w, t_l, t_h = width * 0.6 * ts, length * 0.4 * ts, height * 0.32 * ts
    t_y = length * spec.get("turret_offset", 0.06)
    turret = box("turret", (t_w, t_l, t_h), (0, t_y, hull_top + t_h / 2), m["accent"], hull)
    for side, sx in (("l", -1), ("r", 1)):
        box(f"team_panel_{side}", (0.05, t_l * 0.6, t_h * 0.55), (sx * (t_w / 2 + 0.03), t_y, hull_top + t_h / 2), m["team"], turret)
    barrel_len = spec.get("barrel_length", length * 0.55)
    barrel_r = spec.get("barrel_radius", 0.09)
    barrel_y = t_y - t_l / 2 - barrel_len / 2
    if barrel_len > 0:
        barrel = cylinder("barrel", barrel_r, barrel_len, (0, barrel_y, hull_top + t_h * 0.55), m["metal"], axis="Y", parent=turret)
        empty("muzzle_0", (0, barrel_y - barrel_len / 2, hull_top + t_h * 0.55), parent=barrel)
    _turret_extras(spec, m, turret, t_w, t_l, t_h, t_y, hull_top)
    if spec.get("aps"):
        _aps_parts(m, turret, "", t_w, t_l, t_h, t_y, hull_top)
    if spec.get("cage"):
        _cage_parts(m, turret, "", t_w, t_l, t_h, t_y, hull_top)
    # Upgrade attachments (P2-05): hidden in the game until the upgrade is owned.
    for part in spec.get("upgrade_parts", []):
        holder = empty("upg_" + part, (0, t_y, hull_top + t_h), parent=turret)
        if part == "aps":
            _aps_parts(m, holder, "upg_", t_w, t_l, t_h, t_y, hull_top)
        elif part == "cage":
            _cage_parts(m, holder, "upg_", t_w, t_l, t_h, t_y, hull_top)
    # Pivots last, once every part hangs off the turret and barrel.
    set_origin(turret, (0, t_y, hull_top))
    if barrel_len > 0:
        set_origin(barrel, (0, barrel_y + barrel_len / 2, hull_top + t_h * 0.55))


def _aps_parts(m, parent, prefix, t_w, t_l, t_h, t_y, hull_top):
    """Active protection launchers on the turret corners."""
    for i, (sx, sy) in enumerate(((-1, -1), (1, -1), (-1, 1), (1, 1))):
        box(f"{prefix}aps_{i}", (0.25, 0.25, 0.18), (sx * t_w * 0.45, t_y + sy * t_l * 0.4, hull_top + t_h + 0.09), m["metal"], parent)


def _cage_parts(m, parent, prefix, t_w, t_l, t_h, t_y, hull_top):
    """Anti-drone cage: a frame of thin bars above the turret."""
    cage_z = hull_top + t_h + 0.55
    for i, sx in enumerate((-1, 1)):
        box(f"{prefix}cage_rail_{i}", (0.05, t_l * 1.3, 0.05), (sx * t_w * 0.6, t_y, cage_z), m["metal"], parent)
    for i, sy in enumerate((-1, 0, 1)):
        box(f"{prefix}cage_bar_{i}", (t_w * 1.2, 0.05, 0.05), (0, t_y + sy * t_l * 0.6, cage_z), m["metal"], parent)
    for i, (sx, sy) in enumerate(((-1, -1), (1, -1), (-1, 1), (1, 1))):
        box(f"{prefix}cage_post_{i}", (0.05, 0.05, 0.55), (sx * t_w * 0.6, t_y + sy * t_l * 0.6, cage_z - 0.27), m["metal"], parent)


def wheeled(spec, palette):
    """Wheeled vehicle: trucks, light vehicles, launchers."""
    m = _materials(spec, palette)
    length, width, height = spec["length"], spec["width"], spec["height"]
    axles = spec.get("axles", 2)
    wheel_r = height * 0.22
    body_z = wheel_r * 1.2
    body = box("body", (width * 0.92, length * 0.68, height * 0.45), (0, length * 0.14, body_z + height * 0.22), m["body"])
    cab_l = length * 0.28
    cab = box("cab", (width * 0.92, cab_l, height * 0.62), (0, -length / 2 + cab_l / 2, body_z + height * 0.31), m["body"], body)
    box("windshield", (width * 0.8, 0.05, height * 0.22), (0, -length / 2 - 0.02, body_z + height * 0.45), m["glass"], cab)
    for side, sx in (("l", -1), ("r", 1)):
        box(f"team_door_{side}", (0.04, cab_l * 0.6, height * 0.25), (sx * (width * 0.46 + 0.02), -length / 2 + cab_l / 2, body_z + height * 0.25), m["team"], cab)
    for a in range(axles):
        y = -length * 0.32 + a * (length * 0.68 / max(axles - 1, 1))
        for side, sx in (("l", -1), ("r", 1)):
            cylinder(f"wheel_{side}{a}", wheel_r, width * 0.16, (sx * width * 0.42, y, wheel_r), m["dark"], axis="X", parent=body)
    _extras(spec, m, body, width, length, body_z + height * 0.45)
    cargo = spec.get("cargo")
    if cargo == "armored":
        box("armor_box", (width * 0.9, length * 0.6, height * 0.5), (0, length * 0.16, body_z + height * 0.65), m["accent"], body)
    elif cargo == "crates":
        for i in range(3):
            box(f"crate_{i}", (width * 0.7, length * 0.18, height * 0.3), (0, length * (0.0 + i * 0.2), body_z + height * 0.6), m["metal"], body)
    elif cargo == "launcher":
        launcher = box("launcher", (width * 0.8, length * 0.55, height * 0.35), (0, length * 0.15, body_z + height * 0.75), m["metal"], body)
        set_origin(launcher, (0, length * 0.42, body_z + height * 0.6))
        launcher.rotation_euler = (-0.35, 0, 0)
    elif cargo == "pods":
        # Two rocket pods on a turntable, raised toward the front.
        table = cylinder("turret", width * 0.3, 0.2, (0, length * 0.2, body_z + height * 0.55), m["metal"], parent=body)
        pods = box("barrel", (width * 0.06, length * 0.4, 0.1), (0, length * 0.2, body_z + height * 0.68), m["metal"], table)
        for i, sx in enumerate((-1, 1)):
            box(f"pod_{i}", (width * 0.38, length * 0.42, height * 0.3), (sx * width * 0.2, length * 0.2, body_z + height * 0.8), m["accent"], pods)
            empty(f"muzzle_{i}", (sx * width * 0.2, length * 0.0, body_z + height * 0.8), parent=pods)
        set_origin(table, (0, length * 0.2, body_z + height * 0.55))
        set_origin(pods, (0, length * 0.38, body_z + height * 0.68))
        pods.rotation_euler = (-0.45, 0, 0)
    elif cargo == "laser":
        head_z = body_z + height * 0.6 + width * 0.2
        mount = cylinder("turret", width * 0.25, 0.3, (0, length * 0.2, body_z + height * 0.6), m["metal"], parent=body)
        head = box("barrel", (width * 0.35, width * 0.35, width * 0.3), (0, length * 0.2, head_z), m["accent"], mount)
        cylinder("laser_lens", width * 0.1, 0.1, (0, length * 0.2 - width * 0.2, head_z), m["glass"], axis="Y", parent=head)
        empty("muzzle_0", (0, length * 0.2 - width * 0.26, head_z), parent=head)
        set_origin(mount, (0, length * 0.2, body_z + height * 0.45))
        set_origin(head, (0, length * 0.2, head_z))
    elif cargo == "ew":
        shelter = box("ew_shelter", (width * 0.88, length * 0.55, height * 0.55), (0, length * 0.16, body_z + height * 0.67), m["accent"], body)
        for i, (sx, h) in enumerate(((-1, 2.4), (1, 1.8), (0, 3.0))):
            cylinder(f"antenna_{i}", 0.05, h, (sx * width * 0.3, length * (0.05 + 0.12 * i), body_z + height * 0.95 + h / 2), m["metal"], parent=shelter)
        sphere("ew_dome", width * 0.22, (0, length * 0.34, body_z + height * 0.98), m["metal"], scale=(1, 1, 0.6), parent=shelter)


def infantry(spec, palette):
    """A small squad of low-poly soldiers, scaled up for readability."""
    m = _materials(spec, palette)
    figures = spec.get("figures", 4)
    s = spec.get("scale", 1.3)
    spacing = 0.9 * s
    cols = 2
    for i in range(figures):
        ox = ((i % cols) - (cols - 1) / 2) * spacing
        oy = ((i // cols) - ((figures - 1) // cols) / 2) * spacing
        legs = box(f"soldier_{i}", (0.32 * s, 0.22 * s, 0.85 * s), (ox, oy, 0.425 * s), m["dark"])
        box(f"torso_{i}", (0.42 * s, 0.26 * s, 0.6 * s), (ox, oy, 1.15 * s), m["body"], legs)
        box(f"vest_{i}", (0.44 * s, 0.2 * s, 0.32 * s), (ox, oy + 0.06 * s, 1.18 * s), m["team"], legs)
        sphere(f"head_{i}", 0.13 * s, (ox, oy, 1.6 * s), m["body"], parent=legs)
        sphere(f"helmet_{i}", 0.15 * s, (ox, oy, 1.66 * s), m["body"], scale=(1.0, 1.0, 0.65), parent=legs)
        weapon = spec.get("weapon", "rifle")
        if weapon == "launcher" and i % 2 == 0:
            cylinder(f"launcher_{i}", 0.09 * s, 1.1 * s, (ox + 0.2 * s, oy - 0.1 * s, 1.5 * s), m["accent"], axis="Y", parent=legs)
        elif weapon == "drone_case" and i % 2 == 0:
            box(f"case_{i}", (0.5 * s, 0.25 * s, 0.6 * s), (ox, oy + 0.3 * s, 1.2 * s), m["accent"], legs)
        else:
            box(f"rifle_{i}", (0.06 * s, 0.75 * s, 0.08 * s), (ox + 0.22 * s, oy - 0.25 * s, 1.15 * s), m["metal"], legs)


def drone(spec, palette):
    """Quadcopter or small fixed-wing drone. Hover height is handled in Godot."""
    m = _materials(spec, palette)
    size = spec.get("size", 1.2)
    if spec.get("wing"):
        body = box("body", (size * 0.16, size * 0.8, size * 0.14), (0, 0, size * 0.1), m["body"])
        box("wing", (size * 1.4, size * 0.2, 0.03), (0, -size * 0.05, size * 0.15), m["accent"], body)
        box("tail", (size * 0.5, size * 0.1, 0.03), (0, size * 0.36, size * 0.15), m["accent"], body)
        box("team_plate", (size * 0.12, size * 0.3, 0.02), (0, 0, size * 0.18), m["team"], body)
        cylinder("prop", size * 0.12, 0.02, (0, size * 0.42, size * 0.1), m["metal"], axis="Y", parent=body)
        box("camera_pod", (size * 0.1, size * 0.1, size * 0.08), (0, -size * 0.3, size * 0.0), m["glass"], body)
        return
    body = box("body", (size * 0.35, size * 0.5, size * 0.15), (0, 0, size * 0.1), m["body"])
    box("team_plate", (size * 0.25, size * 0.3, 0.02), (0, 0, size * 0.18), m["team"], body)
    for i, (sx, sy) in enumerate(((-1, -1), (1, -1), (-1, 1), (1, 1))):
        box(f"arm_{i}", (size * 0.08, size * 0.08, size * 0.04), (sx * size * 0.3, sy * size * 0.3, size * 0.12), m["dark"], body)
        cylinder(f"rotor_{i}", size * 0.2, 0.02, (sx * size * 0.42, sy * size * 0.42, size * 0.16), m["metal"], parent=body)
    box("camera_pod", (size * 0.1, size * 0.1, size * 0.1), (0, -size * 0.22, size * 0.02), m["glass"], body)


def building(spec, palette):
    """Generic structure: base slab, main block, team-color band, details."""
    m = _materials(spec, palette)
    w, d, h = spec["width"], spec["depth"], spec["height"]
    style = spec.get("style", "block")
    if style != "block":
        STYLES[style](spec, m, w, d, h)
        return
    base = box("base", (w, d, 0.3), (0, 0, 0.15), m["metal"])
    main = box("main", (w * 0.8, d * 0.7, h), (0, d * 0.05, 0.3 + h / 2), m["body"], base)
    box("team_band", (w * 0.82, d * 0.72, h * 0.12), (0, d * 0.05, 0.3 + h * 0.7), m["team"], main)
    box("door", (w * 0.25, 0.1, h * 0.45), (0, -d * 0.3 - 0.05, 0.3 + h * 0.225), m["dark"], main)
    details = spec.get("details", [])
    if "mast" in details:
        cylinder("mast", 0.12, h * 0.9, (w * 0.25, d * 0.2, 0.3 + h + h * 0.45), m["metal"], parent=main)
        sphere("dish", 0.6, (w * 0.25, d * 0.2, 0.3 + h * 1.9), m["metal"], scale=(1.0, 0.35, 1.0), parent=main)
    if "vents" in details:
        for i in range(3):
            box(f"vent_{i}", (w * 0.12, d * 0.12, 0.4), (-w * 0.25 + i * w * 0.15, d * 0.15, 0.3 + h + 0.2), m["dark"], main)
    if "garage" in details:
        # Wide vehicle doors along the front.
        for i, sx in enumerate((-1, 1)):
            box(f"garage_{i}", (w * 0.28, 0.12, h * 0.7), (sx * w * 0.2, -d * 0.3 - 0.06, 0.3 + h * 0.35), m["dark"], main)
    if "reactor" in details:
        cylinder("reactor_drum", min(w, d) * 0.22, h * 0.6, (w * 0.18, d * 0.1, 0.3 + h + h * 0.3), m["metal"], segments=16, parent=main)
        sphere("reactor_cap", min(w, d) * 0.22, (w * 0.18, d * 0.1, 0.3 + h * 1.6), m["metal"], scale=(1, 1, 0.5), parent=main)
    if "stacks" in details:
        for i, sx in enumerate((-1, 1)):
            cylinder(f"stack_{i}", min(w, d) * 0.12, h * 1.2, (sx * w * 0.22, d * 0.2, 0.3 + h + h * 0.6), m["accent"], segments=12, parent=main)
    if "tanks" in details:
        for i in range(2):
            cylinder(f"fuel_tank_{i}", d * 0.12, w * 0.3, (w * 0.45, -d * 0.2 + i * d * 0.3, d * 0.13 + 0.3), m["metal"], axis="X", parent=base)
    if "pad" in details:
        pad = box("pad", (w * 0.45, d * 0.45, 0.12), (-w * 0.25, -d * 0.25, 0.36), m["dark"], base)
        box("pad_mark", (w * 0.25, w * 0.04, 0.02), (-w * 0.25, -d * 0.25, 0.43), m["team"], pad)
    if "dish" in details:
        sphere("dish_big", min(w, d) * 0.18, (-w * 0.25, d * 0.2, 0.3 + h + 0.6), m["metal"], scale=(1.0, 0.3, 1.0), parent=main)
    if "flag" in details:
        cylinder("flagpole", 0.06, h * 1.4, (-w * 0.42, -d * 0.42, 0.3 + h * 0.7), m["metal"], parent=base)
        box("flag", (0.03, 1.2, 0.7), (-w * 0.42, -d * 0.42 + 0.6, 0.3 + h * 1.25), m["team"], base)


def _bunker(spec, m, w, d, h):
    """Low concrete bunker with a sloped front and a firing slit."""
    base = box("base", (w, d, 0.3), (0, 0, 0.15), m["metal"])
    main = box("main", (w * 0.85, d * 0.8, h), (0, d * 0.05, 0.3 + h / 2), m["body"], base)
    slope = box("slope", (w * 0.85, d * 0.3, h * 0.6), (0, -d * 0.3, 0.3 + h * 0.3), m["accent"], main)
    set_origin(slope, (0, -d * 0.3, 0.3 + h * 0.3))
    slope.rotation_euler = (-0.5, 0, 0)
    box("slit", (w * 0.5, 0.1, h * 0.12), (0, -d * 0.36, 0.3 + h * 0.72), m["dark"], main)
    box("team_band", (w * 0.87, d * 0.4, h * 0.12), (0, d * 0.25, 0.3 + h * 0.9), m["team"], main)
    empty("muzzle_0", (0, -d * 0.4, 0.3 + h * 0.72), parent=main)


def _trench(spec, m, w, d, h):
    """A line of sandbag walls along the width, open to the rear."""
    base = box("base", (w, d, 0.1), (0, 0, 0.05), m["dark"])
    for i, sy in enumerate((-1, 1)):
        box(f"wall_{i}", (w, d * 0.22, h), (0, sy * d * 0.38, 0.1 + h / 2), m["body"], base)
    for i in range(int(w // 2)):
        box(f"sandbag_{i}", (1.6, d * 0.25, 0.25), (-w / 2 + 1 + i * 2, -d * 0.38, 0.1 + h + 0.12), m["accent"], base)
    box("team_post", (0.2, 0.2, h * 1.6), (w * 0.45, d * 0.38, 0.1 + h * 0.8), m["team"], base)
    empty("muzzle_0", (0, -d * 0.45, 0.1 + h), parent=base)


def _sam(spec, m, w, d, h):
    """Air-defense site: slab, turntable, an angled launcher box and a radar."""
    base = box("base", (w, d, 0.3), (0, 0, 0.15), m["metal"])
    table = cylinder("turret", min(w, d) * 0.3, 0.4, (0, d * 0.05, 0.5), m["accent"], segments=16, parent=base)
    rack = box("barrel", (w * 0.5, d * 0.55, h * 0.45), (0, d * 0.05, 0.7 + h * 0.3), m["body"], table)
    for i, (sx, sz) in enumerate(((-1, -1), (1, -1), (-1, 1), (1, 1))):
        cylinder(f"tube_{i}", w * 0.08, 0.1, (sx * w * 0.12, -d * 0.24, 0.7 + h * 0.3 + sz * h * 0.1), m["dark"], axis="Y", parent=rack)
        empty(f"muzzle_{i}", (sx * w * 0.12, -d * 0.26, 0.7 + h * 0.3 + sz * h * 0.1), parent=rack)
    box("team_band", (w * 0.52, d * 0.1, h * 0.1), (0, d * 0.3, 0.7 + h * 0.4), m["team"], rack)
    set_origin(table, (0, d * 0.05, 0.3))
    set_origin(rack, (0, d * 0.05, 0.7 + h * 0.3))
    rack.rotation_euler = (-0.6, 0, 0)
    cylinder("radar_mast", 0.08, h * 0.8, (w * 0.4, d * 0.38, 0.3 + h * 0.4), m["metal"], parent=base)
    box("radar_panel", (w * 0.25, 0.08, h * 0.3), (w * 0.4, d * 0.36, 0.3 + h * 0.85), m["dark"], base)


STYLES = {"bunker": _bunker, "trench": _trench, "sam": _sam}


def _extras(spec, m, parent, width, length, top):
    """Optional hull add-ons shared by tracked and wheeled vehicles."""
    extras = spec.get("extras", [])
    if "dozer_blade" in extras:
        box("dozer_blade", (width * 1.05, 0.25, top * 0.55), (0, -length / 2 - 0.3, top * 0.3), m["metal"], parent)
    if "crane" in extras:
        boom = box("crane_boom", (0.3, length * 0.6, 0.3), (width * 0.2, length * 0.05, top + 0.9), m["accent"], parent)
        set_origin(boom, (width * 0.2, length * 0.3, top + 0.6))
        boom.rotation_euler = (-0.35, 0, 0)
        box("crane_base", (0.8, 0.8, 0.6), (width * 0.2, length * 0.3, top + 0.3), m["accent"], parent)
    if "antennas" in extras:
        for i, sx in enumerate((-1, 1)):
            cylinder(f"whip_{i}", 0.03, 2.2, (sx * width * 0.35, length * 0.4, top + 1.1), m["metal"], parent=parent)
    if "rear_door" in extras:
        box("rear_door", (width * 0.5, 0.08, top * 0.5), (0, length / 2 + 0.04, top * 0.6), m["dark"], parent)


def _turret_extras(spec, m, turret, t_w, t_l, t_h, t_y, hull_top):
    """Optional turret add-ons (missile launcher box, sensor sight)."""
    extras = spec.get("turret_extras", [])
    if "missile_box" in extras:
        box("missile_box", (t_w * 0.3, t_l * 0.7, t_h * 0.5), (t_w * 0.5 + t_w * 0.15, t_y, hull_top + t_h * 0.8), m["metal"], turret)
    if "sight" in extras:
        box("sight", (t_w * 0.2, t_l * 0.2, t_h * 0.4), (-t_w * 0.25, t_y - t_l * 0.2, hull_top + t_h + t_h * 0.2), m["glass"], turret)


ARCHETYPES = {
    "tracked": tracked,
    "wheeled": wheeled,
    "infantry": infantry,
    "drone": drone,
    "building": building,
}
