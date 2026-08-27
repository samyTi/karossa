#!/usr/bin/env python3
"""
migrate_i18n.py — Migration automatique Flutter i18n
=====================================================
Remplace les chaînes françaises codées en dur dans les fichiers Dart
par des appels à AppLocalizations (context.l10n.clé).

Usage :
    python migrate_i18n.py [--lib lib/] [--arb app_fr.arb] [--dry-run] [--file chemin/fichier.dart]

Options :
    --lib     Dossier racine Flutter (défaut: lib/)
    --arb     Fichier ARB de référence (défaut: lib/l10n/app_fr.arb)
    --dry-run Affiche les remplacements sans modifier les fichiers
    --file    Migre un seul fichier (pour tester)
    --report  Génère un rapport CSV des remplacements effectués

Fonctionnement :
    1. Charge le fichier ARB (valeur → clé)
    2. Pour chaque fichier .dart :
       a. Cherche les patterns Text('...'), label: '...', etc.
       b. Si la valeur est dans l'ARB, remplace par l10n.clé
       c. Ajoute l'import si nécessaire
       d. Retire `const` si le widget devient non-const
"""

import re
import os
import sys
import json
import shutil
import argparse
import csv
from pathlib import Path
from datetime import datetime

# ─── Configuration ────────────────────────────────────────────────────────────

# Import à injecter dans chaque fichier modifié
L10N_IMPORT = "import 'package:garage_auto/generated/l10n/app_localizations.dart';"

# Extension helper (évite de répéter AppLocalizations.of(context)!)
# Doit exister dans votre projet : extension BuildContextL10n on BuildContext
L10N_CALL = "context.l10n"

# Fichiers/dossiers à ignorer
IGNORE_DIRS  = {'.dart_tool', '.git', 'build', 'generated', 'gen_l10n', '.DS_Store'}
IGNORE_FILES = {'app_localizations.dart', 'app_localizations_fr.dart',
                'app_localizations_ar.dart', 'app_localizations_en.dart'}

# Fichiers domaine à NE PAS migrer (les enum .label seront gérés séparément)
IGNORE_DOMAIN_LABELS = True   # met False pour migrer aussi les domain models

# ─── Patterns de remplacement ─────────────────────────────────────────────────

# Chaque règle : (pattern_regex, builder_fn)
# builder_fn(match, l10n_key) → nouvelle chaîne

def _q(s):
    """Retourne le quoting utilisé (' ou ")."""
    return s[0] if s else "'"

# 1. Text('Chaîne fixe')  ou  Text('Chaîne', ...)
PAT_TEXT_WIDGET = re.compile(
    r"""(const\s+)?Text\(\s*(['"])([^'"$\\\n]{2,120})\2\s*([,\)])\s*""",
    re.MULTILINE
)

# 2. label: 'Chaîne'  / title: 'Chaîne'  / hint: ... / tooltip: ... etc.
PAT_NAMED_ARG = re.compile(
    r"""((?:label|title|hintText|labelText|tooltip|message|helperText|errorText|placeholder|subtitle|semanticsLabel)\s*:\s*)(const\s+)?(['"])([^'"$\\\n]{2,120})\3""",
    re.MULTILINE
)

# 3. Tab(text: 'Chaîne')
PAT_TAB_TEXT = re.compile(
    r"""(Tab\(\s*text:\s*)(const\s+)?(['"])([^'"$\\\n]{2,80})\3\s*\)""",
    re.MULTILINE
)

# 4. hint: const Text('Chaîne')
PAT_HINT_TEXT = re.compile(
    r"""((?:hint|icon|prefix|suffix|leading|trailing)\s*:\s*)(const\s+)?Text\(\s*(['"])([^'"$\\\n]{2,80})\3\s*\)""",
    re.MULTILINE
)

# 5. NavigationDestination(label: 'Chaîne')
PAT_NAV_DEST = re.compile(
    r"""(NavigationDestination\([^)]*?label:\s*)(const\s+)?(['"])([^'"$\\\n]{2,60})\3""",
    re.MULTILINE | re.DOTALL
)

# 6. FloatingActionButton.extended(label: const Text('Chaîne'))
PAT_FAB_LABEL = re.compile(
    r"""(FloatingActionButton[\w.]*\([^)]*?label:\s*)(const\s+)?Text\(\s*(['"])([^'"$\\\n]{2,60})\3\s*\)""",
    re.MULTILINE | re.DOTALL
)

# 7. ElevatedButton / TextButton / OutlinedButton child: const Text('...')
PAT_BTN_CHILD = re.compile(
    r"""((?:ElevatedButton|TextButton|OutlinedButton|FilledButton)[\w.]*\([^)]*?child:\s*)(const\s+)?Text\(\s*(['"])([^'"$\\\n]{2,60})\3\s*\)""",
    re.MULTILINE | re.DOTALL
)

# 8. DropdownMenuItem(value: ..., child: const Text('Chaîne'))
PAT_DROPDOWN = re.compile(
    r"""(DropdownMenuItem[^)]*?child:\s*)(const\s+)?Text\(\s*(['"])([^'"$\\\n]{2,60})\3\s*\)""",
    re.MULTILINE | re.DOTALL
)

# 9. validator: (v) => v == null ? 'Requis' : null
#    validator: (v) { if (...) return 'Message'; }
PAT_VALIDATOR_TERNARY = re.compile(
    r"""(\?\s*)(['"])([^'"$\\\n]{2,80})\2(\s*:\s*null)""",
    re.MULTILINE
)
PAT_VALIDATOR_RETURN = re.compile(
    r"""(return\s+)(['"])([^'"$\\\n]{3,100})\2(\s*;)""",
    re.MULTILINE
)

# 10. NotificationService().success('Chaîne') / .error / .warning / .info
PAT_NOTIFICATION = re.compile(
    r"""(NotificationService\(\)\.\w+\(\s*)(['"])([^'"$\\\n]{3,120})\2(\s*\))""",
    re.MULTILINE
)

# 11. throw Exception('Chaîne')
PAT_EXCEPTION = re.compile(
    r"""(throw\s+Exception\(\s*)(['"])([^'"$\\\n]{5,120})\2(\s*\))""",
    re.MULTILINE
)

# 12. AppBar(title: const Text('Chaîne'))  — déjà couvert par PAT_HINT_TEXT + PAT_TEXT_WIDGET
#     mais on ajoute le cas title: Text(variable) — skip (variable)

# ─── Helpers ──────────────────────────────────────────────────────────────────

def normalize(s: str) -> str:
    """Normalise une chaîne pour la comparer à l'ARB (strip + unescape)."""
    return s.strip().replace("\\'", "'").replace('\\"', '"')


def build_lookup(arb: dict) -> dict[str, str]:
    """
    Construit val → clé depuis l'ARB.
    On garde uniquement les clés sans @.
    """
    lookup = {}
    for k, v in arb.items():
        if k.startswith('@'):
            continue
        if isinstance(v, str):
            lookup[v] = k
    return lookup


def l10n_expr(key: str) -> str:
    return f"{L10N_CALL}.{key}"


def needs_import(content: str) -> bool:
    return L10N_IMPORT not in content and 'AppLocalizations' not in content


def add_import(content: str, filepath: str) -> str:
    """Injecte l'import l10n après les autres imports flutter/package."""
    # Cherche la dernière ligne import
    lines = content.split('\n')
    last_import = -1
    for i, line in enumerate(lines):
        if line.strip().startswith('import '):
            last_import = i
    if last_import == -1:
        # Pas d'import trouvé, ajouter en tête
        return L10N_IMPORT + '\n' + content
    lines.insert(last_import + 1, L10N_IMPORT)
    return '\n'.join(lines)


def is_const_safe(new_expr: str) -> bool:
    """Un widget contenant l10n.xxx ne peut plus être const."""
    return False  # jamais const avec l10n


# ─── Moteur de remplacement ───────────────────────────────────────────────────

class Replacer:
    def __init__(self, lookup: dict[str, str], dry_run: bool = False):
        self.lookup   = lookup
        self.dry_run  = dry_run
        self.report   = []  # liste de (file, line, original, replacement, key)

    def _find_key(self, raw: str) -> str | None:
        norm = normalize(raw)
        return self.lookup.get(norm)

    def _log(self, filepath, line_hint, original, replacement, key):
        self.report.append({
            'file':        filepath,
            'line':        line_hint,
            'original':    original.strip(),
            'replacement': replacement.strip(),
            'key':         key,
        })

    # ── Applique tous les patterns sur un contenu ──────────────────────────

    def apply(self, content: str, filepath: str) -> tuple[str, int]:
        """Retourne (nouveau_contenu, nb_remplacements)."""
        result    = content
        nb_total  = 0

        # --- 1. Text('Chaîne fixe') ---
        def repl_text(m):
            const_kw, quote, val, closing = m.group(1), m.group(2), m.group(3), m.group(4)
            key = self._find_key(val)
            if not key:
                return m.group(0)
            expr     = l10n_expr(key)
            new_str  = f"Text({expr}{closing} "
            self._log(filepath, '?', m.group(0), new_str, key)
            return new_str  # const retiré automatiquement

        new, n = PAT_TEXT_WIDGET.subn(repl_text, result)
        result, nb_total = new, nb_total + n

        # --- 2. label: 'Chaîne' etc. ---
        def repl_named(m):
            prefix, const_kw, quote, val = m.group(1), m.group(2), m.group(3), m.group(4)
            key = self._find_key(val)
            if not key:
                return m.group(0)
            expr    = l10n_expr(key)
            new_str = f"{prefix}{expr}"
            self._log(filepath, '?', m.group(0), new_str, key)
            return new_str

        new, n = PAT_NAMED_ARG.subn(repl_named, result)
        result, nb_total = new, nb_total + n

        # --- 3. Tab(text: 'Chaîne') ---
        def repl_tab(m):
            prefix, const_kw, quote, val = m.group(1), m.group(2), m.group(3), m.group(4)
            key = self._find_key(val)
            if not key:
                return m.group(0)
            expr    = l10n_expr(key)
            new_str = f"{prefix}{expr})"
            self._log(filepath, '?', m.group(0), new_str, key)
            return new_str

        new, n = PAT_TAB_TEXT.subn(repl_tab, result)
        result, nb_total = new, nb_total + n

        # --- 4. hint/icon: const Text('Chaîne') ---
        def repl_hint(m):
            prefix, const_kw, quote, val = m.group(1), m.group(2), m.group(3), m.group(4)
            key = self._find_key(val)
            if not key:
                return m.group(0)
            expr    = l10n_expr(key)
            new_str = f"{prefix}Text({expr})"
            self._log(filepath, '?', m.group(0), new_str, key)
            return new_str

        new, n = PAT_HINT_TEXT.subn(repl_hint, result)
        result, nb_total = new, nb_total + n

        # --- 5. NavigationDestination label ---
        def repl_navdest(m):
            prefix, const_kw, quote, val = m.group(1), m.group(2), m.group(3), m.group(4)
            key = self._find_key(val)
            if not key:
                return m.group(0)
            expr    = l10n_expr(key)
            new_str = f"{prefix}{expr}"
            self._log(filepath, '?', m.group(0), new_str, key)
            return new_str

        new, n = PAT_NAV_DEST.subn(repl_navdest, result)
        result, nb_total = new, nb_total + n

        # --- 6. FAB label ---
        def repl_fab(m):
            prefix, const_kw, quote, val = m.group(1), m.group(2), m.group(3), m.group(4)
            key = self._find_key(val)
            if not key:
                return m.group(0)
            expr    = l10n_expr(key)
            new_str = f"{prefix}Text({expr})"
            self._log(filepath, '?', m.group(0), new_str, key)
            return new_str

        new, n = PAT_FAB_LABEL.subn(repl_fab, result)
        result, nb_total = new, nb_total + n

        # --- 7. Button child ---
        def repl_btn(m):
            prefix, const_kw, quote, val = m.group(1), m.group(2), m.group(3), m.group(4)
            key = self._find_key(val)
            if not key:
                return m.group(0)
            expr    = l10n_expr(key)
            new_str = f"{prefix}Text({expr})"
            self._log(filepath, '?', m.group(0), new_str, key)
            return new_str

        new, n = PAT_BTN_CHILD.subn(repl_btn, result)
        result, nb_total = new, nb_total + n

        # --- 8. DropdownMenuItem child ---
        new, n = PAT_DROPDOWN.subn(repl_btn, result)   # même logique
        result, nb_total = new, nb_total + n

        # --- 9a. Validator ternaire: ? 'Message' : null ---
        def repl_val_tern(m):
            q_mark, quote, val, rest = m.group(1), m.group(2), m.group(3), m.group(4)
            key = self._find_key(val)
            if not key:
                return m.group(0)
            expr    = l10n_expr(key)
            new_str = f"{q_mark}{expr}{rest}"
            self._log(filepath, '?', m.group(0), new_str, key)
            return new_str

        new, n = PAT_VALIDATOR_TERNARY.subn(repl_val_tern, result)
        result, nb_total = new, nb_total + n

        # --- 9b. return 'Message'; ---
        def repl_val_return(m):
            ret, quote, val, semi = m.group(1), m.group(2), m.group(3), m.group(4)
            key = self._find_key(val)
            if not key:
                return m.group(0)
            expr    = l10n_expr(key)
            new_str = f"{ret}{expr}{semi}"
            self._log(filepath, '?', m.group(0), new_str, key)
            return new_str

        new, n = PAT_VALIDATOR_RETURN.subn(repl_val_return, result)
        result, nb_total = new, nb_total + n

        # --- 10. NotificationService().success/error('Message') ---
        def repl_notif(m):
            prefix, quote, val, suffix = m.group(1), m.group(2), m.group(3), m.group(4)
            key = self._find_key(val)
            if not key:
                return m.group(0)
            # NotificationService n'a pas de context — on utilise une solution globale
            # Pattern recommandé: stocker le context dans un provider ou passer en param
            # Ici on produit un TODO commenté pour review manuelle
            expr    = l10n_expr(key)
            new_str = f"{prefix}{expr}{suffix}  // TODO: l10n — vérifier accès context"
            self._log(filepath, '?', m.group(0), new_str, key)
            return new_str

        new, n = PAT_NOTIFICATION.subn(repl_notif, result)
        result, nb_total = new, nb_total + n

        # --- 11. throw Exception('Message') ---
        def repl_exc(m):
            prefix, quote, val, suffix = m.group(1), m.group(2), m.group(3), m.group(4)
            key = self._find_key(val)
            if not key:
                return m.group(0)
            # Les exceptions sont dans les repositories (pas de context)
            # On laisse en français avec un commentaire
            new_str = m.group(0) + f"  // l10n_key: {key}"
            self._log(filepath, '?', m.group(0), new_str, key)
            return new_str

        new, n = PAT_EXCEPTION.subn(repl_exc, result)
        result, nb_total = new, nb_total + n

        return result, nb_total


# ─── Nettoyage post-remplacement ──────────────────────────────────────────────

def fix_const_cascade(content: str) -> str:
    """
    Retire les `const` orphelins : un widget avec l10n.xxx ne peut être const.
    Stratégie : retire `const` devant tout widget contenant `context.l10n`.
    """
    # Retire `const Text(context.l10n...)`  →  `Text(context.l10n...)`
    content = re.sub(r'\bconst\s+(Text\(context\.l10n)', r'\1', content)
    # Retire `const [` lorsque les enfants contiennent l10n
    # (heuristique conservatrice — laisse les vrais const intacts)
    content = re.sub(r'\bconst\s+(\[[\s\S]{0,200}?context\.l10n)', r'\1', content)
    return content


def fix_double_l10n(content: str) -> str:
    """Corrige les doubles remplacements (artefacts de passes multiples)."""
    # context.l10n.context.l10n.xxx → context.l10n.xxx
    content = re.sub(r'context\.l10n\.context\.l10n\.', 'context.l10n.', content)
    return content


def fix_spacing(content: str) -> str:
    """Corrige les espaces parasites introduits par les remplacements."""
    # Text(context.l10n.key) ,  →  Text(context.l10n.key),
    content = re.sub(r'(context\.l10n\.\w+\))\s+([,;)])', r'\1\2', content)
    # label: context.l10n.key ,  →  label: context.l10n.key,
    content = re.sub(r'(context\.l10n\.\w+)\s+([,;)])', r'\1\2', content)
    return content


# ─── Traitement fichier par fichier ───────────────────────────────────────────

def should_skip_file(path: Path) -> bool:
    parts = set(path.parts)
    if parts & IGNORE_DIRS:
        return True
    if path.name in IGNORE_FILES:
        return True
    if IGNORE_DOMAIN_LABELS and '/domain/' in str(path):
        # On ne touche pas aux enum .label dans les models
        return True
    return False


def process_file(path: Path, replacer: Replacer, backup: bool = True) -> dict:
    content = path.read_text(encoding='utf-8')
    original = content

    new_content, nb = replacer.apply(content, str(path))

    if nb == 0:
        return {'file': str(path), 'changes': 0, 'status': 'skipped'}

    # Post-processing
    new_content = fix_const_cascade(new_content)
    new_content = fix_double_l10n(new_content)
    new_content = fix_spacing(new_content)

    # Ajouter import si nécessaire
    if needs_import(new_content):
        new_content = add_import(new_content, str(path))

    if replacer.dry_run:
        print(f"\n{'='*60}")
        print(f"📄 {path}  ({nb} remplacement(s))")
        print('='*60)
        orig_lines = original.split('\n')
        new_lines  = new_content.split('\n')
        for i, (ol, nl) in enumerate(zip(orig_lines, new_lines)):
            if ol != nl:
                print(f"  L{i+1} - {ol.strip()}")
                print(f"  L{i+1} + {nl.strip()}")
        return {'file': str(path), 'changes': nb, 'status': 'dry-run'}

    # Backup
    if backup:
        bak = path.with_suffix('.dart.bak')
        shutil.copy2(path, bak)

    path.write_text(new_content, encoding='utf-8')
    return {'file': str(path), 'changes': nb, 'status': 'done'}


# ─── Génération du fichier l10n_extension.dart ───────────────────────────────

EXTENSION_CONTENT = """\
// lib/core/extensions/l10n_extension.dart
// Extension helper pour accéder facilement aux traductions
// Usage : context.l10n.monLabel

import 'package:flutter/material.dart';
import 'package:garage_auto/generated/l10n/app_localizations.dart';

export 'package:flutter_gen/gen_l10n/app_localizations.dart';

extension BuildContextL10n on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}
"""

def generate_extension(lib_dir: Path):
    ext_path = lib_dir / 'core' / 'extensions' / 'l10n_extension.dart'
    ext_path.parent.mkdir(parents=True, exist_ok=True)
    if not ext_path.exists():
        ext_path.write_text(EXTENSION_CONTENT, encoding='utf-8')
        print(f"✅ Créé : {ext_path}")
    else:
        print(f"ℹ️  Déjà existant : {ext_path}")


# ─── Génération du l10n.yaml ─────────────────────────────────────────────────

L10N_YAML = """\
arb-dir: lib/l10n
template-arb-file: app_fr.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
nullable-getter: false
"""

def generate_l10n_yaml(root: Path):
    yaml_path = root / 'l10n.yaml'
    if not yaml_path.exists():
        yaml_path.write_text(L10N_YAML, encoding='utf-8')
        print(f"✅ Créé : {yaml_path}")
    else:
        print(f"ℹ️  Déjà existant : {yaml_path}")


# ─── Rapport ─────────────────────────────────────────────────────────────────

def write_report(report: list[dict], output_path: str):
    with open(output_path, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=['file','line','original','replacement','key'])
        writer.writeheader()
        writer.writerows(report)
    print(f"\n📊 Rapport CSV : {output_path}")


def write_untranslated(lib_dir: Path, lookup: dict, output_path: str):
    """Trouve les chaînes françaises restantes non encore dans l'ARB."""
    pat = re.compile(r"""(?:Text\(|label:|title:|hint:)\s*(?:const\s+)?['"]([^'"$\\\n]{3,100})['"]""")
    fr_re = re.compile(r'[àâäéèêëîïôùûüç]')
    untranslated = set()

    for path in lib_dir.rglob('*.dart'):
        if should_skip_file(path):
            continue
        content = path.read_text(encoding='utf-8', errors='ignore')
        for m in pat.finditer(content):
            s = m.group(1).strip()
            if fr_re.search(s) and s not in lookup:
                untranslated.add(s)

    with open(output_path, 'w', encoding='utf-8') as f:
        f.write("# Chaînes françaises NON présentes dans l'ARB\n")
        f.write("# Ajoutez-les manuellement dans app_fr.arb\n\n")
        for s in sorted(untranslated):
            f.write(f"{s}\n")
    print(f"📋 Chaînes non traduites : {output_path}  ({len(untranslated)} entrées)")


# ─── Main ─────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description='Migration i18n Flutter — remplace les chaînes françaises par des appels l10n'
    )
    parser.add_argument('--lib',     default='lib',              help='Dossier lib Flutter (défaut: lib/)')
    parser.add_argument('--arb',     default='lib/l10n/app_fr.arb', help='Fichier ARB source')
    parser.add_argument('--dry-run', action='store_true',        help='Aperçu sans modifier les fichiers')
    parser.add_argument('--file',    default=None,               help='Migrer un seul fichier .dart')
    parser.add_argument('--no-backup', action='store_true',      help='Ne pas créer de .bak')
    parser.add_argument('--report',  action='store_true',        help='Générer rapport CSV + liste non traduits')
    parser.add_argument('--setup',   action='store_true',        help='Générer l10n_extension.dart + l10n.yaml uniquement')
    args = parser.parse_args()

    lib_dir  = Path(args.lib).resolve()
    arb_path = Path(args.arb).resolve()
    root_dir = lib_dir.parent

    # ── Chargement ARB ──────────────────────────────────────────────────────
    if not arb_path.exists():
        print(f"❌ Fichier ARB introuvable : {arb_path}")
        print(f"   Copiez app_fr.arb dans lib/l10n/ d'abord.")
        sys.exit(1)

    arb_data = json.loads(arb_path.read_text(encoding='utf-8'))
    lookup   = build_lookup(arb_data)
    print(f"✅ ARB chargé : {len(lookup)} clés")

    # ── Setup uniquement ────────────────────────────────────────────────────
    if args.setup:
        generate_extension(lib_dir)
        generate_l10n_yaml(root_dir)
        print("\n✅ Setup terminé. Lancez maintenant :")
        print("   flutter gen-l10n")
        return

    # ── Migration ───────────────────────────────────────────────────────────
    replacer = Replacer(lookup, dry_run=args.dry_run)
    backup   = not args.no_backup
    results  = []

    if args.file:
        # Fichier unique
        p = Path(args.file).resolve()
        if not p.exists():
            print(f"❌ Fichier introuvable : {p}")
            sys.exit(1)
        r = process_file(p, replacer, backup=backup)
        results.append(r)
    else:
        # Tous les fichiers .dart du dossier lib
        dart_files = sorted(lib_dir.rglob('*.dart'))
        print(f"🔍 {len(dart_files)} fichiers .dart trouvés")
        for p in dart_files:
            if should_skip_file(p):
                continue
            r = process_file(p, replacer, backup=backup)
            results.append(r)

    # ── Résumé ──────────────────────────────────────────────────────────────
    done    = [r for r in results if r['status'] == 'done']
    dry     = [r for r in results if r['status'] == 'dry-run']
    skipped = [r for r in results if r['status'] == 'skipped']
    total_changes = sum(r['changes'] for r in results)

    print(f"\n{'='*60}")
    print(f"📦 RÉSUMÉ DE LA MIGRATION")
    print(f"{'='*60}")
    if args.dry_run:
        print(f"  Mode DRY-RUN — aucun fichier modifié")
        print(f"  Fichiers avec remplacements : {len(dry)}")
    else:
        print(f"  Fichiers modifiés    : {len(done)}")
        print(f"  Fichiers inchangés   : {len(skipped)}")
    print(f"  Remplacements totaux : {total_changes}")
    if backup and not args.dry_run:
        print(f"  Backups créés (.bak) : {len(done)}")

    # ── Rapport ─────────────────────────────────────────────────────────────
    if args.report:
        ts = datetime.now().strftime('%Y%m%d_%H%M%S')
        write_report(replacer.report, f"migration_report_{ts}.csv")
        write_untranslated(lib_dir, lookup, f"untranslated_{ts}.txt")

    # ── Génération des fichiers support ──────────────────────────────────────
    if not args.dry_run and not args.file:
        generate_extension(lib_dir)
        generate_l10n_yaml(root_dir)

    print(f"\n{'='*60}")
    print("✅ Migration terminée !")
    if not args.dry_run:
        print("\n📋 PROCHAINES ÉTAPES :")
        print("  1. flutter gen-l10n")
        print("  2. Vérifiez les TODO: l10n (NotificationService sans context)")
        print("  3. Compilez et corrigez les erreurs const restantes")
        print("  4. Traduisez app_ar.arb et app_en.arb")
        print("  5. Testez en changeant la locale dans les paramètres")
        if backup:
            print("\n🗑️  Pour supprimer les backups :")
            print("  find lib -name '*.dart.bak' -delete")
    print('='*60)


if __name__ == '__main__':
    main()
