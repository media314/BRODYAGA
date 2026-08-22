SHELL := /usr/bin/env bash

.PHONY: help init up up-gpu up-native pull pull-native doctor logs ps down install-kimi kimi test

help:
	@awk 'BEGIN {FS = ":.*## "; printf "БРОДЯГА — команды:\n\n"} /^[a-zA-Z_-]+:.*## / {printf "  %-16s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

init: ## Создать .env из примера, если его ещё нет
	@test -f .env || cp .env.example .env

up: init ## Запустить Open WebUI + Ollama на CPU
	docker compose -f compose.yaml up -d

up-gpu: init ## Запустить Open WebUI + Ollama на NVIDIA GPU
	docker compose -f compose.yaml -f compose.gpu.yaml up -d

up-native: init ## Запустить UI, используя Ollama на хосте
	docker compose -f compose.native.yaml up -d

pull: init ## Скачать Qwen и VLM в контейнерный Ollama
	./scripts/pull-models.sh

pull-native: init ## Скачать Qwen и VLM в Ollama на хосте
	./scripts/pull-models.sh --native

doctor: ## Проверить хост, Docker, GPU и API
	./scripts/doctor.sh

logs: ## Показать логи контейнерного стека
	docker compose -f compose.yaml logs -f --tail=100

ps: ## Показать состояние сервисов
	docker compose -f compose.yaml ps

down: ## Остановить сервисы, сохранив модели и чаты
	docker compose -f compose.yaml down
	docker compose -f compose.native.yaml down

install-kimi: ## Установить Kimi Code официальным скриптом
	./scripts/install-kimi.sh

kimi: ## Запустить Kimi Code с локальным Qwen
	./scripts/kimi-local.sh .

test: ## Проверить shell, Compose и отсутствие секретов
	./scripts/validate.sh
