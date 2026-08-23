#!/usr/bin/env python3
"""Build the FaceX-styled BRODYAGA installation and operating guide."""

from __future__ import annotations

import argparse
import os
from pathlib import Path

from reportlab.lib.colors import HexColor
from reportlab.lib.pagesizes import A4
from reportlab.lib.utils import ImageReader
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas


PAGE_W, PAGE_H = A4
MARGIN_X = 54
CONTENT_W = PAGE_W - 2 * MARGIN_X
TOP_Y = PAGE_H - 56
BOTTOM_Y = 50
TOTAL_PAGES = 26

INK = HexColor("#0B0D12")
GRAPHITE = HexColor("#4A5563")
MUTED = HexColor("#7E899B")
LINE = HexColor("#D9DEE6")
PANEL = HexColor("#F3F5F7")
SOFT = HexColor("#F8F9FA")
WHITE = HexColor("#FFFFFF")


def parse_args() -> argparse.Namespace:
    here = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=here / "BRODYAGA-install-and-work-guide-v1.0.pdf")
    parser.add_argument("--logo", type=Path, default=Path(os.environ.get("FACEX_LOGO", "")))
    parser.add_argument("--font-dir", type=Path, default=Path(os.environ.get("FACEX_FONT_DIR", "")))
    return parser.parse_args()


def register_fonts(font_dir: Path) -> tuple[str, str]:
    regular = font_dir / "InterDisplay-Regular.ttf"
    semibold = font_dir / "InterDisplay-SemiBold.ttf"
    if regular.is_file() and semibold.is_file():
        pdfmetrics.registerFont(TTFont("FXRegular", str(regular)))
        pdfmetrics.registerFont(TTFont("FXSemibold", str(semibold)))
        return "FXRegular", "FXSemibold"
    return "Helvetica", "Helvetica-Bold"


class Guide:
    def __init__(self, output: Path, logo: Path, font_dir: Path) -> None:
        self.output = output
        self.output.parent.mkdir(parents=True, exist_ok=True)
        self.regular, self.semibold = register_fonts(font_dir)
        self.logo = logo if logo.is_file() else None
        self.assets = Path(__file__).resolve().parent / "assets"
        self.c = canvas.Canvas(str(output), pagesize=A4, pageCompression=1)
        self.c.setTitle("БРОДЯГА — установка и работа")
        self.c.setSubject("Пошаговое руководство по Open WebUI, Ollama, Qwen 3, Qwen 3 VL и Kimi Code")
        self.c.setAuthor("FaceX / media314")
        self.page_no = 0

    def finish(self) -> None:
        if self.page_no != TOTAL_PAGES:
            raise RuntimeError(f"Expected {TOTAL_PAGES} pages, built {self.page_no}")
        self.c.save()

    def _new_page(self, section: str | None = None, *, cover: bool = False) -> None:
        if self.page_no:
            self.c.showPage()
        self.page_no += 1
        self.c.setFillColor(WHITE)
        self.c.rect(0, 0, PAGE_W, PAGE_H, stroke=0, fill=1)
        if cover:
            return
        self.c.setStrokeColor(LINE)
        self.c.setLineWidth(0.6)
        self.c.line(MARGIN_X, PAGE_H - 34, PAGE_W - MARGIN_X, PAGE_H - 34)
        self.c.line(MARGIN_X, 34, PAGE_W - MARGIN_X, 34)
        self.c.setFont(self.semibold, 6.6)
        self.c.setFillColor(MUTED)
        self.c.drawString(MARGIN_X, PAGE_H - 27, "FACEX / БРОДЯГА")
        if section:
            self.c.drawRightString(PAGE_W - MARGIN_X, PAGE_H - 27, section.upper())
        self.c.setFont(self.regular, 6.5)
        self.c.drawString(MARGIN_X, 22, "РУКОВОДСТВО ПО УСТАНОВКЕ И РАБОТЕ")
        self.c.drawRightString(PAGE_W - MARGIN_X, 22, f"v1.0 · {self.page_no:02d}")

    def overline(self, text: str, y: float) -> float:
        self.c.setFillColor(MUTED)
        self.c.setFont(self.semibold, 7.5)
        self.c.drawString(MARGIN_X, y, text.upper())
        return y - 20

    def title(self, text: str, y: float, size: float = 25, leading: float | None = None) -> float:
        return self.text(text, MARGIN_X, y, CONTENT_W, self.semibold, size, leading or size * 1.08, INK) - 10

    def text(
        self,
        text: str,
        x: float,
        y: float,
        width: float,
        font: str | None = None,
        size: float = 9.2,
        leading: float = 13.2,
        color=GRAPHITE,
        max_lines: int | None = None,
    ) -> float:
        font = font or self.regular
        lines: list[str] = []
        for paragraph in text.split("\n"):
            if paragraph == "":
                lines.append("")
                continue
            words = paragraph.split()
            current = ""
            for word in words:
                trial = word if not current else f"{current} {word}"
                if pdfmetrics.stringWidth(trial, font, size) <= width:
                    current = trial
                else:
                    if current:
                        lines.append(current)
                    current = word
            if current:
                lines.append(current)
        if max_lines is not None:
            lines = lines[:max_lines]
        self.c.setFillColor(color)
        self.c.setFont(font, size)
        for line in lines:
            self.c.drawString(x, y, line)
            y -= leading
        return y

    def bullet_list(self, items: list[str], x: float, y: float, width: float, size: float = 8.8, gap: float = 6) -> float:
        for item in items:
            self.c.setFillColor(INK)
            self.c.circle(x + 2.5, y - 3, 1.35, stroke=0, fill=1)
            y = self.text(item, x + 13, y, width - 13, size=size, leading=size * 1.42, color=GRAPHITE) - gap
        return y

    def quote(self, text: str, y: float, caption: str | None = None) -> float:
        box_h = 74 if caption else 62
        self.c.setFillColor(PANEL)
        self.c.roundRect(MARGIN_X, y - box_h, CONTENT_W, box_h, 5, stroke=0, fill=1)
        self.c.setFillColor(INK)
        self.c.rect(MARGIN_X, y - box_h, 4, box_h, stroke=0, fill=1)
        ty = y - 22
        ty = self.text(f"«{text}»", MARGIN_X + 18, ty, CONTENT_W - 36, self.semibold, 12, 16, INK)
        if caption:
            self.c.setFont(self.regular, 7)
            self.c.setFillColor(MUTED)
            self.c.drawString(MARGIN_X + 18, y - box_h + 12, caption.upper())
        return y - box_h - 14

    def code(self, lines: list[str], y: float, *, size: float = 7.5, padding: float = 13) -> float:
        leading = size * 1.45
        box_h = padding * 2 + leading * len(lines)
        self.c.setFillColor(INK)
        self.c.roundRect(MARGIN_X, y - box_h, CONTENT_W, box_h, 4, stroke=0, fill=1)
        self.c.setFillColor(WHITE)
        cy = y - padding - size
        for line in lines:
            # Built-in Courier has no Cyrillic glyphs. Keep it for shell syntax,
            # but use the registered FaceX font for Russian comments/prompts.
            self.c.setFont("Courier" if line.isascii() else self.regular, size)
            self.c.drawString(MARGIN_X + padding, cy, line)
            cy -= leading
        return y - box_h - 13

    def table(
        self,
        headers: list[str],
        rows: list[list[str]],
        col_widths: list[float],
        y: float,
        *,
        font_size: float = 7.3,
        header_size: float = 6.8,
        row_padding: float = 6,
    ) -> float:
        x0 = MARGIN_X
        line_h = font_size * 1.35

        def wrap(value: str, width: float, font: str, size: float) -> list[str]:
            words = value.split()
            out: list[str] = []
            cur = ""
            for word in words:
                trial = word if not cur else f"{cur} {word}"
                if pdfmetrics.stringWidth(trial, font, size) <= width - row_padding * 2:
                    cur = trial
                else:
                    if cur:
                        out.append(cur)
                    cur = word
            if cur:
                out.append(cur)
            return out or [""]

        header_h = 27
        self.c.setFillColor(INK)
        self.c.rect(x0, y - header_h, sum(col_widths), header_h, stroke=0, fill=1)
        x = x0
        self.c.setFillColor(WHITE)
        self.c.setFont(self.semibold, header_size)
        for label, width in zip(headers, col_widths):
            self.c.drawString(x + row_padding, y - 17, label.upper())
            x += width
        y -= header_h

        for ridx, row in enumerate(rows):
            wrapped = [wrap(value, width, self.regular, font_size) for value, width in zip(row, col_widths)]
            row_h = max(len(lines) for lines in wrapped) * line_h + row_padding * 2
            self.c.setFillColor(SOFT if ridx % 2 == 0 else WHITE)
            self.c.rect(x0, y - row_h, sum(col_widths), row_h, stroke=0, fill=1)
            self.c.setStrokeColor(LINE)
            self.c.setLineWidth(0.45)
            self.c.line(x0, y - row_h, x0 + sum(col_widths), y - row_h)
            x = x0
            self.c.setFillColor(GRAPHITE)
            self.c.setFont(self.regular, font_size)
            for lines, width in zip(wrapped, col_widths):
                cy = y - row_padding - font_size
                for line in lines:
                    self.c.drawString(x + row_padding, cy, line)
                    cy -= line_h
                x += width
            y -= row_h
        return y - 10

    def image(self, filename: str, y: float, height: float = 320) -> float:
        path = self.assets / filename
        image = ImageReader(str(path))
        iw, ih = image.getSize()
        scale = min(CONTENT_W / iw, height / ih)
        w, h = iw * scale, ih * scale
        x = MARGIN_X + (CONTENT_W - w) / 2
        self.c.drawImage(image, x, y - h, width=w, height=h, preserveAspectRatio=True, mask="auto")
        return y - h - 12

    def labels(self, labels: list[tuple[str, str]], y: float, columns: int = 3) -> float:
        gap = 10
        width = (CONTENT_W - gap * (columns - 1)) / columns
        for idx, (head, body) in enumerate(labels):
            row, col = divmod(idx, columns)
            x = MARGIN_X + col * (width + gap)
            by = y - row * 63
            self.c.setFillColor(PANEL)
            self.c.roundRect(x, by - 50, width, 50, 4, stroke=0, fill=1)
            self.c.setFont(self.semibold, 7.4)
            self.c.setFillColor(INK)
            self.c.drawString(x + 9, by - 14, head.upper())
            self.text(body, x + 9, by - 27, width - 18, size=7.1, leading=9.4, color=GRAPHITE, max_lines=2)
        rows = (len(labels) + columns - 1) // columns
        return y - rows * 63

    def field(self, label: str, value: str, x: float, y: float, width: float) -> None:
        self.c.setFont(self.semibold, 6.5)
        self.c.setFillColor(MUTED)
        self.c.drawString(x, y, label.upper())
        self.c.setStrokeColor(LINE)
        self.c.line(x, y - 26, x + width, y - 26)
        self.c.setFont(self.regular, 10)
        self.c.setFillColor(INK)
        self.c.drawString(x, y - 19, value)

    def section_page(self, section: str, title: str, intro: str) -> float:
        self._new_page(section)
        y = self.overline(section, TOP_Y)
        y = self.title(title, y)
        return self.text(intro, MARGIN_X, y, CONTENT_W, size=10.3, leading=15.4, color=GRAPHITE) - 14


def build(args: argparse.Namespace) -> None:
    g = Guide(args.output.resolve(), args.logo.resolve(), args.font_dir.resolve())

    # 01 — Cover
    g._new_page(cover=True)
    if g.logo:
        logo = ImageReader(str(g.logo))
        iw, ih = logo.getSize()
        lw = 118
        lh = lw * ih / iw
        g.c.drawImage(logo, (PAGE_W - lw) / 2, PAGE_H - 118, width=lw, height=lh, mask="auto")
    g.c.setFont(g.semibold, 7.5)
    g.c.setFillColor(MUTED)
    g.c.drawString(MARGIN_X, 640, "РУКОВОДСТВО / ЛОКАЛЬНЫЙ AI")
    y = g.text("БРОДЯГА:\nустановка\nи работа", MARGIN_X, 600, CONTENT_W, g.semibold, 36, 39, INK)
    g.text(
        "Пошаговый путь от чистой системы до локального чата, Qwen 3 / Qwen 3 VL и Kimi Code — без облачной обязаловки и без догадок.",
        MARGIN_X,
        y - 5,
        CONTENT_W - 34,
        size=12,
        leading=17,
        color=GRAPHITE,
    )
    g.c.setStrokeColor(INK)
    g.c.setLineWidth(0.8)
    g.c.line(MARGIN_X, 215, PAGE_W - MARGIN_X, 215)
    col = (CONTENT_W - 20) / 3
    g.field("Год", "____________", MARGIN_X, 195, col)
    g.field("Версия", "1.0", MARGIN_X + col + 10, 195, col)
    g.field("Владелец", "media314", MARGIN_X + 2 * (col + 10), 195, col)
    g.field("Дата выпуска", "2026-08-23", MARGIN_X, 133, col)
    g.field("Статус", "PUBLIC", MARGIN_X + col + 10, 133, col)
    g.field("Репозиторий", "media314/BRODYAGA", MARGIN_X + 2 * (col + 10), 133, col)

    # 02 — How to use
    y = g.section_page("Навигация", "Как пользоваться руководством", "Этот PDF написан для человека, который умеет открыть терминал, но ещё не обязан понимать Docker, CUDA, VLM или API.")
    g.field("Проект", "________________________________", MARGIN_X, y, 210)
    g.field("Год", "________", MARGIN_X + 240, y, 85)
    g.field("Ответственный", "________________________", MARGIN_X + 345, y, 142)
    y -= 64
    y = g.labels([
        ("1 · Выберите режим", "CPU, NVIDIA GPU или native Ollama."),
        ("2 · Подготовьте хост", "Git, Docker, драйвер и toolkit по ситуации."),
        ("3 · Запустите стек", "Bootstrap создаст конфиг и скачает модели."),
        ("4 · Войдите в чат", "Первая учётная запись становится администратором."),
        ("5 · Подключите Kimi", "Агент использует тот же Ollama API."),
        ("6 · Проверьте память", "Для 3060 цель — одна модель и 100% GPU."),
    ], y, columns=3)
    y -= 4
    g.quote("Копируйте команды по одному блоку и проверяйте результат перед следующим шагом.", y, "Главное правило для новичка")

    # 03 — Architecture
    y = g.section_page("Архитектура", "Что именно вы запускаете", "БРОДЯГА объединяет два интерфейса и один локальный inference-сервер. Все связи по умолчанию остаются на вашем компьютере.")
    y = g.image("01-architecture.png", y, 315)
    y = g.labels([
        ("Open WebUI", "Чат в браузере на localhost:3000."),
        ("Kimi Code", "Coding agent в терминале и папке проекта."),
        ("Ollama", "Локальный API на localhost:11434."),
        ("Qwen 3", "Текст, рассуждение, инструменты и код."),
        ("Qwen 3 VL", "Изображения, скриншоты, документы и OCR."),
        ("Loopback", "Порты 127.0.0.1 не открыты наружу."),
    ], y, columns=3)
    g.quote("Один сервер, два интерфейса, одна библиотека моделей.", y - 4)

    # 04 — Components
    y = g.section_page("Архитектура", "Где живут программы и данные", "Понимание четырёх мест снимает половину типичных вопросов: хост, контейнеры, volumes и рабочая папка репозитория.")
    y = g.table(["Место", "Что там", "Что важно"], [
        ["Хост", "NVIDIA driver, Docker, Git; в native-режиме ещё Ollama", "Драйвер связывает ОС с GPU. Полный CUDA Toolkit стеку не нужен."],
        ["Контейнер Ollama", "Модели и API", "В GPU-режиме получает видеокарту через NVIDIA Container Toolkit."],
        ["Контейнер Open WebUI", "Интерфейс, аккаунты, история", "Обращается к Ollama по внутреннему имени ollama:11434."],
        ["Docker volumes", "Веса моделей, настройки, чаты", "make down их сохраняет; down -v удаляет данные."],
        [".env", "Модели, порты, контекст, параллельность", "Не коммитить. Bootstrap создаёт файл из .env.example."],
        [".runtime/kimi", "Изолированный конфиг Kimi", "Не меняет глобальный ~/.kimi-code/config.toml."],
    ], [90, 177, 220], y, font_size=7.5)
    g.quote("Контейнер — это процесс с настройками. Volume — это данные, которые переживают перезапуск.", y)

    # 05 — Modes
    y = g.section_page("Выбор режима", "CPU, NVIDIA GPU или native", "Выберите один путь до запуска. Режимы независимы: один не является обязательной ступенью другого.")
    y = g.image("03-launch-modes.png", y, 315)
    g.table(["Режим", "Кому подходит", "Команда"], [
        ["CPU", "Любой компьютер; медленно, но предсказуемо", "./scripts/bootstrap.sh --cpu"],
        ["GPU", "Linux / WSL2 + NVIDIA", "./scripts/bootstrap.sh --gpu"],
        ["Native", "macOS / Windows или Ollama уже на хосте", "./scripts/bootstrap.sh --native"],
    ], [72, 211, 204], y, font_size=7.5)

    # 06 — Requirements
    y = g.section_page("Требования", "Сколько нужно памяти", "Цифры ниже — практический старт для одной активной модели и одного запроса. Контекст и параллельность расходуют дополнительную память.")
    y = g.table(["Профиль", "Модели Q4", "RAM", "VRAM", "Диск"], [
        ["Лёгкий", "Qwen 3 4B + VL 4B", "16 ГБ", "6–8 ГБ", "15+ ГБ"],
        ["Рекомендуемый", "Qwen 3 8B + VL 8B", "32 ГБ", "10–12 ГБ", "25+ ГБ"],
        ["Мощный", "Qwen 3 30B + VL 30B", "64 ГБ", "24+ ГБ", "55+ ГБ"],
    ], [85, 185, 70, 70, 77], y, font_size=7.7)
    y = g.overline("RTX 3060 12 ГБ", y - 6)
    y = g.table(["Компонент", "Минимум", "Рекомендуется", "Почему"], [
        ["GPU", "RTX 3060 12 ГБ", "10+ ГБ свободной VRAM", "Монитор и браузер тоже занимают VRAM"],
        ["Driver", "550+", "Актуальный стабильный", "Текущее требование Ollama для CC 8.6"],
        ["RAM", "16 ГБ", "32 ГБ", "Docker, UI, cache и запас без swap"],
        ["CPU", "4 ядра", "6+ ядер / 12 потоков", "Загрузка и вспомогательные задачи"],
        ["SSD", "25 ГБ", "40 ГБ", "Образы, две 8B-модели, обновления"],
        ["ОС", "Linux x86_64 / WSL2", "Ubuntu 24.04 LTS", "Простой путь Docker + NVIDIA"],
    ], [75, 105, 132, 175], y, font_size=7.0)

    # 07 — Preflight
    y = g.section_page("Подготовка", "Проверка перед установкой", "Не начинайте с Docker Compose. Сначала убедитесь, что ОС видит железо и что выбранный режим реалистичен.")
    y = g.labels([
        ("ОС", "uname -m и cat /etc/os-release"),
        ("GPU", "lspci | grep -i nvidia"),
        ("Драйвер", "nvidia-smi"),
        ("Docker", "docker --version"),
        ("Compose v2", "docker compose version"),
        ("Диск", "df -h"),
    ], y, columns=3)
    y -= 8
    y = g.code([
        "uname -m",
        "cat /etc/os-release",
        "lspci | grep -i nvidia",
        "nvidia-smi",
        "docker --version",
        "docker compose version",
        "docker info",
    ], y)
    y = g.bullet_list([
        "Если nvidia-smi не работает, не переходите к Container Toolkit: сначала исправьте драйвер.",
        "На macOS CUDA не существует — используйте native Ollama и Metal.",
        "Для CPU-режима NVIDIA driver и Container Toolkit не нужны.",
    ], MARGIN_X, y, CONTENT_W)
    g.quote("Каждый следующий слой проверяется только после предыдущего.", y)

    # 08 — Driver
    y = g.section_page("NVIDIA", "Драйвер на Ubuntu", "Пример ниже рассчитан на Ubuntu 24.04. Пакеты и поддержка меняются: перед установкой сверяйтесь с официальной инструкцией NVIDIA.")
    y = g.code([
        "DISTRO=ubuntu2404",
        "sudo apt-get update",
        "sudo apt-get install -y linux-headers-$(uname -r) wget",
        "wget https://developer.download.nvidia.com/compute/cuda/repos/\\",
        "${DISTRO}/x86_64/cuda-keyring_1.1-1_all.deb",
        "sudo dpkg -i cuda-keyring_1.1-1_all.deb",
        "sudo apt-get update",
        "sudo apt-get install -y nvidia-open",
        "sudo reboot",
    ], y, size=7.0)
    y = g.overline("После перезагрузки", y)
    y = g.code(["nvidia-smi", "cat /proc/driver/nvidia/version"], y)
    y = g.bullet_list([
        "Для RTX 3060 ориентир — NVIDIA driver 550 или новее.",
        "Если open kernel modules не поддерживаются, используйте рекомендованный NVIDIA пакет cuda-drivers.",
        "Secure Boot может потребовать регистрацию ключа MOK; сообщение установщика нельзя пропускать.",
        "Строка CUDA в nvidia-smi показывает максимум runtime драйвера, а не установленный CUDA Toolkit.",
    ], MARGIN_X, y, CONTENT_W, size=8.4)
    g.quote("Для запуска Ollama в Docker полный CUDA Toolkit на хосте не нужен.", y)

    # 09 — Container toolkit
    y = g.section_page("NVIDIA", "NVIDIA Container Toolkit", "Драйвер уже должен работать. Toolkit даёт Docker-контейнеру доступ к видеокарте.")
    y = g.code([
        "sudo apt-get update",
        "sudo apt-get install -y ca-certificates curl gnupg2",
        "KEYRING=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg",
        "LIST_URL=https://nvidia.github.io/libnvidia-container/stable/deb/\\",
        "nvidia-container-toolkit.list",
        "curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \\",
        "  | sudo gpg --dearmor -o \"$KEYRING\"",
        "curl -sL \"$LIST_URL\" \\",
        "  | sed \"s#deb https://#deb [signed-by=$KEYRING] https://#g\" \\",
        "  | sudo tee /etc/apt/sources.list.d/nvidia-ctk.list",
        "sudo apt-get update",
        "sudo apt-get install -y nvidia-container-toolkit",
        "sudo nvidia-ctk runtime configure --runtime=docker",
        "sudo systemctl restart docker",
    ], y, size=6.6)
    y = g.overline("Контрольный тест", y)
    y = g.code(["docker run --rm --gpus all ubuntu nvidia-smi"], y)
    y = g.bullet_list([
        "Если тестовый контейнер не видит GPU, Ollama тоже не увидит его.",
        "В WSL2 драйвер ставится в Windows; Linux display driver поверх него внутри WSL не устанавливайте.",
        "После настройки runtime Docker daemon обязательно перезапускается.",
    ], MARGIN_X, y, CONTENT_W, size=8.4)

    # 10 — Installation roadmap
    y = g.section_page("Установка", "Весь путь одной схемой", "Шесть шагов идут строго слева направо. Подписи под схемой — ваша контрольная карта.")
    y = g.image("02-installation-roadmap.png", y, 315)
    g.labels([
        ("1 · Железо", "ОС видит RTX 3060."),
        ("2 · Драйвер", "nvidia-smi без ошибки."),
        ("3 · Toolkit", "Docker получил runtime NVIDIA."),
        ("4 · GPU test", "Контейнер видит карту."),
        ("5 · Репозиторий", "Клон и локальный .env."),
        ("6 · Запуск", "UI, модели и health checks."),
    ], y, columns=3)

    # 11 — Clone/bootstrap
    y = g.section_page("Установка", "Клонирование и первый запуск", "Работайте из обычной пользовательской папки. Не запускайте bootstrap через sudo: Docker должен быть настроен для вашего пользователя.")
    y = g.code([
        "git clone https://github.com/media314/BRODYAGA.git",
        "cd BRODYAGA",
        "./scripts/doctor.sh",
    ], y)
    y = g.overline("Linux / WSL2 + NVIDIA", y)
    y = g.code(["./scripts/bootstrap.sh --gpu"], y)
    y = g.overline("Слабая машина", y)
    y = g.code(["./scripts/bootstrap.sh --gpu --light", "# или: ./scripts/bootstrap.sh --cpu --light"], y)
    y = g.overline("macOS / Windows с native Ollama", y)
    y = g.code(["ollama serve", "./scripts/bootstrap.sh --native"], y)
    y = g.bullet_list([
        "Bootstrap создаёт .env из .env.example, запускает сервисы и скачивает две модели.",
        "Стандартные 8B-веса суммарно занимают около 11.3 ГБ на диске; загрузка может быть долгой.",
        "Чтобы запустить сервисы без моделей, добавьте --skip-models и позже выполните make pull.",
    ], MARGIN_X, y, CONTENT_W, size=8.4)

    # 12 — First login
    y = g.section_page("Первый вход", "Откройте чат и зафиксируйте администратора", "После окончания bootstrap интерфейс доступен по адресу http://localhost:3000.")
    y = g.labels([
        ("Откройте", "http://localhost:3000"),
        ("Создайте аккаунт", "Первая учётная запись станет admin."),
        ("Выберите модель", "qwen3:8b для обычного диалога."),
        ("Сделайте запрос", "Первый ответ загрузит модель в память."),
        ("Проверьте", "make doctor и make memory."),
        ("Закройте signup", "ENABLE_SIGNUP=false после регистрации."),
    ], y, columns=3)
    y -= 8
    y = g.code([
        "make doctor",
        "make memory",
        "./scripts/smoke-test.sh",
    ], y)
    y = g.bullet_list([
        "localhost доступен только на этом компьютере; это безопасное значение по умолчанию.",
        "Не меняйте bind на 0.0.0.0 без TLS, reverse proxy и продуманной аутентификации.",
        "Чаты и настройки сохраняются в volume open-webui-data.",
    ], MARGIN_X, y, CONTENT_W)
    g.quote("Первый рабочий результат — не красивый экран, а успешный health check и ответ модели.", y)

    # 13 — Daily chat
    y = g.section_page("Open WebUI", "Как работать в чате каждый день", "Начните с простой задачи. Выбор модели зависит от входных данных, а не от названия вкладки.")
    y = g.table(["Задача", "Модель", "Как действовать"], [
        ["Текст, план, письмо, код", "qwen3:8b", "Опишите цель, контекст, ограничения и формат ответа."],
        ["Скриншот, фото, PDF-страница", "qwen3-vl:8b", "Прикрепите файл и укажите, что именно найти или сравнить."],
        ["Быстрый ответ на слабой машине", "4B", "Переключитесь на light-профиль или измените .env."],
        ["Длинный анализ", "8B / больше", "Следите за контекстом: он расходует KV-cache."],
    ], [128, 100, 259], y, font_size=7.6)
    y = g.overline("Шаблон хорошего запроса", y)
    y = g.code([
        "Цель: что должно получиться.",
        "Контекст: какие данные и для кого.",
        "Ограничения: что нельзя менять или выдумывать.",
        "Формат: таблица, чек-лист, код, краткий ответ.",
        "Проверка: по каким признакам ответ верный.",
    ], y)
    y = g.bullet_list([
        "Для VLM укажите область изображения: весь экран, таблица, ошибка или конкретный элемент.",
        "Не отправляйте модели секреты только потому, что стек локальный: чаты всё равно сохраняются.",
        "В сборке нет отдельного moderation-сервиса; поведение зависит от весов модели и системного промпта.",
    ], MARGIN_X, y, CONTENT_W, size=8.4)

    # 14 — Model selection
    y = g.section_page("Модели", "Выберите размер без самообмана", "Размер файла — только веса. Сверху нужны KV-cache, runtime, vision encoder и буферы.")
    y = g.table(["Модель", "Вес Q4", "RTX 3060 12 ГБ", "Применение"], [
        ["qwen3:4b", "2.5 ГБ", "Большой запас", "Быстрый текст, короткие coding-задачи"],
        ["qwen3-vl:4b", "3.3 ГБ", "Большой запас", "Лёгкий vision и OCR"],
        ["qwen3:8b", "5.2 ГБ", "Да, одна модель", "Основной чат и Kimi"],
        ["qwen3-vl:8b", "6.1 ГБ", "Да, одна модель", "Основной визуальный разбор"],
        ["qwen3:14b", "9.3 ГБ", "Погранично", "Только короткий контекст; offload возможен"],
        ["qwen3:30b", "19 ГБ", "Нет", "Веса уже больше VRAM"],
    ], [130, 70, 120, 167], y, font_size=7.3)
    y = g.bullet_list([
        "Для 3060 выбирайте 8B как потолок комфортного старта и держите одну модель.",
        "VLM загружается вместо LLM; небольшая пауза при переключении — ожидаемое поведение.",
        "Заявленное окно 256K не означает, что такой контекст помещается в 12 ГБ VRAM.",
        "Если важнее скорость и стабильность, 4B часто полезнее пограничной 14B.",
    ], MARGIN_X, y, CONTENT_W)
    g.quote("Контекст — это бюджет памяти, а не бесплатный максимум.", y)

    # 15 — Model loading visual
    y = g.section_page("Модели", "Одна активная модель на RTX 3060", "Обе 8B-модели хранятся на диске, но в VRAM загружается только та, к которой пришёл текущий запрос.")
    y = g.image("04-model-loading.png", y, 315)
    y = g.labels([
        ("Библиотека", "Веса LLM и VLM лежат на диске."),
        ("Переключатель", "Ollama выгружает предыдущую модель."),
        ("VRAM", "Одна модель + её KV-cache."),
        ("Текст", "Qwen 3 отвечает в чате и Kimi."),
        ("Зрение", "Qwen 3 VL получает изображение."),
        ("Очередь", "Один запрос не умножает память."),
    ], y, columns=3)
    g.quote("Одна активная модель — это контроль бюджета, а не поломка.", y - 4)

    # 16 — .env
    y = g.section_page("Настройка", "Параметры .env простыми словами", "Для RTX 3060 готовый профиль уже содержит безопасные значения. Если настраиваете вручную, меняйте один параметр за раз.")
    y = g.code([
        "QWEN_MODEL=qwen3:8b",
        "VLM_MODEL=qwen3-vl:8b",
        "OLLAMA_CONTEXT_LENGTH=16384",
        "OLLAMA_KEEP_ALIVE=0",
        "OLLAMA_MAX_LOADED_MODELS=1",
        "OLLAMA_NUM_PARALLEL=1",
        "OLLAMA_FLASH_ATTENTION=1",
        "OLLAMA_KV_CACHE_TYPE=q8_0",
    ], y)
    y = g.table(["Параметр", "Что делает", "Для 3060"], [
        ["CONTEXT_LENGTH", "Максимум токенов и размер KV-cache", "16K; при offload снизить до 8K"],
        ["KEEP_ALIVE", "Сколько модель остаётся загруженной", "0 — выгрузить после ответа"],
        ["MAX_LOADED_MODELS", "Число моделей одновременно", "1"],
        ["NUM_PARALLEL", "Параллельные запросы на модель", "1"],
        ["FLASH_ATTENTION", "Снижает рост памяти на длинном контексте", "1"],
        ["KV_CACHE_TYPE", "Точность и размер KV-cache", "q8_0 ≈ половина f16"],
    ], [145, 215, 127], y, font_size=7.0)

    # 17 — VLM
    y = g.section_page("Qwen 3 VL", "Как разбирать изображения", "VLM не читает ваши мысли. Передайте изображение и задайте наблюдаемую задачу.")
    y = g.labels([
        ("1 · Прикрепите", "Скриншот, фото или страницу документа."),
        ("2 · Укажите область", "Например, правая панель или строка ошибки."),
        ("3 · Сформулируйте цель", "Распознать, сравнить, извлечь или объяснить."),
        ("4 · Задайте формат", "Таблица полей, список дефектов, краткое резюме."),
        ("5 · Попросите доказательство", "Сослаться на видимые элементы."),
        ("6 · Проверьте", "OCR и числа сверяются человеком."),
    ], y, columns=3)
    y -= 8
    y = g.code([
        "Разбери приложенный скриншот.",
        "Цель: найти причину ошибки авторизации.",
        "Сначала перечисли только видимые факты.",
        "Потом дай 3 гипотезы от наиболее вероятной.",
        "Не выдумывай текст, которого не видно.",
    ], y)
    y = g.bullet_list([
        "Для длинных документов загружайте релевантные страницы, а не весь архив без задачи.",
        "При переключении с qwen3:8b на qwen3-vl:8b Ollama может заново загрузить веса.",
        "VLM-output не является источником истины для критических чисел, дат и юридических фактов.",
    ], MARGIN_X, y, CONTENT_W)
    g.quote("Сначала видимые факты, затем интерпретация.", y)

    # 18 — Kimi install
    y = g.section_page("Kimi Code", "Установка coding agent", "Kimi Code — отдельный терминальный клиент. БРОДЯГА подключает его к локальному Ollama через OpenAI-compatible API.")
    y = g.overline("macOS / Linux", y)
    y = g.code(["./scripts/install-kimi.sh", "kimi --version"], y)
    y = g.overline("Официальный эквивалент", y)
    y = g.code(["curl -fsSL https://code.kimi.com/kimi-code/install.sh | bash"], y)
    y = g.overline("Windows PowerShell", y)
    y = g.code(["irm https://code.kimi.com/kimi-code/install.ps1 | iex"], y)
    y = g.bullet_list([
        "На Windows заранее установите Git for Windows: Kimi использует Git Bash.",
        "Локальный скрипт сначала скачивает официальный installer во временный файл и только потом запускает его.",
        "После установки откройте новый терминал, если команда kimi ещё не появилась в PATH.",
        "Официальная облачная модель подключается отдельно: запустите kimi и выполните /login.",
    ], MARGIN_X, y, CONTENT_W)
    g.quote("Установка Kimi не запускает модель: модель уже обслуживает Ollama.", y)

    # 19 — Kimi connect
    y = g.section_page("Kimi Code", "Подключение локального Qwen", "Самый безопасный путь — обёртка репозитория. Она создаёт изолированный конфиг и включает ручные подтверждения.")
    y = g.code([
        "./scripts/kimi-local.sh .",
        "# профиль RTX 3060:",
        "make kimi-3060",
        "# VLM для скриншотов:",
        "./scripts/kimi-local.sh --model qwen3-vl:8b .",
    ], y)
    y = g.table(["Поле", "Значение", "Смысл"], [
        ["type", "openai", "Kimi использует Chat Completions protocol"],
        ["base_url", "http://127.0.0.1:11434/v1", "OpenAI-compatible endpoint Ollama"],
        ["api_key", "ollama", "Непустая заглушка; локальный Ollama не проверяет"],
        ["permission", "manual", "Команды и правки подтверждает человек"],
        ["context", "16384", "Совпадает с безопасным профилем 3060"],
    ], [95, 190, 202], y, font_size=7.3)
    y = g.bullet_list([
        "Конфиг создаётся в .runtime/kimi и не трогает глобальный файл пользователя.",
        "Для удалённого Ollama передайте --base-url, но открывайте API только в доверенной сети.",
        "Coding agent сильнее зависит от tool calling, чем чат; маленькая модель может ошибаться чаще.",
    ], MARGIN_X, y, CONTENT_W, size=8.3)

    # 20 — Kimi workflow
    y = g.section_page("Kimi Code", "Как агент меняет проект", "Рабочий цикл остаётся под контролем человека: изучение, план, предложение, approval, изменение и проверка.")
    y = g.image("05-kimi-workflow.png", y, 315)
    y = g.labels([
        ("Папка", "Вы выбираете точный проект."),
        ("Анализ", "Агент читает структуру и контекст."),
        ("План", "Действия формулируются до правок."),
        ("Approval", "Команда проходит ручной gate."),
        ("Изменение", "Разрешённые файлы обновляются."),
        ("Проверка", "Тесты и diff закрывают цикл."),
    ], y, columns=3)
    g.quote("Kimi предлагает; человек решает.", y - 4, "Режим manual")

    # 21 — Kimi daily
    y = g.section_page("Kimi Code", "Безопасная ежедневная работа", "Не начинайте просьбой «исправь всё». Дайте агенту узкую цель и критерий готовности.")
    y = g.labels([
        ("1 · Откройте проект", "Запускать Kimi из нужной папки."),
        ("2 · Дайте задачу", "Один результат, ясные границы."),
        ("3 · Попросите план", "Файлы, риски, проверки."),
        ("4 · Читайте diff", "Не подтверждать незнакомые команды."),
        ("5 · Запустите тесты", "Команды реального репозитория."),
        ("6 · Зафиксируйте итог", "Что изменено и что осталось."),
    ], y, columns=3)
    y -= 8
    y = g.code([
        "Изучи репозиторий и сначала дай план.",
        "Цель: добавить команду диагностики без изменения данных.",
        "Не трогай файлы вне scripts/ и docs/.",
        "Перед командами объясняй риск.",
        "Готово, когда make test проходит.",
    ], y)
    y = g.bullet_list([
        "Не включайте yolo/auto для незнакомого проекта или новой локальной модели.",
        "Секреты, .env и ключи не должны попадать в prompt, diff или commit.",
        "Если агент предлагает удаление, остановитесь и проверьте точный target и возможность восстановления.",
        "Для сложной coding-задачи официальный Kimi или большая модель может быть надёжнее локальной 8B.",
    ], MARGIN_X, y, CONTENT_W, size=8.2)

    # 22 — Prompt recipes
    y = g.section_page("Практика", "Три готовых сценария", "Эти шаблоны можно копировать в Open WebUI или Kimi и подставлять свои данные.")
    y = g.overline("Чат", y)
    y = g.code([
        "Объясни тему для новичка.",
        "Сначала дай аналогию, затем 5 шагов и чек-лист.",
        "Новые термины объясняй при первом употреблении.",
    ], y)
    y = g.overline("VLM", y)
    y = g.code([
        "Разбери изображение. Отдели факты от предположений.",
        "Верни таблицу: область / наблюдение / риск / проверка.",
        "Нечитаемые фрагменты пометь как неопределённые.",
    ], y)
    y = g.overline("Kimi", y)
    y = g.code([
        "Сначала прочитай AGENTS.md и релевантные файлы.",
        "Ничего не меняй до плана. Сохрани пользовательские правки.",
        "После изменений запусти проектные проверки и покажи итог.",
    ], y)
    y = g.bullet_list([
        "Если ответ слабый, уточняйте входные данные, а не только просите «подумай лучше».",
        "Большой контекст не исправляет плохую постановку задачи.",
        "Локальность не отменяет ответственность владельца за законное и безопасное использование.",
    ], MARGIN_X, y, CONTENT_W, size=8.4)

    # 23 — 3060 memory settings
    y = g.section_page("Память", "RTX 3060: режим без offload", "Цель — веса и KV-cache одной модели находятся в VRAM, а системная RAM не используется для вычислительного offload.")
    y = g.code([
        "make rtx3060",
        "# отправьте один запрос модели",
        "make memory",
        "make kimi-3060",
    ], y)
    y = g.table(["Проверка", "Здоровое значение", "Если не так"], [
        ["ollama ps", "PROCESSOR = 100% GPU", "Уменьшить контекст или модель"],
        ["Loaded models", "Одна", "MAX_LOADED_MODELS=1"],
        ["Context", "16384", "Снизить до 8192"],
        ["Parallel", "1", "NUM_PARALLEL=1"],
        ["docker stats", "Ollama <12 ГБ; UI <4 ГБ", "Проверить memory overlay"],
        ["free -h", "available стабильно", "Закрыть процессы; проверить swap"],
        ["nvidia-smi", "Нет лишних GPU-приложений", "Закрыть игры и GPU-ускоренный браузер"],
    ], [120, 165, 202], y, font_size=7.2)
    y = g.bullet_list([
        "100% GPU не означает 0 байт RAM: Docker, UI, драйвер, буферы и файловый cache используют память.",
        "q8_0 KV-cache занимает примерно половину f16 с очень небольшой потерей точности.",
        "KEEP_ALIVE=0 освобождает модель после ответа, но следующий первый токен будет медленнее.",
    ], MARGIN_X, y, CONTENT_W, size=8.2)

    # 24 — Diagnostics visual
    y = g.section_page("Память", "Что проверять, если «жрёт оперативу»", "Смотрите не на одну цифру, а на размещение модели, лимиты контейнеров, available RAM и swap.")
    y = g.image("06-memory-diagnostics.png", y, 315)
    y = g.labels([
        ("VRAM", "Модель целиком на GPU."),
        ("Host RAM", "Оценивайте available, а не used."),
        ("Swap", "Не должен расти во время ответа."),
        ("Закрыть лишнее", "Освободить GPU-процессы."),
        ("Уменьшить", "Контекст 16K → 8K."),
        ("Упростить", "8B → 4B, один запрос."),
    ], y, columns=3)
    g.quote("100% GPU — цель; нулевое потребление RAM — миф.", y - 4)

    # 25 — Troubleshooting
    y = g.section_page("Диагностика", "Если что-то не работает", "Идите сверху вниз. Не меняйте несколько параметров одновременно — иначе причина потеряется.")
    y = g.table(["Симптом", "Проверка", "Следующее действие"], [
        ["UI не открывается", "docker compose ps; logs open-webui; curl /health", "Проверить порт; WEBUI_PORT=3001"],
        ["UI не видит модели", "curl :11434/api/tags; ollama list", "make pull; внутри Docker URL = ollama:11434"],
        ["GPU не используется", "nvidia-smi; Docker runtime; test container", "Переустановить/настроить Container Toolkit"],
        ["Очень медленно / OOM", "ollama ps; make memory", "Контекст 8K/16K; одна модель; 4B"],
        ["Kimi без provider", "Проверить запуск через wrapper", "./scripts/kimi-local.sh ."],
        ["Kimi ломает tool calls", "./scripts/smoke-test.sh", "Снизить контекст; выбрать сильнее модель"],
    ], [113, 185, 189], y, font_size=7.0)
    y = g.code([
        "./scripts/doctor.sh",
        "make logs",
        "make memory",
        "./scripts/smoke-test.sh",
        "make test",
    ], y)
    y = g.bullet_list([
        "make down останавливает сервисы и сохраняет модели, аккаунты и чаты.",
        "Не используйте docker compose down -v без осознанного решения удалить данные.",
        "После suspend/resume Linux при потере GPU может помочь перезагрузка модуля nvidia_uvm или системы.",
    ], MARGIN_X, y, CONTENT_W, size=8.3)

    # 26 — Operations and sources
    y = g.section_page("Финал", "Рабочая памятка", "Пять команд закрывают обычный жизненный цикл. Сохраните эту страницу рядом с компьютером.")
    y = g.table(["Когда", "Команда", "Что получите"], [
        ["Первый запуск 3060", "make rtx3060", "Стек, лимиты и две 8B-модели"],
        ["Проверка", "make doctor", "Состояние хоста, GPU, API и Kimi"],
        ["Контроль памяти", "make memory", "VRAM, offload, container RAM"],
        ["Логи", "make logs", "Последние события Ollama и UI"],
        ["Остановка", "make down", "Сервисы остановлены, данные сохранены"],
    ], [130, 140, 217], y, font_size=7.3)
    y = g.overline("Проверенные источники · 2026-08-23", y - 2)
    sources = [
        ("Open WebUI Quick Start", "https://docs.openwebui.com/getting-started/quick-start/"),
        ("Ollama GPU / FAQ / OpenAI compatibility", "https://docs.ollama.com/gpu"),
        ("NVIDIA Container Toolkit", "https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html"),
        ("Kimi Code Getting Started", "https://moonshotai.github.io/kimi-code/en/guides/getting-started"),
        ("Kimi providers and models", "https://moonshotai.github.io/kimi-code/en/configuration/providers"),
        ("Qwen 3 VL in Ollama", "https://ollama.com/library/qwen3-vl"),
    ]
    for label, url in sources:
        g.c.setFont(g.semibold, 7.2)
        g.c.setFillColor(INK)
        g.c.drawString(MARGIN_X, y, label)
        g.c.setFont(g.regular, 6.4)
        g.c.setFillColor(MUTED)
        g.c.drawString(MARGIN_X, y - 10, url)
        g.c.linkURL(url, (MARGIN_X, y - 13, PAGE_W - MARGIN_X, y + 3), relative=0)
        y -= 30
    y -= 2
    y = g.quote("Курсантье всегда придёт на помощь!", y, "Пометка на полях")
    g.c.setFont(g.regular, 7)
    g.c.setFillColor(MUTED)
    g.c.drawCentredString(PAGE_W / 2, max(48, y), "media314/BRODYAGA · FaceX layout system · Public guide")

    g.finish()


if __name__ == "__main__":
    build(parse_args())
