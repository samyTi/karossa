#!/usr/bin/env python3
"""
flutter_architecture.py
-----------------------
Répertorie l'architecture de fichiers et de dossiers d'une application Flutter.

Usage :
    python flutter_architecture.py [chemin_du_projet] [options]

Options :
    --output, -o    Fichier de sortie (ex: architecture.txt)
    --format, -f    Format de sortie : tree | json | markdown  (défaut: tree)
    --depth, -d     Profondeur maximale d'exploration (défaut: illimitée)
    --no-ignore     Inclure les dossiers normalement ignorés (.dart_tool, build, .git…)
    --help, -h      Afficher ce message
"""

import os
import sys
import json
import argparse
from pathlib import Path
from datetime import datetime

# Dossiers/fichiers ignorés par défaut (générés automatiquement, peu utiles à auditer)
DEFAULT_IGNORE = {
    ".git", ".dart_tool", ".idea", ".vscode",
    "build", ".flutter-plugins", ".flutter-plugins-dependencies",
    "__pycache__", ".DS_Store", "*.g.dart",
}

# Extensions Flutter/Dart intéressantes
FLUTTER_EXTENSIONS = {
    ".dart", ".yaml", ".yml", ".json", ".xml",
    ".gradle", ".properties", ".plist", ".entitlements",
    ".swift", ".kt", ".java", ".m", ".h",
    ".png", ".jpg", ".jpeg", ".svg", ".webp",
    ".ttf", ".otf", ".md", ".txt",
}


def should_ignore(name: str, no_ignore: bool) -> bool:
    if no_ignore:
        return False
    return name in DEFAULT_IGNORE or name.startswith(".")


def get_file_info(path: Path) -> dict:
    stat = path.stat()
    return {
        "name": path.name,
        "type": "file",
        "extension": path.suffix.lower(),
        "size_bytes": stat.st_size,
        "size_human": human_size(stat.st_size),
    }


def human_size(n: int) -> str:
    for unit in ("o", "Ko", "Mo", "Go"):
        if n < 1024:
            return f"{n:.0f} {unit}"
        n /= 1024
    return f"{n:.1f} To"


def build_tree(root: Path, no_ignore: bool, max_depth: int, _depth: int = 0) -> dict:
    node = {
        "name": root.name,
        "type": "directory",
        "path": str(root),
        "children": [],
    }

    if max_depth is not None and _depth >= max_depth:
        return node

    try:
        entries = sorted(root.iterdir(), key=lambda p: (p.is_file(), p.name.lower()))
    except PermissionError:
        return node

    for entry in entries:
        if should_ignore(entry.name, no_ignore):
            continue
        if entry.is_dir():
            node["children"].append(build_tree(entry, no_ignore, max_depth, _depth + 1))
        elif entry.is_file():
            node["children"].append(get_file_info(entry))

    return node


# ──────────────────────────── FORMATTERS ────────────────────────────

def format_tree(node: dict, prefix: str = "", is_last: bool = True) -> list[str]:
    connector = "└── " if is_last else "├── "
    lines = []

    if node["type"] == "directory":
        icon = "📁"
    elif node["extension"] in (".dart",):
        icon = "🎯"
    elif node["extension"] in (".yaml", ".yml"):
        icon = "⚙️ "
    elif node["extension"] in (".png", ".jpg", ".jpeg", ".svg", ".webp"):
        icon = "🖼️ "
    else:
        icon = "📄"

    size_info = f"  ({node['size_human']})" if node["type"] == "file" else ""
    lines.append(f"{prefix}{connector}{icon} {node['name']}{size_info}")

    if node["type"] == "directory":
        children = node.get("children", [])
        child_prefix = prefix + ("    " if is_last else "│   ")
        for i, child in enumerate(children):
            lines.extend(format_tree(child, child_prefix, i == len(children) - 1))

    return lines


def format_markdown(node: dict, depth: int = 0) -> list[str]:
    lines = []
    indent = "  " * depth

    if node["type"] == "directory":
        lines.append(f"{indent}- **📁 {node['name']}/**")
        for child in node.get("children", []):
            lines.extend(format_markdown(child, depth + 1))
    else:
        size = node["size_human"]
        lines.append(f"{indent}- `{node['name']}` _{size}_")

    return lines


def format_json(node: dict) -> str:
    return json.dumps(node, ensure_ascii=False, indent=2)


# ──────────────────────────── STATS ────────────────────────────

def compute_stats(node: dict) -> dict:
    stats = {
        "total_files": 0,
        "total_dirs": 0,
        "total_size_bytes": 0,
        "by_extension": {},
        "dart_files": 0,
    }

    def walk(n):
        if n["type"] == "file":
            stats["total_files"] += 1
            stats["total_size_bytes"] += n["size_bytes"]
            ext = n["extension"] or "(sans extension)"
            stats["by_extension"][ext] = stats["by_extension"].get(ext, 0) + 1
            if ext == ".dart":
                stats["dart_files"] += 1
        else:
            stats["total_dirs"] += 1
            for c in n.get("children", []):
                walk(c)

    walk(node)
    stats["total_size_human"] = human_size(stats["total_size_bytes"])
    return stats


def format_stats(stats: dict) -> list[str]:
    lines = [
        "",
        "══════════════════════════════════════",
        "  STATISTIQUES",
        "══════════════════════════════════════",
        f"  Dossiers     : {stats['total_dirs']}",
        f"  Fichiers     : {stats['total_files']}",
        f"  Fichiers Dart: {stats['dart_files']}",
        f"  Taille totale: {stats['total_size_human']}",
        "",
        "  Par extension :",
    ]
    for ext, count in sorted(stats["by_extension"].items(), key=lambda x: -x[1]):
        lines.append(f"    {ext:<20} {count:>4} fichier(s)")
    lines.append("══════════════════════════════════════")
    return lines


# ──────────────────────────── MAIN ────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Répertorie l'architecture d'un projet Flutter.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "path",
        nargs="?",
        default=".",
        help="Chemin racine du projet Flutter (défaut: répertoire courant)",
    )
    parser.add_argument("--output", "-o", help="Fichier de sortie")
    parser.add_argument(
        "--format", "-f",
        choices=["tree", "json", "markdown"],
        default="tree",
        help="Format de sortie (défaut: tree)",
    )
    parser.add_argument(
        "--depth", "-d",
        type=int,
        default=None,
        help="Profondeur maximale d'exploration",
    )
    parser.add_argument(
        "--no-ignore",
        action="store_true",
        help="Inclure les dossiers ignorés par défaut",
    )

    args = parser.parse_args()
    root = Path(args.path).resolve()

    if not root.exists():
        print(f"❌  Chemin introuvable : {root}", file=sys.stderr)
        sys.exit(1)

    if not root.is_dir():
        print(f"❌  Ce n'est pas un dossier : {root}", file=sys.stderr)
        sys.exit(1)

    # Vérification basique que c'est un projet Flutter
    pubspec = root / "pubspec.yaml"
    if not pubspec.exists():
        print(
            "⚠️  Aucun fichier pubspec.yaml trouvé. "
            "Ce dossier ne semble pas être un projet Flutter.",
            file=sys.stderr,
        )

    # Construction de l'arbre
    tree = build_tree(root, args.no_ignore, args.depth)
    stats = compute_stats(tree)

    # Formatage
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    header = [
        f"Architecture Flutter — {root.name}",
        f"Généré le : {timestamp}",
        f"Chemin    : {root}",
        "",
    ]

    if args.format == "json":
        output_lines = [format_json({"meta": {"project": root.name, "generated": timestamp}, "tree": tree})]
    elif args.format == "markdown":
        output_lines = (
            [f"# Architecture Flutter : `{root.name}`", "", f"> Généré le {timestamp}", ""]
            + format_markdown(tree)
            + [""]
            + [f"**{k}** : {v}" for k, v in [
                ("Dossiers", stats["total_dirs"]),
                ("Fichiers", stats["total_files"]),
                ("Fichiers Dart", stats["dart_files"]),
                ("Taille totale", stats["total_size_human"]),
            ]]
        )
    else:  # tree
        tree_lines = format_tree(tree, is_last=True)
        # Remplacer la première ligne (racine) pour être plus lisible
        tree_lines[0] = f"📦 {root.name}/"
        output_lines = header + tree_lines + format_stats(stats)

    output_text = "\n".join(output_lines)

    # Sortie
    if args.output:
        out_path = Path(args.output)
        out_path.write_text(output_text, encoding="utf-8")
        print(f"✅  Architecture sauvegardée dans : {out_path.resolve()}")
    else:
        print(output_text)


if __name__ == "__main__":
    main()
