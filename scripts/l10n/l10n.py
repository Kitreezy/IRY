"""Разбор локализации Remember: строки RU/EN, формы числа и где ключи используются.

Общий для механической проверки (check.py) и смысловой (ai_check.py).
"""

import json
import plistlib
import re
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / "Remember" / "Remember"
RESOURCES = APP / "Resources"
LANGUAGES = ("en", "ru")

_STRING = re.compile(r'^"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)";', re.M)
_KEY_IN_CODE = re.compile(r'(?:String\(localized:|NSLocalizedString\()\s*"([^"]+)"')
# Интенты берут строки через LocalizedStringResource, и ключ бывает с
# подстановкой: "intent.create.done \(title)" — это ключ "intent.create.done %@".
# Запоминается часть до подстановки, сравнивается с началом ключа.
_RESOURCE_IN_CODE = re.compile(r'LocalizedStringResource\(\s*"([a-z][a-z0-9.]*)')
_FORMAT = re.compile(r"%(?:\d+\$)?(?:l{0,2}[dui]|[@fs])")


def unescape(value: str) -> str:
    return value.encode("utf-8").decode("unicode_escape").encode("latin-1").decode("utf-8")


def read_strings(language: str) -> dict[str, str]:
    path = RESOURCES / f"{language}.lproj" / "Localizable.strings"
    text = path.read_text(encoding="utf-8")
    return {key: unescape(value) for key, value in _STRING.findall(text)}


def read_plurals(language: str) -> dict[str, dict[str, str]]:
    """Формы числа из Localizable.stringsdict: ключ → {one, few, many, other}."""
    path = RESOURCES / f"{language}.lproj" / "Localizable.stringsdict"
    if not path.exists():
        return {}
    plurals = {}
    for key, entry in plistlib.loads(path.read_bytes()).items():
        forms = {}
        for name, rule in entry.items():
            if isinstance(rule, dict) and rule.get("NSStringFormatSpecTypeKey") == "NSStringPluralRuleType":
                forms = {k: v for k, v in rule.items() if k in ("zero", "one", "two", "few", "many", "other")}
        plurals[key] = forms
    return plurals


def formats(value: str) -> list[str]:
    """Спецификаторы формата без позиций: «%1$@ и %d» → ['%@', '%d']."""
    return sorted(re.sub(r"\d+\$", "", spec) for spec in _FORMAT.findall(value))


@dataclass
class Usage:
    """Где ключ используется в коде — для контекста и поиска мёртвых ключей."""
    places: list[str] = field(default_factory=list)


def usages() -> dict[str, Usage]:
    """Ключ → места в коде. L10n.swift — посредник: ключ в нём связан с
    именем вроде `L10n.Search.title`, и настоящие места — там, где это имя."""
    found: dict[str, Usage] = {}
    swift_files = [p for p in APP.rglob("*.swift")]
    l10n = APP / "Shared" / "L10n.swift"

    # Ключ → имя в L10n: перечисление и свойство вокруг строки с ключом.
    names: dict[str, str] = {}
    enum = member = None
    for line in l10n.read_text(encoding="utf-8").splitlines():
        if m := re.match(r"\s*enum (\w+)", line):
            enum = m.group(1) if m.group(1) != "L10n" else enum
        if m := re.search(r"static (?:let|func) (\w+)", line):
            member = m.group(1)
        # Ключ внутри функции — у объявления строкой выше.
        for key in set(_KEY_IN_CODE.findall(line) + re.findall(r'"([a-z]+(?:\.[a-z0-9]+)+)"', line)):
            names[key] = f"L10n.{enum}.{member}"

    for path in swift_files:
        rel = path.relative_to(ROOT)
        for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            if path == l10n:
                continue
            for key in _KEY_IN_CODE.findall(line) + _RESOURCE_IN_CODE.findall(line):
                found.setdefault(key, Usage()).places.append(f"{rel}:{number}: {line.strip()}")
            for key, name in names.items():
                if re.search(re.escape(name) + r"\b", line):
                    found.setdefault(key, Usage()).places.append(f"{rel}:{number}: {line.strip()}")
    for key in names:
        found.setdefault(key, Usage())
    return found


def usage(found: dict[str, Usage], key: str) -> Usage:
    """Где используется ключ — с учётом ключей с подстановкой («ключ %@»)."""
    return found.get(key) or found.get(key.split(" ")[0]) or Usage()


def read_table(language: str, table: str) -> dict[str, str]:
    path = RESOURCES / f"{language}.lproj" / f"{table}.strings"
    if not path.exists():
        return {}
    return {key: unescape(value) for key, value in _STRING.findall(path.read_text(encoding="utf-8"))}


def declared_in_l10n() -> set[str]:
    text = (APP / "Shared" / "L10n.swift").read_text(encoding="utf-8")
    return set(_KEY_IN_CODE.findall(text)) | set(re.findall(r'"([a-z]+(?:\.[a-z0-9]+)+)"', text))


def load_style() -> dict:
    return json.loads((Path(__file__).parent / "style.json").read_text(encoding="utf-8"))
