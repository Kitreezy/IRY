#!/usr/bin/env python3
"""Проверка проверки: находит ли ai_check.py ошибки, которые точно есть.

В копию строк вносятся ошибки известного вида — перевёрнутый смысл, другое
число, обрезанный текст, чужой термин, «вы» вместо «ты» и другие. Сверка
гоняется дважды: на чистых строках и на испорченных. Полнота — сколько
внесённых ошибок найдено; ложные тревоги — новые замечания к строкам,
которых не трогали. С чистым прогоном сравнивается затем, чтобы настоящие
проблемы, которые в строках уже есть, не сошли за ложные.

Как мутационное тестирование, только для перевода: мутация меняет то, что
написано, и проверка должна это заметить.
"""

import shutil
import sys
import tempfile
from pathlib import Path

import ai_check
import l10n

# ключ, язык, было, стало, вид, должна ли быть ошибкой (а не замечанием)
MUTATIONS = [
    ("memory.delete.confirm.message", "ru", "будет удалено навсегда", "можно будет восстановить", "meaning", True),
    ("voice.subtitle", "ru", "До 30 секунд", "До 60 секунд", "meaning", True),
    ("memory.create.button.save", "ru", "Сохранить", "Удалить", "meaning", True),
    ("settings.reset.footer", "ru", " Действие необратимо.", "", "truncated", True),
    ("timeline.today", "ru", "Сегодня", "Today", "untranslated", True),
    ("memory.detail.related.title", "ru", "Похожие воспоминания", "Похожие заметки", "terminology", False),
    ("voice.empty.transcript", "ru", "Попробуй ещё раз", "Попробуйте ещё раз", "register", False),
    ("settings.reset.confirm.message", "ru", "будут удалены", "будет удалено", "agreement", True),
    ("people.empty.subtitle", "en", "are discovered automatically from your memories", "are added manually", "meaning", True),
    ("search.answer.label", "ru", "Из твоих", "Из моих", "meaning", True),
]


def copy_strings(into: Path) -> None:
    for language in l10n.LANGUAGES:
        (into / f"{language}.lproj").mkdir(parents=True)
        shutil.copy(l10n.RESOURCES / f"{language}.lproj" / "Localizable.strings", into / f"{language}.lproj")


def mutate(into: Path) -> None:
    for key, language, old, new, *_ in MUTATIONS:
        path = into / f"{language}.lproj" / "Localizable.strings"
        lines = path.read_text(encoding="utf-8").splitlines(keepends=True)
        for i, line in enumerate(lines):
            if line.startswith(f'"{key}"'):
                assert old in line, f"{key}: «{old}» не найдено — набор устарел"
                lines[i] = line.replace(old, new, 1)
                break
        else:
            raise SystemExit(f"{key}: ключа нет — набор устарел")
        path.write_text("".join(lines), encoding="utf-8")


def flagged(strings_dir: Path) -> dict[str, dict]:
    findings, failure = ai_check.ask(ai_check.pairs(strings_dir))
    if findings is None:
        raise SystemExit(f"сверка не состоялась: {failure}")
    return {f["key"]: f for f in findings}


def main() -> int:
    with tempfile.TemporaryDirectory() as tmp:
        clean, broken = Path(tmp) / "clean", Path(tmp) / "broken"
        copy_strings(clean)
        copy_strings(broken)
        mutate(broken)
        print("Чистые строки…", file=sys.stderr)
        before = flagged(clean)
        print("Испорченные строки…", file=sys.stderr)
        after = flagged(broken)

    mutated = {m[0] for m in MUTATIONS}
    found = 0
    print(f"{'вид':<14}{'ключ':<34}{'найдено':<10}уровень")
    for key, _, _, _, kind, must_be_error in MUTATIONS:
        f = after.get(key)
        hit = f is not None and key not in before
        found += hit
        level = f["severity"] if f else "—"
        note = "" if not f or (f["severity"] == "error") == must_be_error else "  (ожидался другой уровень)"
        print(f"{kind:<14}{key:<34}{'да' if hit else 'нет':<10}{level}{note}")

    noise = sorted(set(after) - set(before) - mutated)
    print(f"\nНайдено {found} из {len(MUTATIONS)} внесённых ошибок.")
    print(f"Новых замечаний к нетронутым строкам: {len(noise)}" + (f" — {', '.join(noise)}" if noise else ""))
    print(f"На чистых строках замечаний: {len(before)} (настоящие проблемы или шум — смотреть глазами).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
