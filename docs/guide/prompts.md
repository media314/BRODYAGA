# ImageGen manifest

Все шесть схем созданы встроенным ImageGen 23 августа 2026 года в режиме новой
генерации без входных изображений. Точные подписи, команды, значения памяти и
названия компонентов добавлены в PDF средствами ReportLab, а не запечены в растр.

## 01 — Архитектура

Роль: Open WebUI и Kimi Code подключаются к одному локальному Ollama, который
обслуживает текстовую и vision-модель.

```text
Create a landscape 3:2 black-and-white editorial architecture illustration for a
premium Russian beginner handbook about installing and using a local AI workstation.
Pure black, graphite gray, and white; crisp vector-like ink lines on a warm white
background; strict grid; generous negative space; no color, gradients, or photorealism.
Show one user with two entry points: a browser chat window and a terminal coding agent.
Both connect to one central local model server inside the same computer. The server
routes to two clearly different model symbols: a text/reasoning brain made of geometric
blocks and a vision model combining an eye with image cards. Include a small lock and
loopback/local shield to communicate that ports are local-only. Use arrows and distinct
shapes, but absolutely no letters, words, numbers, logos, watermarks, code, or fake UI
labels. The architecture must be immediately understandable at A4 half-page size.
```

## 02 — Маршрут установки

Роль: последовательность «железо → драйвер → container runtime → GPU test → clone →
запуск».

```text
Create a landscape 3:2 black-and-white editorial installation roadmap for the same
premium beginner handbook. Show a left-to-right sequence of six large symbolic steps
on one clean baseline: identify the computer and graphics card, install a graphics
driver, connect the graphics card to a container runtime, verify the GPU inside a test
container, clone a code repository, and launch a local AI stack. Use recognizable
objects such as a desktop PC, graphics card, driver package, stacked containers, a
diagnostic gauge, a repository folder, and a browser window. Include a novice user
following the path with a checklist. Crisp vector-like line art, black and graphite on
warm white, strict grid, generous negative space, no color, gradients, or photorealism.
Absolutely no letters, words, numbers, logos, watermarks, shell commands, or fake UI
text. The sequence must be clear at A4 half-page size.
```

## 03 — Три режима запуска

Роль: сравнение контейнерного CPU, контейнерного NVIDIA GPU и native Ollama.

```text
Create a landscape 3:2 monochrome editorial comparison illustration for the same
premium local-AI installation handbook. Divide the image into three equal clean
columns with no text. Column one: all services inside stacked software containers
running on a CPU-only desktop, clearly slow but universal. Column two: the same
containers connected directly to an NVIDIA-style graphics card, clearly fast and
appropriate for Linux or WSL. Column three: a local model server running natively on a
laptop with an integrated chip, while only the browser chat stays in a container,
clearly representing a native host acceleration path for macOS or Windows. Place one
user choosing among the three routes at the bottom. Pure black, graphite, and white;
crisp vector-like line art; strict grid; generous negative space; no color, gradients,
photorealism, brand marks, or text. Absolutely no letters, words, numbers, logos,
watermarks, or fake UI labels. Clear at A4 half-page size.
```

## 04 — Загрузка моделей

Роль: LLM и VLM хранятся вместе, но на RTX 3060 загружаются в VRAM по одной.

```text
Create a landscape 3:2 black-and-white editorial operating diagram for the same
premium beginner handbook. Show a local model library feeding exactly one active GPU
workspace at a time. On the left, two model packages are stored: one symbolized by a
text/reasoning brain and one by an eye with image cards. In the center, a mechanical
switch loads one package into a single graphics-card memory chamber while the other
stays safely stored. On the right, show two outcomes: a clean text conversation and an
image/screenshot analysis. Include a modest context ruler and a single-request queue
symbol, communicating conservative memory use without any labels. Pure black,
graphite, and white; crisp vector-like technical line art; generous negative space; no
color, gradients, photorealism, or decoration. Absolutely no letters, words, numbers,
logos, watermarks, code, or fake UI text. Clear at A4 half-page size.
```

## 05 — Работа Kimi Code

Роль: анализ проекта, план, предложения модели, ручной approval, правки и тесты.

```text
Regenerate from scratch a strictly grayscale landscape 3:2 editorial workflow
illustration for a premium FaceX-styled beginner handbook about Kimi Code working with
local Qwen. Use only RGB-neutral black, white, and gray with zero colored pixels or
colored accents. From left to right: developer opens a project folder; coding agent
inspects the file tree and creates a plan; local model proposes edits and terminal
actions; a prominent human hand reviews each proposal at a manual permission gate;
approved edits return to the folder; tests and a verification seal close the loop.
Risky actions are stopped at the gate. Crisp vector-like technical line art,
disciplined grid, generous white space, serious and minimal. Absolutely no letters,
words, numbers, logos, watermarks, code text, fake UI labels, gradients, or
photorealism. Clear at A4 half-page size.
```

## 06 — Диагностика памяти

Роль: здоровое GPU-размещение, признаки offload и порядок уменьшения нагрузки.

```text
Create a landscape 3:2 strictly grayscale technical editorial troubleshooting
illustration for a premium beginner handbook about running local AI on a 12 GB graphics
card. Show a diagnostic cockpit with three clearly separated instruments: GPU memory
and model placement, container/host RAM, and swap/activity. In the healthy branch, one
model fits entirely inside the graphics-card chamber, one request is active, and memory
gauges stay below limits. In the warning branch, part of a too-large model spills from
the graphics card toward system RAM; a simple corrective staircase shows closing other
GPU apps, shortening context, keeping one model and one request, and choosing a smaller
model. Include a technician following the checks in order. Use only neutral black,
white, and gray; crisp vector-like line art; strict grid; generous negative space; no
color, gradients, or photorealism. Absolutely no letters, words, numbers, logos,
watermarks, code, or fake UI labels. Clear at A4 half-page size.
```

