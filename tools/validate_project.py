#!/usr/bin/env python3
"""Static project validation for machines without Godot installed."""

from __future__ import annotations

import json
import re
import struct
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
RES_PATH_RE = re.compile(r"res://[^\s\"')\],}]+")
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
WAV_SIGNATURE = b"RIFF"
WAVE_SIGNATURE = b"WAVE"

MAP_REFERENCE_ASSETS = {
    "post_office": ROOT / "assets" / "maps" / "post_office_reference.png",
    "rainlamp_street": ROOT / "assets" / "maps" / "rainlamp_street_reference.png",
    "bakery": ROOT / "assets" / "maps" / "bakery_reference.png",
    "old_stone_bridge": ROOT / "assets" / "maps" / "old_stone_bridge_reference.png",
    "memory_bridge": ROOT / "assets" / "maps" / "memory_bridge_reference.png",
    "clocktower_exterior": ROOT / "assets" / "maps" / "clocktower_exterior_reference.png",
}

CRITICAL_INTERACTABLE_IDS = {
    "post_office_handbook",
    "post_office_first_letter",
    "post_office_empty_mailbox",
    "bakery_counter",
    "bakery_red_bean_bun",
    "bakery_linmo_drawer",
    "old_bridge_lamp",
    "old_bridge_cloth_bag",
    "memory_bridge_mailbox",
    "memory_bridge_unsent_letter",
    "memory_bridge_lamp",
    "memory_bridge_truth_pool",
    "memory_bridge_boss_trigger",
    "clocktower_red_bean_bun",
    "clocktower_lit_lamp",
    "clocktower_thirteenth_letter",
    "clocktower_old_door",
    "clocktower_wet_stairs",
}


@dataclass
class Reporter:
    errors: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)
    infos: list[str] = field(default_factory=list)

    def error(self, message: str) -> None:
        self.errors.append(message)

    def warning(self, message: str) -> None:
        self.warnings.append(message)

    def info(self, message: str) -> None:
        self.infos.append(message)


@dataclass
class MainlineRecord:
    source: str
    required_flags: set[str] = field(default_factory=set)
    blocked_by_flags: set[str] = field(default_factory=set)
    grant_flags: set[str] = field(default_factory=set)
    start_encounters: set[str] = field(default_factory=set)


MAINLINE_KEY_FLAGS = [
    "postman_handbook_obtained",
    "letter_001_received",
    "tutorial_battle_01_cleared",
    "found_wenheng_bridge",
    "bakery_lie_discovered",
    "tutorial_battle_02_cleared",
    "bridge_memory_unlocked",
    "boss_return_letter_started",
    "letter_001_sent",
    "thirteenth_letter_seen",
]

MAINLINE_STEPS = [
    ("postman_handbook_obtained", "flag"),
    ("letter_001_received", "flag"),
    ("tutorial_battle_01_cleared", "encounter:enc_tutorial_wet_paper"),
    ("found_wenheng_bridge", "flag"),
    ("bakery_lie_discovered", "flag"),
    ("tutorial_battle_02_cleared", "encounter:enc_tutorial_bridge_lamp"),
    ("bridge_memory_unlocked", "flag"),
    ("memory_bridge_seen", "flag"),
    ("memory_mailbox_seen", "flag"),
    ("memory_unsent_letter_seen", "flag"),
    ("memory_truth_line_seen", "flag"),
    ("boss_return_letter_started", "flag"),
    ("letter_001_sent", "encounter:enc_boss_return_letter"),
    ("thirteenth_letter_seen", "flag"),
]


def rel(path: Path) -> str:
    try:
        return path.resolve().relative_to(ROOT).as_posix()
    except ValueError:
        return path.as_posix()


def res_to_path(value: str) -> Path:
    return ROOT / value.removeprefix("res://")


def iter_files(*suffixes: str) -> list[Path]:
    skipped = {".git"}
    result: list[Path] = []
    for path in ROOT.rglob("*"):
        if any(part in skipped for part in path.parts):
            continue
        if path.is_file() and path.suffix.lower() in suffixes:
            result.append(path)
    return sorted(result)


def load_json_files(reporter: Reporter) -> dict[Path, Any]:
    parsed: dict[Path, Any] = {}
    for path in iter_files(".json"):
        try:
            text = path.read_text(encoding="utf-8-sig")
        except UnicodeDecodeError as exc:
            reporter.error(f"JSON UTF-8 decode failed: {rel(path)} ({exc})")
            continue
        try:
            parsed[path] = json.loads(text)
        except json.JSONDecodeError as exc:
            reporter.error(
                f"JSON parse failed: {rel(path)} line {exc.lineno}, column {exc.colno}: {exc.msg}"
            )
    return parsed


def validate_res_paths(reporter: Reporter) -> int:
    checked = 0
    files = [ROOT / "project.godot"] + iter_files(".tscn", ".gd")
    for path in files:
        if not path.exists():
            continue
        try:
            text = path.read_text(encoding="utf-8-sig")
        except UnicodeDecodeError as exc:
            reporter.error(f"Text UTF-8 decode failed while scanning res:// paths: {rel(path)} ({exc})")
            continue
        for match in RES_PATH_RE.finditer(text):
            res_path = match.group(0).rstrip(".,;:")
            if "%" in res_path or "{" in res_path or "}" in res_path:
                continue
            checked += 1
            if not res_to_path(res_path).exists():
                reporter.error(f"Missing res:// target in {rel(path)}: {res_path}")
    return checked


def collection_by_id(root: Any, key: str | None = None) -> dict[str, dict[str, Any]]:
    if key is None:
        items = root if isinstance(root, list) else [root]
    elif isinstance(root, dict):
        items = root.get(key, [])
    else:
        items = []
    if not isinstance(items, list):
        return {}

    result: dict[str, dict[str, Any]] = {}
    for item in items:
        if isinstance(item, dict) and isinstance(item.get("id"), str):
            result[item["id"]] = item
    return result


def load_maps(parsed: dict[Path, Any]) -> dict[str, dict[str, Any]]:
    maps: dict[str, dict[str, Any]] = {}
    maps_dir = ROOT / "data" / "maps"
    for path, data in parsed.items():
        if path.parent == maps_dir and isinstance(data, dict) and isinstance(data.get("id"), str):
            maps[data["id"]] = data
    return maps


def load_enemies(parsed: dict[Path, Any]) -> dict[str, dict[str, Any]]:
    enemies: dict[str, dict[str, Any]] = {}
    enemies_dir = ROOT / "data" / "enemies"
    for path, data in parsed.items():
        if path.parent == enemies_dir and isinstance(data, dict) and isinstance(data.get("id"), str):
            enemies[data["id"]] = data
    return enemies


def load_dialogue_ids(parsed: dict[Path, Any], interactable_ids: set[str]) -> set[str]:
    dialogue_ids: set[str] = set()
    dialogues_dir = ROOT / "data" / "dialogues"
    for path, data in parsed.items():
        if path.parent == dialogues_dir and isinstance(data, dict) and isinstance(data.get("id"), str):
            dialogue_ids.add(data["id"])

    npc_data = parsed.get(ROOT / "data" / "npcs" / "vertical_slice_npcs.json", {})
    for npc in collection_by_id(npc_data, "npcs").values():
        dialogues = npc.get("dialogues", [])
        if isinstance(dialogues, list):
            for dialogue in dialogues:
                if isinstance(dialogue, dict) and isinstance(dialogue.get("id"), str):
                    dialogue_ids.add(dialogue["id"])

    dialogue_ids.update(interactable_ids)
    return dialogue_ids


def load_interactable_ids(parsed: dict[Path, Any], reporter: Reporter) -> set[str]:
    path = ROOT / "data" / "interactables" / "vertical_slice_interactables.json"
    root = parsed.get(path, {})
    ids: set[str] = set()
    grouped = root.get("interactables_by_map", {}) if isinstance(root, dict) else {}
    if not isinstance(grouped, dict):
        reporter.error(f"Interactables root has no dictionary interactables_by_map: {rel(path)}")
        return ids
    for map_id, items in grouped.items():
        if not isinstance(items, list):
            reporter.error(f"Interactables for map {map_id!r} must be a list: {rel(path)}")
            continue
        for item in items:
            if isinstance(item, dict) and isinstance(item.get("id"), str):
                ids.add(item["id"])
            else:
                reporter.error(f"Interactable item without string id under map {map_id!r}: {rel(path)}")
    return ids


def map_scene_exists(map_data: dict[str, Any]) -> bool:
    scene_id = str(map_data.get("scene_id", "")).strip()
    if not scene_id:
        return False
    candidates = [
        ROOT / "scenes" / "maps" / f"{scene_id}_Reference.tscn",
        ROOT / "scenes" / "maps" / f"{scene_id}.tscn",
    ]
    return any(path.exists() for path in candidates)


def validate_area_rect(reporter: Reporter, owner: str, value: Any) -> None:
    if not isinstance(value, dict):
        reporter.error(f"{owner} area must be an object")
        return
    for key in ["x", "y", "w", "h"]:
        if not isinstance(value.get(key), (int, float)):
            reporter.error(f"{owner} area.{key} must be numeric")
    if isinstance(value.get("w"), (int, float)) and value["w"] <= 0:
        reporter.error(f"{owner} area.w must be > 0")
    if isinstance(value.get("h"), (int, float)) and value["h"] <= 0:
        reporter.error(f"{owner} area.h must be > 0")


def _dimensions_from(map_data: dict[str, Any]) -> tuple[float, float]:
    dimensions = map_data.get("dimensions", {})
    if not isinstance(dimensions, dict):
        return 0.0, 0.0
    width = dimensions.get("width", 0)
    height = dimensions.get("height", 0)
    if not isinstance(width, (int, float)) or not isinstance(height, (int, float)):
        return 0.0, 0.0
    return float(width), float(height)


def _rect_tuple(value: Any) -> tuple[float, float, float, float] | None:
    if not isinstance(value, dict):
        return None
    keys = ["x", "y", "w", "h"]
    if not all(isinstance(value.get(key), (int, float)) for key in keys):
        return None
    return float(value["x"]), float(value["y"]), float(value["w"]), float(value["h"])


def _position_tuple(value: Any) -> tuple[float, float] | None:
    if not isinstance(value, dict):
        return None
    if not isinstance(value.get("x"), (int, float)) or not isinstance(value.get("y"), (int, float)):
        return None
    return float(value["x"]), float(value["y"])


def _contains_rect(outer: tuple[float, float, float, float], inner: tuple[float, float, float, float]) -> bool:
    ox, oy, ow, oh = outer
    ix, iy, iw, ih = inner
    epsilon = 0.001
    return (
        ix >= ox - epsilon
        and iy >= oy - epsilon
        and ix + iw <= ox + ow + epsilon
        and iy + ih <= oy + oh + epsilon
    )


def _trigger_rect(item: dict[str, Any]) -> tuple[float, float, float, float] | None:
    area = _rect_tuple(item.get("area"))
    if area is not None:
        return area
    position = _position_tuple(item.get("position"))
    radius = item.get("radius", 0)
    if position is None or not isinstance(radius, (int, float)) or radius <= 0:
        return None
    x, y = position
    r = float(radius)
    return x - r, y - r, r * 2.0, r * 2.0


def validate_map_reference_scales(
    reporter: Reporter,
    maps: dict[str, dict[str, Any]],
) -> None:
    for map_id, image_path in sorted(MAP_REFERENCE_ASSETS.items()):
        map_data = maps.get(map_id)
        if map_data is None:
            reporter.error(f"Map reference scale check references missing map: {map_id}")
            continue
        if not image_path.exists():
            reporter.error(f"Map {map_id} missing reference PNG for scale check: {rel(image_path)}")
            continue
        try:
            texture_width, texture_height, _color_type, _has_alpha = png_info(image_path)
        except (OSError, ValueError) as exc:
            reporter.error(f"Map {map_id} reference PNG cannot be read for scale check: {rel(image_path)} ({exc})")
            continue

        design_width, design_height = _dimensions_from(map_data)
        if design_width <= 0 or design_height <= 0:
            reporter.error(f"Map {map_id} has invalid dimensions for scale check")
            continue
        scale_x = texture_width / design_width
        scale_y = texture_height / design_height
        reporter.info(
            f"Map {map_id} scale sanity: dimensions={design_width:.0f}x{design_height:.0f}, "
            f"texture={texture_width}x{texture_height}, scale={scale_x:.3f}x{scale_y:.3f}"
        )
        if abs(scale_x - scale_y) > 0.02 or abs(scale_x - 1.0) > 0.02 or abs(scale_y - 1.0) > 0.02:
            reporter.error(
                f"Map {map_id} dimensions do not match baked texture scale: "
                f"dimensions={design_width:.0f}x{design_height:.0f}, "
                f"texture={texture_width}x{texture_height}, scale={scale_x:.3f}x{scale_y:.3f}"
            )


def validate_interactable_reachability(
    reporter: Reporter,
    parsed: dict[Path, Any],
    maps: dict[str, dict[str, Any]],
) -> None:
    path = ROOT / "data" / "interactables" / "vertical_slice_interactables.json"
    root = parsed.get(path, {})
    grouped = root.get("interactables_by_map", {}) if isinstance(root, dict) else {}
    if not isinstance(grouped, dict):
        reporter.error(f"Interactables root has no dictionary interactables_by_map: {rel(path)}")
        return

    checked = 0
    for map_id, items in sorted(grouped.items()):
        if not isinstance(items, list):
            continue
        blocker_rects = []
        for blocker in maps.get(map_id, {}).get("blockers", []):
            if isinstance(blocker, dict):
                rect = _rect_tuple(blocker.get("area"))
                if rect is not None:
                    blocker_rects.append((str(blocker.get("id", "<unnamed>")), rect))

        for item in items:
            if not isinstance(item, dict):
                continue
            item_id = str(item.get("id", ""))
            if item_id not in CRITICAL_INTERACTABLE_IDS:
                continue
            checked += 1
            trigger = _trigger_rect(item)
            if trigger is None:
                reporter.error(f"Critical interactable {map_id}.{item_id} has no valid trigger area/radius")
                continue
            contained_by = [
                blocker_id
                for blocker_id, blocker_rect in blocker_rects
                if _contains_rect(blocker_rect, trigger)
            ]
            if contained_by:
                reporter.error(
                    f"Critical interactable {map_id}.{item_id} trigger is fully inside blocker(s): "
                    f"{', '.join(contained_by)}"
                )
            else:
                x, y, w, h = trigger
                reporter.info(
                    f"Critical interactable reachable: {map_id}.{item_id} "
                    f"trigger=({x:.1f},{y:.1f},{w:.1f},{h:.1f})"
                )
    reporter.info(f"Critical interactable reachability checked: {checked}")


def validate_maps(
    reporter: Reporter,
    maps: dict[str, dict[str, Any]],
    npc_ids: set[str],
    dialogue_ids: set[str],
    interactable_ids: set[str],
) -> None:
    for map_id, data in sorted(maps.items()):
        if not map_scene_exists(data):
            reporter.error(f"Map {map_id} has no runtime scene for scene_id: {data.get('scene_id')!r}")

        spawns = data.get("spawns", [])
        spawn_ids = {
            item.get("id")
            for item in spawns
            if isinstance(item, dict) and isinstance(item.get("id"), str)
        }

        for exit_data in data.get("exits", []) if isinstance(data.get("exits", []), list) else []:
            if not isinstance(exit_data, dict):
                reporter.error(f"Map {map_id} has a non-object exit")
                continue
            target_map_id = exit_data.get("target_map_id")
            target_spawn_id = exit_data.get("target_spawn_id")
            exit_id = exit_data.get("id", "<unnamed>")
            if target_map_id not in maps:
                reporter.error(f"Map {map_id} exit {exit_id} targets missing map: {target_map_id!r}")
                continue
            target_spawns = maps[target_map_id].get("spawns", [])
            target_spawn_ids = {
                item.get("id")
                for item in target_spawns
                if isinstance(item, dict) and isinstance(item.get("id"), str)
            }
            if target_spawn_id not in target_spawn_ids:
                reporter.error(
                    f"Map {map_id} exit {exit_id} targets missing spawn "
                    f"{target_map_id}.{target_spawn_id!r}"
                )

        default_spawn_id = data.get("default_spawn_id")
        if isinstance(default_spawn_id, str) and default_spawn_id not in spawn_ids:
            reporter.error(f"Map {map_id} default_spawn_id is missing from spawns: {default_spawn_id!r}")

        values = data.get("interactable_ids", [])
        if not isinstance(values, list):
            reporter.error(f"Map {map_id} interactable_ids must be a list")
        else:
            for interactable_id in values:
                if interactable_id not in interactable_ids:
                    reporter.error(f"Map {map_id} references missing interactable_id: {interactable_id!r}")

        npcs = data.get("npcs", [])
        if not isinstance(npcs, list):
            reporter.error(f"Map {map_id} npcs must be a list")
            continue
        for npc in npcs:
            if not isinstance(npc, dict):
                reporter.error(f"Map {map_id} has a non-object npc entry")
                continue
            instance_id = npc.get("instance_id", "<unnamed>")
            npc_id = npc.get("npc_id")
            if npc_id not in npc_ids:
                reporter.error(f"Map {map_id} npc {instance_id} references missing npc_id: {npc_id!r}")
            dialogue_id = npc.get("dialogue_id")
            if isinstance(dialogue_id, str) and dialogue_id and dialogue_id not in dialogue_ids:
                reporter.error(
                    f"Map {map_id} npc {instance_id} references missing dialogue_id: {dialogue_id!r}"
                )
            dialogue_ids_value = npc.get("dialogue_ids", [])
            if isinstance(dialogue_ids_value, list):
                for candidate in dialogue_ids_value:
                    if candidate not in dialogue_ids:
                        reporter.error(
                            f"Map {map_id} npc {instance_id} references missing dialogue_ids entry: {candidate!r}"
                        )
            elif "dialogue_ids" in npc:
                reporter.error(f"Map {map_id} npc {instance_id} dialogue_ids must be a list")

        blockers = data.get("blockers", [])
        if not isinstance(blockers, list):
            reporter.error(f"Map {map_id} blockers must be a list")
        elif not blockers:
            reporter.warning(f"Map {map_id} has no coarse collision blockers")
        else:
            for blocker in blockers:
                if not isinstance(blocker, dict):
                    reporter.error(f"Map {map_id} has a non-object blocker")
                    continue
                validate_area_rect(
                    reporter,
                    f"Map {map_id} blocker {blocker.get('id', '<unnamed>')}",
                    blocker.get("area"),
                )


def validate_encounters(
    reporter: Reporter,
    parsed: dict[Path, Any],
    enemy_ids: set[str],
) -> int:
    path = ROOT / "data" / "encounters" / "vertical_slice_encounters.json"
    encounters = collection_by_id(parsed.get(path, {}), "encounters")
    for encounter_id, encounter in sorted(encounters.items()):
        enemies = encounter.get("enemies", [])
        if not isinstance(enemies, list):
            reporter.error(f"Encounter {encounter_id} enemies must be a list")
            continue
        for enemy_id in enemies:
            if enemy_id not in enemy_ids:
                reporter.error(f"Encounter {encounter_id} references missing enemy: {enemy_id!r}")
        reward_flags = encounter.get("reward_flags", [])
        if reward_flags:
            reporter.info(f"Encounter {encounter_id} reward_flags: {', '.join(map(str, reward_flags))}")
    return len(encounters)


def _string_set(value: Any) -> set[str]:
    if isinstance(value, list):
        return {str(item) for item in value if str(item).strip()}
    if isinstance(value, str) and value.strip():
        return {value}
    return set()


def _effects_from(value: Any) -> tuple[set[str], set[str]]:
    grant_flags: set[str] = set()
    start_encounters: set[str] = set()
    if not isinstance(value, list):
        return grant_flags, start_encounters
    for raw_effect in value:
        effect = str(raw_effect).strip()
        if effect.startswith("flag:"):
            flag_id = effect.removeprefix("flag:").strip()
            if flag_id:
                grant_flags.add(flag_id)
        elif effect.startswith("encounter:"):
            encounter_id = effect.removeprefix("encounter:").strip()
            if encounter_id:
                start_encounters.add(encounter_id)
    return grant_flags, start_encounters


def _append_effect_record(
    records: list[MainlineRecord],
    source: str,
    required_flags: set[str],
    blocked_by_flags: set[str],
    effects: Any,
) -> None:
    grant_flags, start_encounters = _effects_from(effects)
    if grant_flags or start_encounters:
        records.append(
            MainlineRecord(
                source=source,
                required_flags=required_flags,
                blocked_by_flags=blocked_by_flags,
                grant_flags=grant_flags,
                start_encounters=start_encounters,
            )
        )


def _collect_dialogue_effect_records(path: Path, dialogue: dict[str, Any]) -> list[MainlineRecord]:
    records: list[MainlineRecord] = []
    dialogue_id = str(dialogue.get("id", rel(path)))
    required = _string_set(dialogue.get("required_flags", []))
    blocked = _string_set(dialogue.get("blocked_by_flags", []))
    _append_effect_record(records, f"dialogue:{dialogue_id}", required, blocked, dialogue.get("effects", []))
    lines = dialogue.get("lines", [])
    if isinstance(lines, list):
        for index, line in enumerate(lines):
            if isinstance(line, dict):
                _append_effect_record(
                    records,
                    f"dialogue:{dialogue_id}.line[{index}]",
                    required,
                    blocked,
                    line.get("effects", []),
                )
    return records


def collect_mainline_records(parsed: dict[Path, Any]) -> list[MainlineRecord]:
    records: list[MainlineRecord] = []

    interactables_path = ROOT / "data" / "interactables" / "vertical_slice_interactables.json"
    interactables_root = parsed.get(interactables_path, {})
    grouped = interactables_root.get("interactables_by_map", {}) if isinstance(interactables_root, dict) else {}
    if isinstance(grouped, dict):
        for map_id, items in grouped.items():
            if not isinstance(items, list):
                continue
            for item in items:
                if not isinstance(item, dict):
                    continue
                item_id = str(item.get("id", "<unnamed>"))
                required = _string_set(item.get("required_flags", []))
                blocked = _string_set(item.get("blocked_by_flags", []))
                _append_effect_record(
                    records,
                    f"interactable:{map_id}.{item_id}",
                    required,
                    blocked,
                    item.get("effects", []),
                )
                conditional_text = item.get("conditional_text", [])
                if isinstance(conditional_text, list):
                    for index, entry in enumerate(conditional_text):
                        if not isinstance(entry, dict):
                            continue
                        _append_effect_record(
                            records,
                            f"interactable:{map_id}.{item_id}.conditional[{index}]",
                            required | _string_set(entry.get("required_flags", [])),
                            blocked | _string_set(entry.get("blocked_by_flags", [])),
                            entry.get("effects", []),
                        )

    maps_dir = ROOT / "data" / "maps"
    for path, data in parsed.items():
        if path.parent != maps_dir or not isinstance(data, dict):
            continue
        map_id = str(data.get("id", rel(path)))
        flags = data.get("flags", {})
        if isinstance(flags, dict):
            grant_flags = _string_set(flags.get("on_enter", []))
            required_flags = _string_set(flags.get("required", []))
            if grant_flags:
                records.append(
                    MainlineRecord(
                        source=f"map:{map_id}.on_enter",
                        required_flags=required_flags,
                        grant_flags=grant_flags,
                    )
                )

    dialogues_dir = ROOT / "data" / "dialogues"
    for path, data in parsed.items():
        if path.parent == dialogues_dir and isinstance(data, dict):
            records.extend(_collect_dialogue_effect_records(path, data))

    npc_path = ROOT / "data" / "npcs" / "vertical_slice_npcs.json"
    npc_root = parsed.get(npc_path, {})
    for npc in collection_by_id(npc_root, "npcs").values():
        npc_id = str(npc.get("id", "<unnamed>"))
        dialogues = npc.get("dialogues", [])
        if not isinstance(dialogues, list):
            continue
        for dialogue in dialogues:
            if not isinstance(dialogue, dict):
                continue
            dialogue_copy = dict(dialogue)
            dialogue_copy["id"] = str(dialogue_copy.get("id", f"{npc_id}.dialogue"))
            records.extend(_collect_dialogue_effect_records(npc_path, dialogue_copy))

    return records


def _record_available(record: MainlineRecord, flags: set[str]) -> bool:
    return record.required_flags.issubset(flags) and record.blocked_by_flags.isdisjoint(flags)


def _apply_record(record: MainlineRecord, flags: set[str], started_encounters: set[str]) -> None:
    flags.update(record.grant_flags)
    started_encounters.update(record.start_encounters)


def validate_mainline_path(
    reporter: Reporter,
    parsed: dict[Path, Any],
) -> None:
    path = ROOT / "data" / "encounters" / "vertical_slice_encounters.json"
    encounters = collection_by_id(parsed.get(path, {}), "encounters")
    records = collect_mainline_records(parsed)
    flags: set[str] = set()
    started_encounters: set[str] = set()
    trace: list[str] = []

    for target, source_kind in MAINLINE_STEPS:
        if source_kind == "flag":
            candidates = [
                record
                for record in records
                if target in record.grant_flags and _record_available(record, flags)
            ]
            if not candidates:
                reporter.error(
                    "Mainline path cannot reach flag "
                    f"{target!r}; current flags: {', '.join(sorted(flags)) or '<none>'}"
                )
                return
            record = candidates[0]
            _apply_record(record, flags, started_encounters)
            trace.append(f"{target} <= {record.source}")
            continue

        encounter_id = source_kind.removeprefix("encounter:")
        encounter = encounters.get(encounter_id)
        if encounter is None:
            reporter.error(f"Mainline path references missing encounter: {encounter_id}")
            return

        if encounter_id not in started_encounters:
            trigger_candidates = [
                record
                for record in records
                if encounter_id in record.start_encounters and _record_available(record, flags)
            ]
            if not trigger_candidates:
                reporter.error(
                    f"Mainline path cannot start encounter {encounter_id!r} before reward "
                    f"{target!r}; current flags: {', '.join(sorted(flags)) or '<none>'}"
                )
                return
            trigger = trigger_candidates[0]
            _apply_record(trigger, flags, started_encounters)
            trace.append(f"start {encounter_id} <= {trigger.source}")

        required = _string_set(encounter.get("required_flags", []))
        rewards = _string_set(encounter.get("reward_flags", []))
        if not required.issubset(flags):
            missing = ", ".join(sorted(required - flags))
            reporter.error(f"Mainline encounter {encounter_id} is missing required flag(s): {missing}")
            return
        if target not in rewards:
            reporter.error(f"Mainline encounter {encounter_id} does not reward required flag: {target}")
            return
        flags.update(rewards)
        trace.append(f"{target} <= encounter:{encounter_id}.reward_flags")

    missing_key_flags = [flag for flag in MAINLINE_KEY_FLAGS if flag not in flags]
    if missing_key_flags:
        reporter.error(f"Mainline path missed key flag(s): {', '.join(missing_key_flags)}")
        return

    reporter.info("Mainline key flag path validated:")
    for entry in trace:
        reporter.info(f"  {entry}")


def png_info(path: Path) -> tuple[int, int, int, bool]:
    with path.open("rb") as file:
        if file.read(8) != PNG_SIGNATURE:
            raise ValueError("not a PNG file")
        length_data = file.read(4)
        chunk_type = file.read(4)
        if len(length_data) != 4 or chunk_type != b"IHDR":
            raise ValueError("missing IHDR chunk")
        length = struct.unpack(">I", length_data)[0]
        ihdr = file.read(length)
        file.read(4)
        if length != 13 or len(ihdr) != 13:
            raise ValueError("invalid IHDR chunk")
        width, height, bit_depth, color_type = struct.unpack(">IIBB", ihdr[:10])
        has_alpha = color_type in {4, 6}

        while True:
            length_data = file.read(4)
            if len(length_data) != 4:
                break
            chunk_length = struct.unpack(">I", length_data)[0]
            chunk_type = file.read(4)
            if len(chunk_type) != 4:
                break
            if chunk_type == b"tRNS":
                has_alpha = True
            file.seek(chunk_length + 4, 1)
            if chunk_type == b"IEND":
                break
        return width, height, color_type, has_alpha


def manifest_image_entries(parsed: dict[Path, Any], reporter: Reporter) -> list[tuple[Path, dict[str, Any], str]]:
    entries: list[tuple[Path, dict[str, Any], str]] = []
    manifest_paths = [
        ROOT / "assets" / "sprites" / "asset_manifest.json",
        ROOT / "assets" / "maps" / "map_asset_manifest.json",
    ]
    image_keys = {"path", "raw", "sheet"}
    for manifest_path in manifest_paths:
        root = parsed.get(manifest_path)
        assets = root.get("assets", []) if isinstance(root, dict) else []
        if not isinstance(assets, list):
            reporter.error(f"Asset manifest assets must be a list: {rel(manifest_path)}")
            continue
        for item in assets:
            if not isinstance(item, dict):
                reporter.error(f"Asset manifest contains a non-object item: {rel(manifest_path)}")
                continue
            asset_id = str(item.get("id", "<unnamed>"))
            for key in sorted(image_keys):
                value = item.get(key)
                if isinstance(value, str) and value.lower().endswith(".png"):
                    entries.append((ROOT / value, item, f"{asset_id}.{key}"))
    return entries


def validate_png_assets(reporter: Reporter, parsed: dict[Path, Any]) -> int:
    checked = 0
    for path, item, label in manifest_image_entries(parsed, reporter):
        checked += 1
        if not path.exists():
            reporter.error(f"Missing key PNG asset {label}: {rel(path)}")
            continue
        try:
            width, height, color_type, has_alpha = png_info(path)
        except OSError as exc:
            reporter.error(f"Cannot read key PNG asset {label}: {rel(path)} ({exc})")
            continue
        except ValueError as exc:
            reporter.error(f"Invalid key PNG asset {label}: {rel(path)} ({exc})")
            continue

        size = item.get("size")
        if isinstance(size, list) and len(size) == 2 and all(isinstance(v, int) for v in size):
            if [width, height] != size:
                reporter.warning(
                    f"PNG size differs from manifest for {label}: actual {width}x{height}, manifest {size[0]}x{size[1]}"
                )
        alpha_text = "alpha" if has_alpha else "no alpha"
        reporter.info(f"PNG {label}: {rel(path)} {width}x{height}, color_type={color_type}, {alpha_text}")
    return checked


def wav_info(path: Path) -> tuple[int, int, int]:
    with path.open("rb") as file:
        if file.read(4) != WAV_SIGNATURE:
            raise ValueError("missing RIFF header")
        file.seek(8)
        if file.read(4) != WAVE_SIGNATURE:
            raise ValueError("missing WAVE header")

        channels = 0
        sample_rate = 0
        data_size = 0
        while True:
            chunk_id = file.read(4)
            if len(chunk_id) != 4:
                break
            chunk_size_data = file.read(4)
            if len(chunk_size_data) != 4:
                break
            chunk_size = struct.unpack("<I", chunk_size_data)[0]
            chunk_start = file.tell()
            if chunk_id == b"fmt ":
                fmt = file.read(min(chunk_size, 16))
                if len(fmt) < 16:
                    raise ValueError("invalid fmt chunk")
                audio_format, channels, sample_rate = struct.unpack("<HHI", fmt[:8])
                bits_per_sample = struct.unpack("<H", fmt[14:16])[0]
                if audio_format != 1:
                    raise ValueError("only PCM WAV is supported")
                if bits_per_sample != 16:
                    raise ValueError("only 16-bit WAV is supported")
            elif chunk_id == b"data":
                data_size = chunk_size
            file.seek(chunk_start + chunk_size + (chunk_size % 2))

        if channels <= 0 or sample_rate <= 0 or data_size <= 0:
            raise ValueError("missing fmt or data chunk")
        return channels, sample_rate, data_size


def validate_wav_assets(reporter: Reporter) -> int:
    required_paths = [
        ROOT / "assets" / "audio" / "ambience" / "rain_loop.wav",
        ROOT / "assets" / "audio" / "sfx" / "dialogue_advance.wav",
        ROOT / "assets" / "audio" / "sfx" / "open_seal.wav",
        ROOT / "assets" / "audio" / "sfx" / "archive_seal.wav",
        ROOT / "assets" / "audio" / "sfx" / "return_to_sender.wav",
        ROOT / "assets" / "audio" / "sfx" / "send_letter.wav",
        ROOT / "assets" / "audio" / "sfx" / "see_through.wav",
        ROOT / "assets" / "audio" / "sfx" / "lamplight.wav",
        ROOT / "assets" / "audio" / "sfx" / "boss_appear.wav",
        ROOT / "assets" / "audio" / "sfx" / "victory.wav",
        ROOT / "assets" / "audio" / "sfx" / "defeat.wav",
    ]
    checked = 0
    for path in required_paths:
        checked += 1
        if not path.exists():
            reporter.error(f"Missing key WAV asset: {rel(path)}")
            continue
        try:
            channels, sample_rate, data_size = wav_info(path)
        except OSError as exc:
            reporter.error(f"Cannot read key WAV asset: {rel(path)} ({exc})")
            continue
        except ValueError as exc:
            reporter.error(f"Invalid key WAV asset: {rel(path)} ({exc})")
            continue
        reporter.info(
            f"WAV: {rel(path)} channels={channels}, sample_rate={sample_rate}, data_bytes={data_size}"
        )
    return checked


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")

    reporter = Reporter()
    parsed = load_json_files(reporter)
    res_paths_checked = validate_res_paths(reporter)

    maps = load_maps(parsed)
    enemies = load_enemies(parsed)
    interactable_ids = load_interactable_ids(parsed, reporter)
    npc_root = parsed.get(ROOT / "data" / "npcs" / "vertical_slice_npcs.json", {})
    npc_ids = set(collection_by_id(npc_root, "npcs"))
    dialogue_ids = load_dialogue_ids(parsed, interactable_ids)

    validate_maps(reporter, maps, npc_ids, dialogue_ids, interactable_ids)
    validate_map_reference_scales(reporter, maps)
    validate_interactable_reachability(reporter, parsed, maps)
    encounter_count = validate_encounters(reporter, parsed, set(enemies))
    validate_mainline_path(reporter, parsed)
    png_count = validate_png_assets(reporter, parsed)
    wav_count = validate_wav_assets(reporter)

    print("Static validation summary")
    print(f"- JSON files parsed: {len(parsed)}")
    print(f"- res:// references checked: {res_paths_checked}")
    print(f"- maps indexed: {len(maps)}")
    print(f"- NPC ids indexed: {len(npc_ids)}")
    print(f"- merged dialogue ids indexed: {len(dialogue_ids)}")
    print(f"- interactable ids indexed: {len(interactable_ids)}")
    print(f"- enemy ids indexed: {len(enemies)}")
    print(f"- encounters checked: {encounter_count}")
    print(f"- key PNG assets checked: {png_count}")
    print(f"- key WAV assets checked: {wav_count}")

    if reporter.infos:
        print("\nInfo")
        for message in reporter.infos:
            print(f"INFO: {message}")
    if reporter.warnings:
        print("\nWarnings")
        for message in reporter.warnings:
            print(f"WARNING: {message}")
    if reporter.errors:
        print("\nErrors")
        for message in reporter.errors:
            print(f"ERROR: {message}")
        print(f"\nValidation failed with {len(reporter.errors)} error(s).")
        return 1

    print("\nValidation passed with 0 errors.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
