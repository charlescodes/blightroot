#!/usr/bin/env python3
"""Generate an AI-oriented source map for GDScript files under src."""

from __future__ import annotations

import argparse
import difflib
import json
import re
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
SRC_ROOT = ROOT / "src"
JSON_PATH = ROOT / "docs" / "ai" / "src-map.json"
MARKDOWN_PATH = ROOT / "docs" / "ai" / "src-map.md"
SCHEMA_VERSION = 1


CLASS_RE = re.compile(r"^class_name\s+([A-Za-z_][A-Za-z0-9_]*)\s*$")
EXTENDS_RE = re.compile(r"^extends\s+(.+?)\s*$")
DEPENDENCY_RE = re.compile(r"\b(preload|load)\(\s*\"([^\"]+)\"\s*\)")
FUNC_START_RE = re.compile(r"^(static\s+)?func\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(")
NEW_RE = re.compile(r"\b([A-Za-z_][A-Za-z0-9_]*)\.new\s*\(")
SELF_NEW_RE = re.compile(r"(^|[^A-Za-z0-9_])new\s*\(")


FOLDER_ROLES = {
    "src/app": "application composition, input routing, and runtime orchestration",
    "src/camera": "camera state and camera rig behavior",
    "src/debug": "debug overlay UI and formatting",
    "src/interaction": "cursor focus, object picking, and action prompts/menus",
    "src/map": "hex grid math, rendering, map codec, and map file UI",
    "src/modes": "game mode state and mode cycling",
    "src/objects": "world object state, archetypes, visuals, movement, and views",
    "src/paint": "paint brushes, placement preview, and paint mesh helpers",
    "src/pathing": "hex-grid pathfinding",
    "src/ui": "shared UI widgets",
}


def rel(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def res_to_project_path(value: str) -> str | None:
    if value.startswith("res://"):
        return value.removeprefix("res://")
    return None


def role_for(path: str, extends_value: str | None) -> str:
    if path == "src/app/main.gd":
        return "application scene root"
    if extends_value == "RefCounted":
        return "state/service/helper"
    if extends_value == "Node3D":
        return "3D scene node"
    if extends_value == "CanvasLayer":
        return "UI overlay layer"
    if extends_value in {"PanelContainer", "Control", "MarginContainer", "VBoxContainer", "HBoxContainer"}:
        return "UI control"
    if extends_value:
        return "Godot script"
    return "unclassified script"


def visibility_for(name: str) -> str:
    return "private" if name.startswith("_") else "public"


def strip_inline_comment(line: str) -> str:
    in_string: str | None = None
    escaped = False
    for index, char in enumerate(line):
        if escaped:
            escaped = False
            continue
        if char == "\\" and in_string is not None:
            escaped = True
            continue
        if char in {"'", '"'}:
            if in_string == char:
                in_string = None
            elif in_string is None:
                in_string = char
            continue
        if char == "#" and in_string is None:
            return line[:index].rstrip()
    return line.rstrip()


def extract_annotations(stripped: str) -> tuple[list[str], str]:
    annotations: list[str] = []
    rest = stripped
    while rest.startswith("@"):
        match = re.match(r"^(@[A-Za-z_][A-Za-z0-9_]*(?:\([^)]*\))?)\s*(.*)$", rest)
        if not match:
            break
        annotations.append(match.group(1))
        rest = match.group(2).strip()
    return annotations, rest


def split_top_level(text: str, delimiter: str = ",") -> list[str]:
    parts: list[str] = []
    start = 0
    depth = 0
    in_string: str | None = None
    escaped = False
    pairs = {"(": ")", "[": "]", "{": "}"}
    closers = set(pairs.values())
    for index, char in enumerate(text):
        if escaped:
            escaped = False
            continue
        if char == "\\" and in_string is not None:
            escaped = True
            continue
        if char in {"'", '"'}:
            if in_string == char:
                in_string = None
            elif in_string is None:
                in_string = char
            continue
        if in_string is not None:
            continue
        if char in pairs:
            depth += 1
            continue
        if char in closers and depth > 0:
            depth -= 1
            continue
        if char == delimiter and depth == 0:
            parts.append(text[start:index].strip())
            start = index + 1
    tail = text[start:].strip()
    if tail:
        parts.append(tail)
    return parts


def find_assignment(text: str) -> tuple[int, str] | None:
    depth = 0
    in_string: str | None = None
    escaped = False
    pairs = {"(": ")", "[": "]", "{": "}"}
    closers = set(pairs.values())
    index = 0
    while index < len(text):
        char = text[index]
        if escaped:
            escaped = False
            index += 1
            continue
        if char == "\\" and in_string is not None:
            escaped = True
            index += 1
            continue
        if char in {"'", '"'}:
            if in_string == char:
                in_string = None
            elif in_string is None:
                in_string = char
            index += 1
            continue
        if in_string is not None:
            index += 1
            continue
        if char in pairs:
            depth += 1
            index += 1
            continue
        if char in closers and depth > 0:
            depth -= 1
            index += 1
            continue
        if depth == 0 and text.startswith(":=", index):
            return index, ":="
        if depth == 0 and char == "=":
            return index, "="
        index += 1
    return None


def parse_name_type_default(text: str) -> dict[str, Any]:
    assignment = find_assignment(text)
    if assignment is None:
        head = text.strip()
        default_value = None
        assignment_operator = None
    else:
        index, assignment_operator = assignment
        head = text[:index].strip()
        default_value = text[index + len(assignment_operator) :].strip()

    if ":" in head:
        name, type_annotation = head.split(":", 1)
        parsed_type = type_annotation.strip() or None
    else:
        name = head
        parsed_type = None

    return {
        "name": name.strip(),
        "type": parsed_type,
        "default": default_value,
        "assignment_operator": assignment_operator,
    }


def parse_parameters(params_text: str) -> list[dict[str, Any]]:
    if params_text.strip() == "":
        return []

    params: list[dict[str, Any]] = []
    for raw_param in split_top_level(params_text):
        parsed = parse_name_type_default(raw_param)
        parsed["raw"] = raw_param
        params.append(parsed)
    return params


def compact_signature(signature: str) -> str:
    return " ".join(part.strip() for part in signature.splitlines()).strip()


def parse_method_signature(signature: str, start_line: int) -> dict[str, Any]:
    one_line = compact_signature(signature)
    match = re.match(
        r"^(static\s+)?func\s+([A-Za-z_][A-Za-z0-9_]*)\s*\((.*)\)\s*(?:->\s*([^:]+))?:\s*$",
        one_line,
    )
    if not match:
        return {
            "name": "<parse-error>",
            "visibility": "private",
            "static": False,
            "signature": signature,
            "signature_compact": one_line,
            "parameters": [],
            "return_type": None,
            "start_line": start_line,
            "end_line": start_line,
        }

    is_static = bool(match.group(1))
    name = match.group(2)
    params_text = match.group(3)
    return_type = match.group(4).strip() if match.group(4) else None
    return {
        "name": name,
        "visibility": visibility_for(name),
        "static": is_static,
        "signature": signature,
        "signature_compact": one_line,
        "parameters": parse_parameters(params_text),
        "return_type": return_type,
        "start_line": start_line,
        "end_line": start_line,
    }


def collect_signature(lines: list[str], start_index: int) -> tuple[str, int]:
    signature_lines: list[str] = []
    balance = 0
    index = start_index
    while index < len(lines):
        raw_line = lines[index].rstrip("\n")
        stripped = strip_inline_comment(raw_line).strip()
        signature_lines.append(raw_line)
        balance += stripped.count("(") - stripped.count(")")
        if balance <= 0 and stripped.endswith(":"):
            break
        index += 1
    return "\n".join(signature_lines), index


def parse_signal(rest: str, line_number: int) -> dict[str, Any]:
    rest = rest.strip()
    if "(" in rest and rest.endswith(")"):
        name, params_text = rest.split("(", 1)
        params_text = params_text[:-1]
    else:
        name = rest
        params_text = ""
    return {
        "name": name.strip(),
        "visibility": visibility_for(name.strip()),
        "parameters": parse_parameters(params_text),
        "line": line_number,
    }


def parse_script(path: Path) -> dict[str, Any]:
    project_path = rel(path)
    lines = path.read_text(encoding="utf-8").splitlines()
    script: dict[str, Any] = {
        "path": project_path,
        "folder": Path(project_path).parent.as_posix(),
        "file": path.name,
        "line_count": len(lines),
        "class_name": None,
        "extends": None,
        "role": None,
        "dependencies": [],
        "dependency_edges": [],
        "instantiations": [],
        "constants": [],
        "members": [],
        "signals": [],
        "methods": [],
    }

    alias_to_dependency: dict[str, dict[str, Any]] = {}
    index = 0
    while index < len(lines):
        line_number = index + 1
        raw_line = lines[index]
        without_comment = strip_inline_comment(raw_line)
        stripped = without_comment.strip()
        is_top_level = raw_line == raw_line.lstrip(" \t")

        if is_top_level and stripped:
            class_match = CLASS_RE.match(stripped)
            if class_match:
                script["class_name"] = class_match.group(1)

            extends_match = EXTENDS_RE.match(stripped)
            if extends_match:
                script["extends"] = extends_match.group(1).strip()

            func_match = FUNC_START_RE.match(stripped)
            if func_match:
                signature, end_index = collect_signature(lines, index)
                script["methods"].append(parse_method_signature(signature, line_number))
                index = end_index + 1
                continue

            annotations, declaration = extract_annotations(stripped)
            if declaration.startswith("const "):
                parsed = parse_name_type_default(declaration.removeprefix("const ").strip())
                item = {
                    "name": parsed["name"],
                    "visibility": visibility_for(parsed["name"]),
                    "type": parsed["type"],
                    "default": parsed["default"],
                    "assignment_operator": parsed["assignment_operator"],
                    "annotations": annotations,
                    "line": line_number,
                }
                script["constants"].append(item)
            elif declaration.startswith("var "):
                parsed = parse_name_type_default(declaration.removeprefix("var ").strip())
                item = {
                    "name": parsed["name"],
                    "visibility": visibility_for(parsed["name"]),
                    "type": parsed["type"],
                    "default": parsed["default"],
                    "assignment_operator": parsed["assignment_operator"],
                    "annotations": annotations,
                    "exported": "@export" in annotations,
                    "onready": "@onready" in annotations,
                    "line": line_number,
                }
                script["members"].append(item)
            elif declaration.startswith("signal "):
                script["signals"].append(parse_signal(declaration.removeprefix("signal "), line_number))

        for dependency_match in DEPENDENCY_RE.finditer(stripped):
            kind = dependency_match.group(1)
            target = dependency_match.group(2)
            target_path = res_to_project_path(target)
            alias = None
            alias_match = re.match(
                r"^(?:const|var)\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?::[^=]+)?(?::=|=)\s*"
                + re.escape(kind)
                + r"\(",
                stripped,
            )
            if alias_match:
                alias = alias_match.group(1)
            dependency = {
                "kind": kind,
                "alias": alias,
                "target": target,
                "target_path": target_path,
                "line": line_number,
            }
            script["dependencies"].append(dependency)
            if target_path:
                script["dependency_edges"].append(target_path)
            if alias:
                alias_to_dependency[alias] = dependency

        for new_match in NEW_RE.finditer(stripped):
            symbol = new_match.group(1)
            dependency = alias_to_dependency.get(symbol)
            script["instantiations"].append(
                {
                    "symbol": symbol,
                    "line": line_number,
                    "target_path": dependency.get("target_path") if dependency else None,
                    "target_class": None,
                    "resolved": dependency is not None,
                }
            )

        if script["class_name"] and SELF_NEW_RE.search(stripped) and ".new" not in stripped:
            script["instantiations"].append(
                {
                    "symbol": script["class_name"],
                    "line": line_number,
                    "target_path": project_path,
                    "target_class": script["class_name"],
                    "resolved": True,
                }
            )

        index += 1

    method_starts = [method["start_line"] for method in script["methods"]]
    for method_index, method in enumerate(script["methods"]):
        if method_index + 1 < len(method_starts):
            method["end_line"] = method_starts[method_index + 1] - 1
        else:
            method["end_line"] = len(lines)

    script["dependency_edges"] = sorted(set(script["dependency_edges"]))
    script["role"] = role_for(project_path, script["extends"])
    return script


def enrich_instantiations(scripts: list[dict[str, Any]]) -> None:
    class_by_path = {script["path"]: script["class_name"] for script in scripts if script["class_name"]}
    path_by_class = {script["class_name"]: script["path"] for script in scripts if script["class_name"]}
    for script in scripts:
        for instantiation in script["instantiations"]:
            target_path = instantiation.get("target_path")
            symbol = instantiation["symbol"]
            if target_path and target_path in class_by_path:
                instantiation["target_class"] = class_by_path[target_path]
                instantiation["resolved"] = True
            elif symbol in path_by_class:
                instantiation["target_path"] = path_by_class[symbol]
                instantiation["target_class"] = symbol
                instantiation["resolved"] = True


def build_folder_index(scripts: list[dict[str, Any]]) -> list[dict[str, Any]]:
    script_paths_by_folder: dict[str, list[str]] = {}
    for script in scripts:
        script_paths_by_folder.setdefault(script["folder"], []).append(script["path"])

    folders: list[dict[str, Any]] = []
    for directory in sorted(path for path in SRC_ROOT.rglob("*") if path.is_dir()):
        folder_path = rel(directory)
        folder_scripts = sorted(script_paths_by_folder.get(folder_path, []))
        folders.append(
            {
                "path": folder_path,
                "role": FOLDER_ROLES.get(folder_path, ""),
                "script_count": len(folder_scripts),
                "scripts": folder_scripts,
            }
        )

    root_scripts = sorted(script_paths_by_folder.get("src", []))
    folders.insert(
        0,
        {
            "path": "src",
            "role": "source root",
            "script_count": len(root_scripts),
            "scripts": root_scripts,
        },
    )
    return folders


def build_inventory() -> dict[str, Any]:
    if not SRC_ROOT.exists():
        raise SystemExit(f"Missing source directory: {SRC_ROOT}")

    scripts = [parse_script(path) for path in sorted(SRC_ROOT.rglob("*.gd")) if path.is_file()]
    enrich_instantiations(scripts)

    class_index = [
        {
            "class_name": script["class_name"],
            "path": script["path"],
            "extends": script["extends"],
            "role": script["role"],
        }
        for script in scripts
        if script["class_name"]
    ]
    class_index.sort(key=lambda item: item["class_name"])

    dependency_edges: list[dict[str, Any]] = []
    for script in scripts:
        for dependency in script["dependencies"]:
            if dependency.get("target_path"):
                dependency_edges.append(
                    {
                        "from": script["path"],
                        "to": dependency["target_path"],
                        "kind": dependency["kind"],
                        "alias": dependency["alias"],
                        "line": dependency["line"],
                    }
                )

    return {
        "schema_version": SCHEMA_VERSION,
        "generated_by": "scripts/generate-src-map.py",
        "source_root": "src",
        "counts": {
            "folders": len([path for path in SRC_ROOT.rglob("*") if path.is_dir()]) + 1,
            "scripts": len(scripts),
            "classes": len(class_index),
            "dependency_edges": len(dependency_edges),
        },
        "folders": build_folder_index(scripts),
        "class_index": class_index,
        "dependency_edges": sorted(dependency_edges, key=lambda item: (item["from"], item["to"], item["line"])),
        "scripts": scripts,
    }


def declaration_label(item: dict[str, Any]) -> str:
    details: list[str] = []
    if item.get("type"):
        details.append(f": {item['type']}")
    if item.get("default") is not None:
        details.append(f" = {item['default']}")
    annotation = " ".join(item.get("annotations", []))
    prefix = f"{annotation} " if annotation else ""
    return f"{prefix}{item['name']}{''.join(details)}"


def parameter_label(parameter: dict[str, Any]) -> str:
    label = parameter["name"]
    if parameter.get("type"):
        label += f": {parameter['type']}"
    if parameter.get("default") is not None:
        label += f" = {parameter['default']}"
    return label


def markdown_table_row(values: list[str]) -> str:
    escaped = [value.replace("|", "\\|").replace("\n", "<br>") if value else "" for value in values]
    return "| " + " | ".join(escaped) + " |"


def render_markdown(data: dict[str, Any]) -> str:
    lines: list[str] = []
    counts = data["counts"]
    lines.extend(
        [
            "# AI Source Map For `src`",
            "",
            "> Generated from source by `scripts/generate-src-map.py`. Do not edit by hand.",
            "",
            "## Summary",
            "",
            f"- Scripts: {counts['scripts']}",
            f"- Classes: {counts['classes']}",
            f"- Folders: {counts['folders']}",
            f"- Dependency edges: {counts['dependency_edges']}",
            "",
            "## Folder Map",
            "",
            markdown_table_row(["Folder", "Role", "Scripts"]),
            markdown_table_row(["---", "---", "---"]),
        ]
    )

    for folder in data["folders"]:
        script_names = ", ".join(f"`{Path(path).name}`" for path in folder["scripts"])
        lines.append(markdown_table_row([f"`{folder['path']}`", folder.get("role", ""), script_names]))

    lines.extend(
        [
            "",
            "## Class And Base Index",
            "",
            markdown_table_row(["Class", "Extends", "Role", "Script"]),
            markdown_table_row(["---", "---", "---", "---"]),
        ]
    )
    for item in data["class_index"]:
        lines.append(
            markdown_table_row(
                [
                    f"`{item['class_name']}`",
                    f"`{item['extends']}`" if item.get("extends") else "",
                    item["role"],
                    f"`{item['path']}`",
                ]
            )
        )

    incoming_counts: dict[str, int] = {}
    for edge in data["dependency_edges"]:
        incoming_counts[edge["to"]] = incoming_counts.get(edge["to"], 0) + 1
    hot_targets = sorted(incoming_counts.items(), key=lambda item: (-item[1], item[0]))

    lines.extend(["", "## Dependency Overview", ""])
    if hot_targets:
        lines.append("Most referenced source scripts:")
        for target, count in hot_targets[:10]:
            lines.append(f"- `{target}` referenced by {count} script(s)")
        lines.append("")

    lines.append("Per-script source dependencies:")
    for script in data["scripts"]:
        deps = [dep for dep in script["dependencies"] if dep.get("target_path")]
        if not deps:
            continue
        rendered_deps = ", ".join(
            f"`{dep['alias'] or dep['kind']}` -> `{dep['target_path']}`" for dep in deps
        )
        lines.append(f"- `{script['path']}`: {rendered_deps}")

    lines.extend(["", "## Subsystem Notes", ""])
    for folder in data["folders"]:
        if folder["path"] == "src" or not folder.get("role"):
            continue
        lines.append(f"- `{folder['path']}`: {folder['role']}.")

    lines.extend(["", "## Per-Script Inventory", ""])
    for script in data["scripts"]:
        identity = script["class_name"] or Path(script["path"]).stem
        lines.extend(
            [
                f"### `{script['path']}`",
                "",
                f"- Identity: `{identity}`",
                f"- Extends: `{script['extends'] or ''}`",
                f"- Role: {script['role']}",
                f"- Lines: {script['line_count']}",
            ]
        )

        if script["dependencies"]:
            lines.append("- Dependencies:")
            for dep in script["dependencies"]:
                alias = f"`{dep['alias']}` " if dep.get("alias") else ""
                target = dep.get("target_path") or dep["target"]
                lines.append(f"  - line {dep['line']}: {alias}{dep['kind']} -> `{target}`")

        if script["instantiations"]:
            lines.append("- Instantiations:")
            for instantiation in script["instantiations"]:
                target = instantiation.get("target_class") or instantiation.get("target_path") or "unresolved/builtin"
                lines.append(f"  - line {instantiation['line']}: `{instantiation['symbol']}.new()` -> `{target}`")

        if script["signals"]:
            lines.append("- Signals:")
            for signal in script["signals"]:
                params = ", ".join(parameter_label(param) for param in signal["parameters"])
                lines.append(f"  - line {signal['line']}: `{signal['name']}({params})`")

        if script["constants"]:
            lines.append("- Constants:")
            for const in script["constants"]:
                lines.append(f"  - line {const['line']}: `{declaration_label(const)}`")

        if script["members"]:
            lines.append("- Members:")
            for member in script["members"]:
                lines.append(
                    f"  - line {member['line']}: `{declaration_label(member)}` ({member['visibility']})"
                )

        if script["methods"]:
            lines.append("- Methods:")
            for method in script["methods"]:
                flags: list[str] = []
                flags.append("static" if method["static"] else "instance")
                flags.append(method["visibility"])
                lines.append(
                    f"  - lines {method['start_line']}-{method['end_line']}: "
                    f"`{method['signature_compact']}` ({', '.join(flags)})"
                )

        lines.append("")

    return "\n".join(lines).rstrip() + "\n"


def render_outputs() -> tuple[str, str]:
    data = build_inventory()
    json_text = json.dumps(data, indent=2, ensure_ascii=False) + "\n"
    markdown_text = render_markdown(data)
    return json_text, markdown_text


def check_file(path: Path, expected: str) -> bool:
    if not path.exists():
        print(f"Missing generated file: {rel(path)}", file=sys.stderr)
        return False

    actual = path.read_text(encoding="utf-8")
    if actual == expected:
        return True

    print(f"Generated file is stale: {rel(path)}", file=sys.stderr)
    diff = difflib.unified_diff(
        actual.splitlines(),
        expected.splitlines(),
        fromfile=f"{rel(path)} (current)",
        tofile=f"{rel(path)} (expected)",
        lineterm="",
    )
    for index, line in enumerate(diff):
        if index >= 120:
            print("... diff truncated ...", file=sys.stderr)
            break
        print(line, file=sys.stderr)
    return False


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="fail if generated docs are missing or stale")
    args = parser.parse_args()

    json_text, markdown_text = render_outputs()

    if args.check:
        ok = check_file(JSON_PATH, json_text)
        ok = check_file(MARKDOWN_PATH, markdown_text) and ok
        return 0 if ok else 1

    JSON_PATH.parent.mkdir(parents=True, exist_ok=True)
    JSON_PATH.write_text(json_text, encoding="utf-8")
    MARKDOWN_PATH.write_text(markdown_text, encoding="utf-8")
    print(f"Wrote {rel(JSON_PATH)}")
    print(f"Wrote {rel(MARKDOWN_PATH)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
