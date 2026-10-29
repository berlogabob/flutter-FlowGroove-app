# Восстановление FlowGroove

Checkpoint: /Users/berloga/MyHermes/FlowGrooveFreeze/20261026-085617
Primary checkout: /Users/berloga/Documents/GitHub/flutter_repsync_app
HEAD: 7274057d6bca9a2544d4a8e4c630d6b26fe015a3

## До очистки
- [x] Пауза обоих FlowGroove cron, snapshot jobs сохранён.
- [x] История всех refs: repository.bundle, bundle verify PASS.
- [x] Незакоммиченные изменения всех найденных worktrees: patches + исходные файлы в working-state.zip.
- [x] Приватные audit/evidence и код конвейера сохранены отдельно от scratch/cache.
- [x] Проверенный последний controller server turn завершён; baseline PID отсутствует; canonical running/review пуст.
- [ ] Скопировать весь checkpoint на внешний диск/независимый носитель.
- [ ] Только после этого выбирать безопасную очистку; не удалять список защищённых путей REPORT.md.

## После reboot
1. Не возобновлять cron. Прочитать REPORT.md и task-matrix.csv.
2. `git -C /Users/berloga/Documents/GitHub/flutter_repsync_app status --short` и `git -C /Users/berloga/Documents/GitHub/flutter_repsync_app rev-parse HEAD`.
3. Проверить `MANIFEST.json`: SHA-256 всех файлов checkpoint.
4. Если исходный checkout утерян: `git clone /Users/berloga/MyHermes/FlowGrooveFreeze/20261026-085617/repository.bundle /ABSOLUTE/NEW/flowgroove`, затем `git -C /ABSOLUTE/NEW/flowgroove switch second01`.
5. Архив сначала распаковать в отдельную папку, не поверх живого checkout. Каждый worktree восстановить на записанный head, затем проверить `git apply --check` для staged/unstaged patches. Не применять один patch дважды и не копировать старую ветку поверх primary.
6. Восстановление untracked — из worktrees/<name>/ архива; node_modules/.venv/build не архивировались и восстанавливаются пакетным менеджером. Не запускать установку до проверки SSD и нужного окружения.
7. Текущий незавершённый task сверить с exact terminal evidence/source hashes; исходные статусы не подделывать в verified.
8. Только по явному решению возобновить контроллер: `hermes cron resume 748ba92c74d8`; статус: `hermes cron resume d173a844e136`. Прежний режим НЕ рекомендован без короткого измеренного pilot.

Suggested skills: software-development/ponytail, software-dev-workflow, coding-agents, flutter-dev, tdd, flowgroove-practice-ux; hermes-agent только для scheduler/runtime troubleshooting.
