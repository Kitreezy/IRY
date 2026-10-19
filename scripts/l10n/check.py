#!/usr/bin/env python3
"""Механическая проверка локализации RU/EN.

Ловит то, что ловится правилом, — надёжно и бесплатно: ключ есть в одном
языке и нет в другом, не совпали спецификаторы формата, пустое значение,
ключ из кода без строки и строка без кода, число без форм множественного
числа, непереведённое, типографика. Смысл — забота ai_check.py.

Ошибки (error) роняют проверку, замечания (warning) — нет.
Выход: человеку — текстом, машине — `--json`.
"""

import json
import re
import sys

import l10n

CYRILLIC = re.compile(r"[А-Яа-яЁё]")
LATIN_WORD = re.compile(r"[A-Za-z]{3,}")
INTEGER = re.compile(r"%(?:\d+\$)?l{0,2}[dui]")
HARDCODED_UI = re.compile(r'\b(Text|Button|Label|TextField|Section|navigationTitle)\("([^"\\]*[A-Za-zА-Яа-яЁё]{3}[^"\\]*)"')


def finding(severity, kind, key, message, **extra):
    return {"severity": severity, "kind": kind, "key": key, "message": message, **extra}


def check() -> list[dict]:
    style = l10n.load_style()
    strings = {lang: l10n.read_strings(lang) for lang in l10n.LANGUAGES}
    plurals = {lang: l10n.read_plurals(lang) for lang in l10n.LANGUAGES}
    en, ru = strings["en"], strings["ru"]
    used = l10n.usages()
    declared = l10n.declared_in_l10n()
    out = []

    # Ключи: в обоих языках и связаны с кодом.
    for key in sorted(set(en) ^ set(ru)):
        missing = "ru" if key in en else "en"
        out.append(finding("error", "missing", key, f"нет перевода на {missing}"))
    all_keys = set(en) | set(ru) | set(plurals["en"]) | set(plurals["ru"])
    for key in sorted(declared - all_keys):
        out.append(finding("error", "unknown_key", key, "ключ есть в L10n.swift, а строки нет — на экране будет сам ключ"))
    for key in sorted(all_keys):
        if not used.get(key) or not used[key].places:
            out.append(finding("warning", "unused", key, "строка ни разу не используется в коде"))

    # Формы числа: у английского нужны one и other, у русского — ещё few и many.
    required = {"en": {"one", "other"}, "ru": {"one", "few", "many", "other"}}
    for key in sorted(set(plurals["en"]) | set(plurals["ru"])):
        for language in l10n.LANGUAGES:
            forms = plurals[language].get(key)
            if forms is None:
                out.append(finding("error", "missing", key, f"нет форм числа на {language}"))
                continue
            if lacking := required[language] - set(forms):
                out.append(finding("error", "plural", key, f"{language}: не хватает форм {sorted(lacking)}"))
        if key in plurals["en"] and key in plurals["ru"]:
            for form in ("one", "other"):
                a, b = plurals["en"][key].get(form, ""), plurals["ru"][key].get(form, "")
                if l10n.formats(a) != l10n.formats(b):
                    out.append(finding("error", "format", key, f"форма {form}: спецификаторы не совпадают", en=a, ru=b))

    for key in sorted(set(en) & set(ru)):
        a, b = en[key], ru[key]

        if not a.strip() or not b.strip():
            out.append(finding("error", "empty", key, "пустое значение", en=a, ru=b))
            continue

        if l10n.formats(a) != l10n.formats(b):
            out.append(finding("error", "format", key,
                               f"спецификаторы не совпадают: {l10n.formats(a)} и {l10n.formats(b)} — приложение упадёт или покажет мусор",
                               en=a, ru=b))

        # Число в русской строке без форм: «2 воспоминаний», «21 воспоминаний».
        # У английского две формы, у русского три — один шаблон на все числа
        # верен только для части из них.
        if INTEGER.search(b) and key not in plurals["ru"]:
            out.append(finding("error", "plural", key,
                               "число без форм множественного числа: для русского нужны one/few/many в Localizable.stringsdict",
                               ru=b))

        if not CYRILLIC.search(b) and LATIN_WORD.search(b) and a.strip() not in style["keep_as_is"]:
            words = [w for w in LATIN_WORD.findall(b) if w not in style["keep_as_is"]]
            if words:
                out.append(finding("warning", "untranslated", key, "по-русски ни одной русской буквы", en=a, ru=b))

        if a.count("\n") != b.count("\n"):
            out.append(finding("warning", "lines", key, "разное число строк — разная вёрстка", en=a, ru=b))

        for language, value in (("en", a), ("ru", b)):
            if value in style["keep_as_is"]:
                continue  # образец ввода вроде «sk-...» — не многоточие
            if "..." in value:
                out.append(finding("warning", "typography", key, f"{language}: три точки вместо «…»", **{language: value}))
            if value != value.strip(" "):
                out.append(finding("warning", "typography", key, f"{language}: пробел по краям", **{language: value}))
        if re.search(r"\b(Нажми|Нажмите)\s+чтобы\b", b):
            out.append(finding("warning", "typography", key, "ru: нет запятой перед «чтобы»", ru=b))

    # Строки интерфейса прямо в коде — мимо перевода.
    for path in l10n.APP.rglob("*.swift"):
        lines = path.read_text(encoding="utf-8").splitlines()
        in_debug = False
        for number, line in enumerate(lines, 1):
            if line.strip().startswith("#if DEBUG"):
                in_debug = True
            elif line.strip().startswith("#endif"):
                in_debug = False
            if in_debug or path.name.startswith("Preview"):
                continue
            for _, text in HARDCODED_UI.findall(line):
                out.append(finding("warning", "hardcoded", None, f"текст интерфейса в коде, мимо локализации: «{text}»",
                                   place=f"{path.relative_to(l10n.ROOT)}:{number}"))
    return out


def main() -> int:
    findings = check()
    if "--json" in sys.argv:
        print(json.dumps(findings, ensure_ascii=False, indent=2))
    else:
        for f in findings:
            where = f.get("key") or f.get("place")
            print(f"{'✗' if f['severity'] == 'error' else '·'} [{f['kind']}] {where}: {f['message']}")
            for language in ("en", "ru"):
                if language in f:
                    print(f"      {language}: {f[language]!r}")
        errors = sum(f["severity"] == "error" for f in findings)
        print(f"\nОшибок: {errors}, замечаний: {len(findings) - errors}")
    return 1 if any(f["severity"] == "error" for f in findings) else 0


if __name__ == "__main__":
    sys.exit(main())
