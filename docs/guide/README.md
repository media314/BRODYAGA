# БРОДЯГА — PDF-руководство

[Скачать готовый PDF](BRODYAGA-install-and-work-guide-v1.0.pdf)

Это учебная версия основной документации репозитория: 26 страниц A4 с полями под
год и владельца, шестью схемами, командами установки, настройкой RTX 3060 12 ГБ,
работой в Open WebUI, подключением Qwen 3 / Qwen 3 VL к Kimi Code и диагностикой
RAM/VRAM.

## Что лежит в папке

- `BRODYAGA-install-and-work-guide-v1.0.pdf` — готовый документ;
- `build_guide.py` — воспроизводимая ReportLab-вёрстка;
- `assets/` — шесть монохромных схем, созданных встроенным ImageGen;
- `prompts.md` — манифест генерации и роли изображений.

## Как пересобрать

Документ использует мастер-логотип и Inter Display из внутреннего хранилища
FaceX, но не копирует их в публичный репозиторий. Передайте пути явно:

```bash
python3 -m pip install reportlab

python3 docs/guide/build_guide.py \
  --logo "/path/to/facex-logo-black.png" \
  --font-dir "/path/to/FaceX/fonts" \
  --output docs/guide/BRODYAGA-install-and-work-guide-v1.0.pdf
```

Без шрифтов скрипт использует Helvetica. Без `--logo` PDF собирается без знака,
поэтому публичный финал следует выпускать только с проверенным master asset.

## Источник содержания

Точные команды взяты из `README.md`, `docs/cuda.md`, `docs/models.md`,
`docs/kimi.md`, `docs/troubleshooting.md` и скриптов репозитория. Верстка следует
внутренним правилам FaceX: официальный знак, Inter Display, белое поле,
чёрно-графитная палитра, строгая сетка, явные доказательства и human control.

