SHELL := /usr/bin/env bash

.PHONY: help init up up-gpu up-native up-3060 pull pull-native pull-3060 rtx3060 memory doctor logs ps down install-kimi kimi kimi-3060 test

help:
	@awk 'BEGIN {FS = ":.*## "; printf "БРОДЯГА — команды:\n\n"} /^[a-zA-Z0-9_-]+:.*## / {printf "  %-16s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

init: ## Создать .env из примера, если его ещё нет
	@test -f .env || cp .env.example .env

up: init ## Запустить Open WebUI + Ollama на CPU
	docker compose -f compose.yaml up -d

up-gpu: init ## Запустить Open WebUI + Ollama на NVIDIA GPU
	docker compose -f compose.yaml -f compose.gpu.yaml up -d

up-native: init ## Запустить UI, используя Ollama на хосте
	docker compose -f compose.native.yaml up -d

up-3060: ## Запустить оптимизированный NVIDIA-профиль для RTX 3060 12 ГБ
	docker compose --env-file profiles/rtx3060-12gb.env.example -f compose.yaml -f compose.gpu.yaml -f compose.memory-limit.yaml up -d

pull: init ## Скачать Qwen и VLM в контейнерный Ollama
	./scripts/pull-models.sh

pull-native: init ## Скачать Qwen и VLM в Ollama на хосте
	./scripts/pull-models.sh --native

pull-3060: ## Скачать рекомендованные 8B-модели для RTX 3060
	QWEN_MODEL=qwen3:8b VLM_MODEL=qwen3-vl:8b ./scripts/pull-models.sh

rtx3060: up-3060 pull-3060 ## Полностью поднять профиль RTX 3060 12 ГБ

memory: ## Проверить VRAM, GPU offload и расход RAM контейнерами
	./scripts/check-memory.sh

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

kimi-3060: ## Запустить Kimi Code с контекстом 16K для RTX 3060
	./scripts/kimi-local.sh --model qwen3:8b --context 16384 .

test: ## Проверить shell, Compose и отсутствие секретов
	./scripts/validate.sh
	./scripts/test-lugbaka.sh
