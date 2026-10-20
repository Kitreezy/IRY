#!/usr/bin/env python3
"""Смысловая сверка RU/EN моделью: то, чего правилом не поймать.

check.py видит, что ключ на месте и спецификаторы совпали. Он не видит,
что «Cancel» переведено как «Назад», что половина строк на «ты», а
половина на «вы», что «memory» в одном месте «воспоминание», а в другом
«запись», и что слово под числом не согласуется с ним. Это видит модель —
если дать ей обе строки, место, где строка показывается, и правила
перевода (style.json).

Модель — Claude через `claude -p`, без инструментов: всё нужное в промпте.
Модель Apple на устройстве не подходит: русского она не знает.

Режимы:
  ai_check.py                 все строки
  ai_check.py --changed REF   только изменённые относительно ветки REF
  --json                      замечания машине, иначе — markdown человеку
  --gate                      выход 1, если есть ошибки (error); сбой модели
                              проверку не роняет никогда
  --strings DIR               другой каталог с en.lproj/ru.lproj — для eval.py
"""

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

import l10n

KINDS = {"meaning", "register", "terminology", "untranslated", "truncated", "grammar", "agreement", "style"}
SEVERITIES = {"error", "warning"}

INSTRUCTIONS = """\
You review the Russian and English localization of an iOS app called Remember — a personal memory app.
For each string you get its key, the English and Russian text and where in the code it is shown.

Report only real problems:
- meaning: the two texts say different things (different action, fact, number, person, negation, missing or extra information).
- register: Russian addresses the user differently from the rule below (ты vs вы).
- terminology: a term is translated differently from the glossary, or differently in different strings.
- untranslated: text left in the other language.
- truncated: part of the text is missing in one language.
- agreement: Russian words do not agree with numbers, gender or case, including words shown next to a number.
- grammar: a grammar or punctuation error in either language.
- style: unnatural, machine-like phrasing.

Severity: "error" only when a user would be misled or confused — meaning, truncated, untranslated, agreement.
Everything else is "warning". Do not report taste. Do not report a string twice. Do not invent problems:
if both texts say the same thing naturally, say nothing about it.

Rules of this app:
{style}

Answer with a short note and then exactly one ```json block containing an array of findings:
[{{"key": "...", "severity": "error|warning", "kind": "...", "problem": "one sentence in Russian",
  "suggest_en": "fixed English or null", "suggest_ru": "fixed Russian or null"}}]
An empty array if everything is fine.
"""


def pairs(strings_dir: Path | None = None) -> list[dict]:
    """Все строки — плоско: обычные ключи и формы числа как «ключ#форма»."""
    def read(language):
        if strings_dir:
            text = (strings_dir / f"{language}.lproj" / "Localizable.strings").read_text(encoding="utf-8")
            return {k: l10n.unescape(v) for k, v in l10n._STRING.findall(text)}
        return l10n.read_strings(language)

    en, ru = read("en"), read("ru")
    used = l10n.usages()
    result = []
    for key in sorted(set(en) & set(ru)):
        result.append({"key": key, "en": en[key], "ru": ru[key], "used": l10n.usage(used, key).places[:2]})
    if not strings_dir:
        plural_en, plural_ru = l10n.read_plurals("en"), l10n.read_plurals("ru")
        for key in sorted(set(plural_en) & set(plural_ru)):
            for form, ru_value in plural_ru[key].items():
                result.append({"key": f"{key}#{form}", "en": plural_en[key].get(form, plural_en[key].get("other", "")),
                               "ru": ru_value, "used": l10n.usage(used, key).places[:2]})
    return result


def changed_keys(ref: str) -> set[str]:
    """Ключи, у которых изменился текст хоть на одном языке относительно `ref`."""
    changed = set()
    for language in l10n.LANGUAGES:
        rel = (l10n.RESOURCES / f"{language}.lproj" / "Localizable.strings").relative_to(l10n.ROOT)
        old_text = subprocess.run(["git", "show", f"{ref}:{rel}"], cwd=l10n.ROOT,
                                  capture_output=True, text=True).stdout
        old = {k: l10n.unescape(v) for k, v in l10n._STRING.findall(old_text)}
        new = l10n.read_strings(language)
        changed |= {k for k in new if old.get(k) != new[k]}
    return changed


def ask(items: list[dict]) -> tuple[list[dict] | None, str]:
    """Спросить модель. `None` — ответа нет или его не разобрать."""
    style = json.dumps(l10n.load_style(), ensure_ascii=False, indent=2)
    prompt = "Strings to review (JSON lines):\n" + "\n".join(json.dumps(i, ensure_ascii=False) for i in items)
    try:
        done = subprocess.run(
            ["claude", "-p", "--output-format", "text", "--system-prompt", INSTRUCTIONS.format(style=style),
             "--disallowedTools", "Bash", "Edit", "Write", "Read", "Glob", "Grep", "WebFetch", "WebSearch", "Task"],
            input=prompt, capture_output=True, text=True, timeout=600)
    except (OSError, subprocess.TimeoutExpired) as error:
        return None, f"claude не запустился: {error}"
    if done.returncode != 0:
        # Причину CLI пишет то в stderr, то в stdout — например, про
        # истёкшую сессию. Берём, где есть.
        reason = (done.stderr.strip() or done.stdout.strip())[-300:]
        return None, f"claude вернул {done.returncode}: {reason}"
    return parse(done.stdout, {i["key"] for i in items})


def parse(answer: str, known: set[str]) -> tuple[list[dict] | None, str]:
    blocks = re.findall(r"```(?:json)?\s*\n(.*?)```", answer, re.S)
    if not blocks:
        return None, "в ответе нет блока json"
    try:
        raw = json.loads(blocks[-1])
    except json.JSONDecodeError as error:
        return None, f"json не разобрать: {error}"
    findings = []
    for f in raw if isinstance(raw, list) else []:
        # Чужого не принимаем: ключ, которого не было, — выдумка модели.
        if not isinstance(f, dict) or f.get("key") not in known:
            continue
        f["severity"] = f.get("severity") if f.get("severity") in SEVERITIES else "warning"
        f["kind"] = f.get("kind") if f.get("kind") in KINDS else "style"
        findings.append(f)
    return findings, ""


def markdown(findings: list[dict], items: dict[str, dict], failure: str) -> str:
    if failure:
        return f"Смысловая сверка не состоялась: {failure}. Проверка не остановлена."
    if not findings:
        return f"Смысловая сверка: {len(items)} строк, замечаний нет."
    lines = [f"Смысловая сверка: {len(items)} строк, замечаний {len(findings)}.", ""]
    for f in sorted(findings, key=lambda f: (f["severity"] != "error", f["key"])):
        item = items[f["key"]]
        lines.append(f"- {'**ошибка**' if f['severity'] == 'error' else 'замечание'} · {f['kind']} · `{f['key']}` — {f.get('problem', '')}")
        lines.append(f"  - en: {item['en']!r}" + (f" → {f['suggest_en']!r}" if f.get("suggest_en") else ""))
        lines.append(f"  - ru: {item['ru']!r}" + (f" → {f['suggest_ru']!r}" if f.get("suggest_ru") else ""))
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--changed")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--gate", action="store_true")
    parser.add_argument("--strings", type=Path)
    args = parser.parse_args()

    items = pairs(args.strings)
    if args.changed:
        keys = changed_keys(args.changed)
        items = [i for i in items if i["key"].split("#")[0] in keys]
    if not items:
        print("[]" if args.json else "Смысловая сверка: изменённых строк нет.")
        return 0

    findings, failure = ask(items)
    findings = findings or []
    if args.json:
        print(json.dumps({"failure": failure, "findings": findings}, ensure_ascii=False, indent=2))
    else:
        print(markdown(findings, {i["key"]: i for i in items}, failure))
    return 1 if args.gate and any(f["severity"] == "error" for f in findings) else 0


if __name__ == "__main__":
    sys.exit(main())
