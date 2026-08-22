# Диагностика

Начните с одной команды:

```bash
./scripts/doctor.sh
```

## Open WebUI не открывается

```bash
docker compose -f compose.yaml ps
docker compose -f compose.yaml logs --tail=200 open-webui
curl -v http://127.0.0.1:3000/health
```

Если порт занят, измените `WEBUI_PORT=3001` в `.env` и перезапустите стек.

## UI не видит модели

```bash
curl http://127.0.0.1:11434/api/tags
docker compose -f compose.yaml exec ollama ollama list
make pull
```

В контейнерном режиме Open WebUI должен обращаться к `http://ollama:11434`, а не к
`localhost`: внутри контейнера `localhost` означает сам Open WebUI.

В native-режиме Ollama должен слушать хост и быть доступен контейнеру как
`host.docker.internal:11434`. На Linux `compose.native.yaml` добавляет host-gateway.

## NVIDIA GPU не используется

Проверяйте по слоям:

```bash
nvidia-smi
docker info --format '{{json .Runtimes}}'
docker run --rm --gpus all ubuntu nvidia-smi
docker compose -f compose.yaml -f compose.gpu.yaml exec ollama ollama ps
```

Если третий шаг не работает, переустановите/настройте NVIDIA Container Toolkit:
[docs/cuda.md](cuda.md). После `nvidia-ctk runtime configure --runtime=docker`
обязательно перезапустите Docker daemon.

После suspend/resume Linux Ollama иногда теряет GPU. Официальный workaround:

```bash
sudo rmmod nvidia_uvm
sudo modprobe nvidia_uvm
```

## Out of memory / модель работает очень медленно

1. Выберите `qwen3:4b` и `qwen3-vl:4b`.
2. Оставьте `OLLAMA_MAX_LOADED_MODELS=1` и `OLLAMA_NUM_PARALLEL=1`.
3. Уменьшите `OLLAMA_CONTEXT_LENGTH`, например до `16384`.
4. Проверьте `ollama ps`: CPU/GPU split означает нехватку VRAM.
5. На macOS не запускайте Ollama в Docker — используйте `--native`.

После правки `.env` пересоздайте Ollama:

```bash
docker compose -f compose.yaml up -d --force-recreate ollama
```

### RTX 3060 12 ГБ использует много оперативной памяти

```bash
make memory
```

- `PROCESSOR = 100% GPU` — веса модели целиком на видеокарте.
- `CPU/GPU` — часть модели выгружена в RAM; поставьте контекст 8K/16K или модель 4B.
- Держите `OLLAMA_MAX_LOADED_MODELS=1` и `OLLAMA_NUM_PARALLEL=1`.
- Включите `OLLAMA_FLASH_ATTENTION=1` и `OLLAMA_KV_CACHE_TYPE=q8_0`.
- `OLLAMA_KEEP_ALIVE=0` освобождает модель сразу после ответа.
- В `free -h` оценивайте `available`: файловый cache Linux освобождается по запросу.
- Для жёстких лимитов запускайте `make rtx3060`; overlay ограничивает Ollama 12 ГБ,
  а Open WebUI — 4 ГБ host RAM. Превышение лимита завершит контейнер по OOM вместо
  дальнейшего роста, поэтому сначала уменьшайте модель или контекст.

Полная таблица и порядок проверки: [RTX 3060 12 ГБ](models.md#rtx-3060-12-гб-без-offload-в-ram).

## Kimi сообщает, что provider не настроен

Запускайте через обёртку:

```bash
./scripts/kimi-local.sh .
```

Она создаёт нужный provider с непустым dummy key. Если конфиг ручной, проверьте:

```toml
[providers.ollama]
type = "openai"
base_url = "http://127.0.0.1:11434/v1"
api_key = "ollama"
```

Обычный `export OPENAI_API_KEY=...` не исправляет постоянный провайдер: Kimi Code
читает credentials из своего `config.toml`.

## Kimi не может вызвать инструменты

- Убедитесь, что выбрана instruct/tool-capable модель, а не base-модель.
- Проверьте простой API-запрос: `./scripts/smoke-test.sh`.
- Уменьшите контекст и повторите.
- Локальная 4B/8B модель может хуже соблюдать сложную схему tool calls, чем большая
  coding-модель. Для трудных задач переключитесь на 14B/30B или официальный Kimi.

## Сброс без удаления данных

```bash
make down
make up-gpu   # либо make up / make up-native
```

`make down` не удаляет volumes. Полное удаление volumes уничтожит модели, аккаунты,
настройки и историю чатов, поэтому отдельной автоматической команды в проекте нет.

## Логи и полезные команды

```bash
make logs
docker compose -f compose.yaml logs --tail=200 ollama
docker compose -f compose.yaml exec ollama ollama list
docker system df
```
