# Kimi Code CLI и подключение моделей

[Kimi Code CLI](https://github.com/MoonshotAI/kimi-code) — терминальный coding agent:
он читает и редактирует файлы, запускает команды, работает с вебом и поддерживает
OpenAI-compatible провайдеры. Это отдельный клиент, но в БРОДЯГЕ он использует тот
же Ollama и те же веса, что Open WebUI.

## Установка

Официальный скрипт Moonshot AI обёрнут локальной командой:

```bash
./scripts/install-kimi.sh
kimi --version
```

Эквивалентная официальная команда для macOS/Linux:

```bash
curl -fsSL https://code.kimi.com/kimi-code/install.sh | bash
```

Windows PowerShell:

```powershell
irm https://code.kimi.com/kimi-code/install.ps1 | iex
```

На Windows также нужен Git for Windows, потому что Kimi использует Git Bash.

## Локальный Qwen через Ollama

Сначала запустите БРОДЯГУ и скачайте модели, затем:

```bash
./scripts/kimi-local.sh /path/to/your/project
```

Скрипт:

1. читает `QWEN_MODEL` из `.env`;
2. создаёт изолированный `.runtime/kimi/config.toml`;
3. подключается к `http://127.0.0.1:11434/v1` как к OpenAI Chat Completions API;
4. запускает Kimi в выбранном проекте с ручными подтверждениями команд.

`.runtime/` исключён из Git. Глобальный `~/.kimi-code/config.toml` не меняется.

Примеры:

```bash
# Текстовая модель по умолчанию
./scripts/kimi-local.sh .

# Vision-модель для разбора скриншотов
./scripts/kimi-local.sh --model qwen3-vl:8b .

# Ollama на другой машине
./scripts/kimi-local.sh \
  --model qwen3:14b \
  --base-url http://192.168.1.50:11434/v1 \
  ~/code/project
```

`api_key = "ollama"` в конфиге — не секрет. Kimi требует непустое поле для
OpenAI-провайдера, а локальный Ollama этот ключ не проверяет.

## Ручной глобальный конфиг

Готовый пример лежит в [`kimi/config.ollama.toml`](../kimi/config.ollama.toml).
Если хотите сделать его глобальным:

```bash
mkdir -p ~/.kimi-code
cp kimi/config.ollama.toml ~/.kimi-code/config.toml
kimi
```

Если глобальный файл уже существует, сначала сохраните копию и объедините секции
вручную. Kimi читает долгосрочную конфигурацию из `~/.kimi-code/config.toml`.

Минимальная структура подключения:

```toml
default_model = "ollama/qwen3:8b"
default_permission_mode = "manual"

[providers.ollama]
type = "openai"
base_url = "http://127.0.0.1:11434/v1"
api_key = "ollama"

[models."ollama/qwen3:8b"]
provider = "ollama"
model = "qwen3:8b"
max_context_size = 32768
capabilities = ["thinking", "tool_use"]
```

## Официальные модели Kimi

Чтобы использовать управляемый Kimi Code, запустите:

```bash
kimi
```

В интерфейсе введите `/login` и выберите OAuth Kimi Code либо Moonshot AI API key.
OAuth сам создаёт и обновляет credentials; ручной TOML не нужен.

Для Moonshot Open Platform можно добавить провайдера вручную:

```toml
[providers.kimi]
type = "kimi"
base_url = "https://api.moonshot.ai/v1"
api_key = "YOUR_MOONSHOT_API_KEY"
```

Не коммитьте реальный ключ. В новых версиях Kimi Code удобнее использовать
интерактивную команду `/provider` или `kimi provider`.

## Другой OpenAI-compatible сервер

Схема та же для vLLM, SGLang, LM Studio или удалённого Ollama:

```toml
[providers.local]
type = "openai"
base_url = "http://server.example:8000/v1"
api_key = "local-or-real-key"

[models."local/my-model"]
provider = "local"
model = "served-model-name"
max_context_size = 32768
capabilities = ["thinking", "tool_use"]
```

Проверьте, что сервер действительно реализует streaming Chat Completions и tool
calling: coding agent зависит от инструментов сильнее, чем обычный чат.

## Разрешения агента

Проект использует `default_permission_mode = "manual"`: команды и изменения можно
проверить до выполнения. Не включайте `yolo`/`auto` для незнакомого репозитория или
модели без понимания последствий. В пример также добавлен запрет на `rm -rf*`.

Официальная документация:

- [Getting Started](https://moonshotai.github.io/kimi-code/en/guides/getting-started)
- [Providers and models](https://moonshotai.github.io/kimi-code/en/configuration/providers)
- [Configuration files](https://moonshotai.github.io/kimi-code/en/configuration/config-files)
- [Command reference](https://moonshotai.github.io/kimi-code/en/reference/kimi-command)
