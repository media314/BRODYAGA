# NVIDIA, CUDA и Docker GPU

Эта инструкция нужна для **Linux/WSL2 + NVIDIA**. На macOS CUDA не существует:
установите Ollama нативно и запускайте БРОДЯГУ с `--native`, чтобы использовать Metal.

> Для данного Docker-стека полный CUDA Toolkit на хосте не нужен. Нужны
> NVIDIA driver и NVIDIA Container Toolkit. CUDA runtime приезжает вместе с
> контейнером Ollama. Устанавливайте `cuda-toolkit` только если вам отдельно
> нужны `nvcc` или CUDA-библиотеки для разработки.

## 1. Требования

- NVIDIA GPU с compute capability **5.0+**.
- NVIDIA driver **550+** — минимальное требование Ollama на момент проверки.
  Для старых GPU с compute capability 5.0–6.2 нужен driver 570+.
- 64-битный Linux; рекомендуются Ubuntu 24.04/26.04 или другой дистрибутив из
  [матрицы NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/supported-platforms.html).
- Docker Engine / Docker Desktop и Compose v2.

Проверьте железо:

```bash
lspci | grep -i nvidia
uname -m
cat /etc/os-release
```

## 2. NVIDIA driver на Ubuntu

Ниже — вариант через официальный сетевой репозиторий NVIDIA. Подставьте код ОС:

| ОС | `DISTRO` |
|---|---|
| Ubuntu 22.04 | `ubuntu2204` |
| Ubuntu 24.04 | `ubuntu2404` |
| Ubuntu 26.04 | `ubuntu2604` |

```bash
DISTRO=ubuntu2404

sudo apt-get update
sudo apt-get install -y linux-headers-$(uname -r) wget
wget https://developer.download.nvidia.com/compute/cuda/repos/${DISTRO}/x86_64/cuda-keyring_1.1-1_all.deb
sudo dpkg -i cuda-keyring_1.1-1_all.deb
sudo apt-get update
sudo apt-get install -y nvidia-open
sudo reboot
```

После перезагрузки:

```bash
nvidia-smi
cat /proc/driver/nvidia/version
```

Если GPU не поддерживает open kernel modules, используйте рекомендуемый NVIDIA
вариант `cuda-drivers` вместо `nvidia-open`. Для Secure Boot может потребоваться
подписать/зарегистрировать модуль (MOK) или изменить настройку Secure Boot в UEFI.
Сверяйтесь с [официальной Ubuntu-инструкцией NVIDIA](https://docs.nvidia.com/datacenter/tesla/driver-installation-guide/ubuntu.html),
поскольку пакеты и поддерживаемые версии меняются.

## 3. NVIDIA Container Toolkit

Для Ubuntu/Debian:

```bash
sudo apt-get update
sudo apt-get install -y --no-install-recommends ca-certificates curl gnupg2

curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
  | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

curl -sL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
  | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
  | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

Проверьте проброс GPU:

```bash
docker run --rm --gpus all ubuntu nvidia-smi
```

Если эта команда не работает, Ollama в контейнере тоже не увидит GPU. Полный
актуальный процесс описан в [NVIDIA Container Toolkit Install Guide](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html).

## 4. Запуск БРОДЯГИ на GPU

```bash
./scripts/doctor.sh
./scripts/bootstrap.sh --gpu
docker compose -f compose.yaml exec ollama ollama ps
```

Во время генерации `ollama ps` покажет размещение модели. В идеале столбец
`PROCESSOR` содержит `100% GPU`; смешанный CPU/GPU означает, что модель или KV-cache
не помещаются в VRAM.

Выбрать конкретные GPU можно, добавив к сервису Ollama переменную
`CUDA_VISIBLE_DEVICES`. UUID надёжнее порядкового номера:

```bash
nvidia-smi -L
```

## 5. Нужен именно CUDA Toolkit?

Для разработки CUDA после установки репозитория:

```bash
sudo apt-get install -y cuda-toolkit
nvcc --version
```

Сверьте версию toolkit, ОС и GCC с текущей
[CUDA Installation Guide for Linux](https://docs.nvidia.com/cuda/cuda-installation-guide-linux/).
Она не обязана совпадать с версией CUDA, которую показывает верхняя строка
`nvidia-smi`: там указана максимальная версия runtime, поддерживаемая драйвером.

## WSL2

1. Установите свежий NVIDIA driver **в Windows**.
2. Обновите WSL: `wsl --update`.
3. Включите WSL2 backend в Docker Desktop.
4. Не ставьте Linux display driver внутрь WSL поверх Windows-драйвера.
5. Проверьте `nvidia-smi` в WSL и тестовый Docker-контейнер выше.

После этого используйте `./scripts/bootstrap.sh --gpu` из файловой системы WSL.

## macOS / Apple Silicon

Docker-контейнер Ollama не получает Metal GPU. Используйте native-схему:

```bash
# Установите Ollama с https://ollama.com/download и запустите приложение,
# либо в терминале:
ollama serve

./scripts/bootstrap.sh --native
```

Open WebUI останется в Docker, а модели будут считаться нативным Ollama через Metal.
