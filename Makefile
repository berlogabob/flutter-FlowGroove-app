# ================================================
# Makefile для деплоя Flutter Web → GitHub Pages
# macOS / Linux — полная автоматизация
# ================================================

REPO_NAME     := flutter-repsync-app
BASE_HREF     := /$(REPO_NAME)/

.PHONY: deploy build-web clean help

# 🔥 ОСНОВНАЯ КОМАНДА — ВСЁ В ОДНОЙ СТРОКЕ
deploy:
	@echo "🧹 1. Полная очистка..."
	rm -rf build/web docs
	
	@echo "🚀 2. Сборка Flutter Web..."
	flutter build web --release --base-href $(BASE_HREF)
	
	@echo "📁 3. Копируем в docs..."
	mkdir -p docs
	cp -r build/web/* docs/
	
	@echo "🛡️ 4. Создаём .nojekyll и 404.html..."
	touch docs/.nojekyll
	cp docs/index.html docs/404.html
	
	@echo "📤 5. Git: add + commit + push..."
	git add docs/ Makefile
	git commit -m "Deploy: update GitHub Pages" || echo "✅ Нет изменений для коммита"
	git push
	
	@echo ""
	@echo "🎉 ВСЁ ГОТОВО АВТОМАТИЧЕСКИ!"
	@echo "Сайт: https://berlogabob.github.io/flutter-repsync-app/"
	@echo "Можно сразу обновить страницу в браузере (Ctrl+Shift+R)"

build-web:
	flutter build web --release --base-href $(BASE_HREF)

clean:
	rm -rf build/web docs/*

help:
	@echo "make deploy     — полная автоматизация (clean + build + git push)"
	@echo "make build-web  — только собрать"
	@echo "make clean      — только очистка"
	@echo "make help       — справка"
