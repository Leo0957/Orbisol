#!/usr/bin/env python3
"""Valider la structure et les garde-fous du Codex Web Agent Kit."""

from __future__ import annotations

import re
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parent.parent

AGENT_FILES = (
    "coordinator.toml",
    "codebase-explorer.toml",
    "frontend-developer.toml",
    "backend-developer.toml",
    "ui-ux-auditor.toml",
    "qa-tester.toml",
    "security-auditor.toml",
    "seo-accessibility-auditor.toml",
    "performance-auditor.toml",
    "deployment-specialist.toml",
    "documentation-maintainer.toml",
)

SKILL_NAMES = (
    "project-discovery",
    "full-web-audit",
    "feature-implementation",
    "bug-investigation",
    "ui-ux-review",
    "responsive-audit",
    "accessibility-audit",
    "seo-audit",
    "performance-audit",
    "security-audit",
    "legal-compliance-audit",
    "automated-testing",
    "safe-refactoring",
    "dependency-review",
    "documentation-update",
    "pre-release-check",
    "deployment-audit",
    "git-commit-preparation",
)

TEMPLATE_FILES = (
    "audit-report.md",
    "implementation-plan.md",
    "bug-report.md",
    "test-report.md",
    "release-report.md",
    "project-profile-example.md",
)

SKILL_SECTIONS = (
    "Objectif",
    "Quand utiliser cette skill",
    "Quand ne pas l’utiliser",
    "Informations nécessaires",
    "Étapes de travail",
    "Vérifications obligatoires",
    "Format du résultat",
    "Règles de sécurité",
    "Critères de réussite",
)

TEXT_SUFFIXES = {
    ".md",
    ".toml",
    ".yaml",
    ".yml",
    ".py",
    ".json",
    ".jsonc",
    ".txt",
}


def required_files() -> list[Path]:
    """Retourner tous les fichiers imposés par le kit."""
    files = [
        ROOT / "AGENTS.md",
        ROOT / "README.md",
        ROOT / "PROJECT_PROFILE.template.md",
        ROOT / "TASK_TEMPLATE.md",
        ROOT / "VALIDATION.md",
        ROOT / ".codex" / "config.toml",
        ROOT / "scripts" / "validate_kit.py",
    ]
    files.extend(ROOT / ".codex" / "agents" / name for name in AGENT_FILES)
    files.extend(
        ROOT / ".agents" / "skills" / name / "SKILL.md"
        for name in SKILL_NAMES
    )
    files.extend(ROOT / "templates" / name for name in TEMPLATE_FILES)
    files.extend(
        ROOT / ".agents" / "skills" / "deployment-audit" / "references" / name
        for name in ("cloudflare-pages.md", "vercel.md", "netlify.md")
    )
    return files


def load_toml(path: Path, errors: list[str], warnings: list[str]) -> dict[str, Any] | None:
    """Charger un fichier TOML avec tomllib lorsqu’il est disponible."""
    try:
        import tomllib
    except ModuleNotFoundError:
        warnings.append("tomllib indisponible : validation syntaxique TOML ignorée")
        return None

    try:
        with path.open("rb") as handle:
            data = tomllib.load(handle)
    except (OSError, tomllib.TOMLDecodeError) as exc:
        errors.append(f"TOML invalide {path.relative_to(ROOT)} : {exc}")
        return None

    if not isinstance(data, dict):
        errors.append(f"TOML sans table racine : {path.relative_to(ROOT)}")
        return None
    return data


def parse_frontmatter(path: Path, errors: list[str]) -> dict[str, str] | None:
    """Extraire le frontmatter YAML minimal sans dépendance externe."""
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()
    relative = path.relative_to(ROOT)
    if not lines or lines[0].strip() != "---":
        errors.append(f"Frontmatter absent au début de {relative}")
        return None

    try:
        closing = next(index for index in range(1, len(lines)) if lines[index].strip() == "---")
    except StopIteration:
        errors.append(f"Frontmatter non fermé dans {relative}")
        return None

    metadata: dict[str, str] = {}
    for line_number, line in enumerate(lines[1:closing], start=2):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if ":" not in line:
            errors.append(f"YAML minimal invalide dans {relative}:{line_number}")
            continue
        key, value = line.split(":", 1)
        key = key.strip()
        value = value.strip().strip("\"'")
        if not key or not value:
            errors.append(f"Champ YAML vide dans {relative}:{line_number}")
            continue
        if key in metadata:
            errors.append(f"Champ YAML dupliqué '{key}' dans {relative}")
        metadata[key] = value

    for field in ("name", "description"):
        if not metadata.get(field):
            errors.append(f"Champ frontmatter manquant '{field}' dans {relative}")
    unexpected = sorted(set(metadata) - {"name", "description"})
    if unexpected:
        errors.append(f"Champs frontmatter non minimaux dans {relative} : {', '.join(unexpected)}")
    return metadata


def validate_required(errors: list[str]) -> None:
    for path in required_files():
        if not path.is_file():
            errors.append(f"Fichier obligatoire absent : {path.relative_to(ROOT)}")


def validate_non_empty(errors: list[str]) -> None:
    for path in sorted(item for item in ROOT.rglob("*") if item.is_file()):
        if path.stat().st_size == 0:
            errors.append(f"Fichier vide : {path.relative_to(ROOT)}")


def validate_toml(errors: list[str], warnings: list[str]) -> None:
    config = ROOT / ".codex" / "config.toml"
    if config.is_file():
        load_toml(config, errors, warnings)

    seen_names: dict[str, Path] = {}
    agent_dir = ROOT / ".codex" / "agents"
    for path in sorted(agent_dir.glob("*.toml")):
        data = load_toml(path, errors, warnings)
        if data is None:
            continue
        relative = path.relative_to(ROOT)
        for field in ("name", "description", "developer_instructions"):
            value = data.get(field)
            if not isinstance(value, str) or not value.strip():
                errors.append(f"Champ agent manquant ou vide '{field}' dans {relative}")

        name = data.get("name")
        if not isinstance(name, str) or not name:
            continue
        if not re.fullmatch(r"[a-z][a-z0-9_]*", name):
            errors.append(f"Nom d’agent non snake_case dans {relative} : {name}")
        previous = seen_names.get(name)
        if previous:
            errors.append(
                f"Nom d’agent dupliqué '{name}' dans {previous.relative_to(ROOT)} et {relative}"
            )
        seen_names[name] = path
        expected_stem = name.replace("_", "-")
        if path.stem != expected_stem:
            errors.append(f"Nom de fichier incohérent pour l’agent '{name}' : {relative}")


def section_body(text: str, heading: str) -> str:
    marker = f"## {heading}"
    start = text.find(marker)
    if start < 0:
        return ""
    content_start = start + len(marker)
    next_heading = text.find("\n## ", content_start)
    if next_heading < 0:
        next_heading = len(text)
    return text[content_start:next_heading].strip()


def validate_skills(errors: list[str]) -> None:
    seen_names: dict[str, Path] = {}
    skill_root = ROOT / ".agents" / "skills"
    for path in sorted(skill_root.glob("*/SKILL.md")):
        metadata = parse_frontmatter(path, errors)
        if metadata is None:
            continue
        relative = path.relative_to(ROOT)
        name = metadata.get("name", "")
        if not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", name):
            errors.append(f"Nom de skill invalide dans {relative} : {name}")
        if name != path.parent.name:
            errors.append(f"Nom de skill différent du dossier dans {relative} : {name}")
        previous = seen_names.get(name)
        if previous:
            errors.append(
                f"Nom de skill dupliqué '{name}' dans {previous.relative_to(ROOT)} et {relative}"
            )
        seen_names[name] = path

        text = path.read_text(encoding="utf-8")
        for heading in SKILL_SECTIONS:
            body = section_body(text, heading)
            if not body:
                errors.append(f"Section absente ou vide '{heading}' dans {relative}")
            elif len(body) < 35:
                errors.append(f"Section trop courte '{heading}' dans {relative}")


def text_files() -> list[Path]:
    return [
        path
        for path in sorted(ROOT.rglob("*"))
        if path.is_file() and path.suffix.lower() in TEXT_SUFFIXES
    ]


def validate_portability_and_secrets(errors: list[str]) -> None:
    unix_path = re.compile(
        r"(?<![A-Za-z0-9:])/(?:Users|home|root|private|var|tmp)/[^\s`\"'<>]+"
    )
    windows_path = re.compile(
        r"(?i)(?<![A-Za-z0-9])[A-Z]:[\\/](?:Users|Documents|Desktop|Program\s+Files)[^\s`\"'<>]*"
    )
    secret_assignment = re.compile(
        r"(?i)\b(?:api[_-]?key|access[_-]?token|secret|password|passwd|client[_-]?secret)\b"
        r"\s*[:=]\s*[\"']?([A-Za-z0-9_./+=-]{12,})"
    )
    ignored_values = ("example", "placeholder", "changeme", "replace", "your_")

    for path in text_files():
        relative = path.relative_to(ROOT)
        text = path.read_text(encoding="utf-8")
        for line_number, line in enumerate(text.splitlines(), start=1):
            if unix_path.search(line) or windows_path.search(line):
                errors.append(f"Chemin absolu évident dans {relative}:{line_number}")
            match = secret_assignment.search(line)
            if match and not any(word in match.group(1).lower() for word in ignored_values):
                errors.append(f"Secret manifeste ou valeur suspecte dans {relative}:{line_number}")
            unfinished_markers = ("[" + "TODO", "TO" + "DO:")
            if any(marker in line for marker in unfinished_markers):
                errors.append(f"Placeholder non remplacé dans {relative}:{line_number}")


def main() -> int:
    errors: list[str] = []
    warnings: list[str] = []

    print(f"Validation de {ROOT.name}")
    validate_required(errors)
    validate_non_empty(errors)
    validate_toml(errors, warnings)
    validate_skills(errors)
    validate_portability_and_secrets(errors)

    for warning in dict.fromkeys(warnings):
        print(f"[AVERTISSEMENT] {warning}")

    if errors:
        print(f"[ERREUR] {len(errors)} problème(s) détecté(s) :")
        for error in errors:
            print(f"  - {error}")
        return 1

    agent_count = len(list((ROOT / ".codex" / "agents").glob("*.toml")))
    skill_count = len(list((ROOT / ".agents" / "skills").glob("*/SKILL.md")))
    file_count = len([path for path in ROOT.rglob("*") if path.is_file()])
    print(f"[OK] {file_count} fichiers non vides contrôlés")
    print(f"[OK] {agent_count} agents TOML valides et uniques")
    print(f"[OK] {skill_count} skills avec frontmatter et sections obligatoires")
    print("[OK] Aucun chemin absolu évident ni secret manifeste détecté")
    return 0


if __name__ == "__main__":
    sys.exit(main())
