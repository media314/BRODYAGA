#!/usr/bin/env bash
# Also accept: sh lugbaka.sh (Ubuntu's /bin/sh is dash).
if [ -z "${BASH_VERSION:-}" ]; then exec bash "$0" "$@"; fi
set -Eeuo pipefail
umask 077

SELF="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/$(basename -- "${BASH_SOURCE[0]}")"
ROOT="$(dirname -- "$SELF")"
SCRIPT_DIR="$ROOT"
UPSTREAM_SHA=0a8c37804d7f65faf8da458e55f3d2705ba8e92c
ACTION=install
MODE=auto
LIGHT=0
SKIP_MODELS=0
SKIP_KIMI=0
PROJECT=""
WEB_PORT=""
OLLAMA_PORT_ARG=""
BIND_ARG=""
SUBNET_ARG=""
DOCKER_CONTEXT=default
NO_SYSTEM_CHANGES=0
QA_ID=""
DOCKER=(docker --context "$DOCKER_CONTEXT")
AS_ROOT=()
CONFIG=""
RUNTIME_DIR=""
APT_WORK=""
APT_OPTIONS=()

say() { printf '\n==> %s\n' "$*"; }
die() { printf '\nОШИБКА: %s\n' "$*" >&2; exit 1; }
on_error() {
  local rc="$1" line="$2"
  printf '\nУстановка прервана (код %s, строка %s). Данные сохранены; повторите ту же команду.\n' "$rc" "$line" >&2
  exit "$rc"
}
trap 'on_error "$?" "$LINENO"' ERR
cleanup() {
  local rc=$?
  if [[ -n "$APT_WORK" ]]; then
    "${AS_ROOT[@]}" rm -rf -- "$APT_WORK" || printf 'Не удалось удалить временные индексы APT: %s\n' "$APT_WORK" >&2
  fi
  exit "$rc"
}
trap cleanup EXIT

banner() {
  [[ ! -t 1 || -n "${NO_COLOR:-}" ]] || printf '\033[1;36m'
  local columns="${COLUMNS:-80}"
  if [[ -z "${COLUMNS:-}" && -t 1 ]] && command -v tput >/dev/null; then columns="$(tput cols 2>/dev/null || printf 80)"; fi
  [[ "$columns" =~ ^[0-9]{1,4}$ ]] || columns=80
  if ((10#$columns >= 160)); then
    cat <<'LUGBAKA160'


                               ###           ###     ###     ########    #########        #####      ###     ###      #####
                               ###::         ###::   ###::  ##########:  ##########:     #######:    ###::  ###:::   #######:
                               ###::.        ###::.  ###::.###:::::::::: ###:::::###:   ###:::###:   ###::.###:::.. ###:::###:
                               ###::.        ###::.  ###::.###::.........###::...###:: ###:::..###:  ###::###:::.. ###:::..###:
                               ###::.        ###::.  ###::.###::.#####   #########::::.###########:: #######:::..  ###########::
                               ###::.        ###::.  ###::.###::. :###:: ###:::::###...###########::.###::###:..   ###########::.
                               ###::.        ###::.  ###::.###::.  ###::.###::...###:: ###:::::###::.###::.###:    ###:::::###::.
                               ###########    #########:::. ##########::.##########:::.###::...###::.###::. ###:   ###::...###::.
                               ###########::   #######:::..  ########:::.#########:::..###::.  ###::.###::.  ###:  ###::.  ###::.
                                ::::::::::::.   ::::::::..    :::::::::.. ::::::::::..  ::::.   ::::. ::::.   ::::  ::::.   ::::.
                                  ...........     .......       ........    .........     ...     ...   ...     ...   ...     ...

                                        ########    ###     ###   #########     ###########   #########     ###########
                                       ##########:  ###::  ###::: ##########:   ###########:: ##########:   ###########::
                                      ###:::::::::: ###::.###:::..###:::::###:   :::###::::::.###:::::###:   :::###::::::.
                                      ###::.........###::###:::.. ###::...###::    .###::.....###::...###::    .###::.....
                                       #########    #######:::..  ##########:::.    ###::.    ##########:::.    ###::.
                                        ::::::###:  ###::###:..   #######:::::..    ###::.    #########:::..    ###::.
                                          ....###:: ###::.###:    ###::###:....     ###::.    ###::::::::..     ###::.
                                      ##########:::.###::. ###:   ###::.###:    ###########   ###::.......      ###::.
                                       ########:::..###::.  ###:  ###::. ###:   ###########:: ###::.            ###::.
                                        :::::::::..  ::::.   ::::  ::::.  ::::   ::::::::::::. ::::.             ::::.
                                          ........     ...     ...   ...    ...    ...........   ...               ...

                                                         |     .       |       .       |       .     |
                                                         .     |       .       |       .       |     .
                                                                               .
                                                                              /#\
                                                                             /###\
                                                                            /#####\
                                                                            \#####/
                                                                             \###/
                                                                               V
                                                                          \    |    /
                                                                           \\  |  //
                                                                        ____\\_|_//____
                                                        ____..---====#####################====---..____
                                                   _.--==###########======~~~~~~~~~~~======###########==--._
                                                 .-==########====~~~~~    .---===---.    ~~~~~====########==-.
                                                  (########====~~~   .--==(###===###)==--.   ~~~====########)
                                                   '==########====~~~ '--===#######===--' ~~~====########=='
                                                       '--==##########======~~~~~~~======##########==--'
                                                           '---====#########################====---'
                                                             '--------===================--------'
                                                                   ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~

                                                              //  LUGBAKA SKRIPT  //  LOCAL AI  //
LUGBAKA160
  elif ((10#$columns >= 120)); then
    cat <<'LUGBAKA120'


      ###           ###     ###     ########    #########        #####      ###     ###      #####
      ###::         ###::   ###::  ##########:  ##########:     #######:    ###::  ###:::   #######:
      ###::.        ###::.  ###::.###:::::::::: ###:::::###:   ###:::###:   ###::.###:::.. ###:::###:
      ###::.        ###::.  ###::.###::.........###::...###:: ###:::..###:  ###::###:::.. ###:::..###:
      ###::.        ###::.  ###::.###::.#####   #########::::.###########:: #######:::..  ###########::
      ###::.        ###::.  ###::.###::. :###:: ###:::::###...###########::.###::###:..   ###########::.
      ###::.        ###::.  ###::.###::.  ###::.###::...###:: ###:::::###::.###::.###:    ###:::::###::.
      ###########    #########:::. ##########::.##########:::.###::...###::.###::. ###:   ###::...###::.
      ###########::   #######:::..  ########:::.#########:::..###::.  ###::.###::.  ###:  ###::.  ###::.
       ::::::::::::.   ::::::::..    :::::::::.. ::::::::::..  ::::.   ::::. ::::.   ::::  ::::.   ::::.
         ...........     .......       ........    .........     ...     ...   ...     ...   ...     ...

               ########    ###     ###   #########     ###########   #########     ###########
              ##########:  ###::  ###::: ##########:   ###########:: ##########:   ###########::
             ###:::::::::: ###::.###:::..###:::::###:   :::###::::::.###:::::###:   :::###::::::.
             ###::.........###::###:::.. ###::...###::    .###::.....###::...###::    .###::.....
              #########    #######:::..  ##########:::.    ###::.    ##########:::.    ###::.
               ::::::###:  ###::###:..   #######:::::..    ###::.    #########:::..    ###::.
                 ....###:: ###::.###:    ###::###:....     ###::.    ###::::::::..     ###::.
             ##########:::.###::. ###:   ###::.###:    ###########   ###::.......      ###::.
              ########:::..###::.  ###:  ###::. ###:   ###########:: ###::.            ###::.
               :::::::::..  ::::.   ::::  ::::.  ::::   ::::::::::::. ::::.             ::::.
                 ........     ...     ...   ...    ...    ...........   ...               ...

                                |     .       |       .       |       .     |
                                .     |       .       |       .       |     .
                                                      .
                                                     /#\
                                                    /###\
                                                   /#####\
                                                   \#####/
                                                    \###/
                                                      V
                                                 \    |    /
                                                  \\  |  //
                                               ____\\_|_//____
                               ____..---====#####################====---..____
                          _.--==###########======~~~~~~~~~~~======###########==--._
                        .-==########====~~~~~    .---===---.    ~~~~~====########==-.
                         (########====~~~   .--==(###===###)==--.   ~~~====########)
                          '==########====~~~ '--===#######===--' ~~~====########=='
                              '--==##########======~~~~~~~======##########==--'
                                  '---====#########################====---'
                                    '--------===================--------'
                                          ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~

                                     //  LUGBAKA SKRIPT  //  LOCAL AI  //
LUGBAKA120
  else
    cat <<'LUGBAKA80'

     ##        ##   ##    #####    ######     #####    ##   ##    #####
     ##:       ##:  ##:  #######   #######   #######   ##: ##::  #######
     ##:.      ##:. ##:. ##::::::  ##:::##:  ##:::##:  ##:##::.. ##:::##:
     ##:.      ##:. ##:. ##:...... ##:..##:. ##:..##:. ####::..  ##:..##:.
     ##:.      ##:. ##:. ##:####   ######::. #######:. ####:..   #######:.
     ##:.      ##:. ##:. ##:.:##:  ##:::##.. #######:. ##:##.    #######:.
     ##:.      ##:. ##:. ##:. ##:. ##:..##:  ##:::##:. ##:.##    ##:::##:.
     #######   #######:. #######:. #######:. ##:..##:. ##:. ##   ##:..##:.
     #######:   #####::.  #####::. ######::. ##:. ##:. ##:. ##:  ##:. ##:.
      :::::::.   :::::..   :::::..  ::::::..  ::.  ::.  ::.  ::.  ::.  ::.
       .......    .....     .....    ......    ..   ..   ..   ..   ..   ..

           #####    ##   ##   ######    #######   ######    #######
          #######   ##: ##::  #######   #######:  #######   #######:
          ##::::::  ##:##::.. ##:::##:   :###:::. ##:::##:   :###:::.
          ##:...... ####::..  ##:..##:.   ###:... ##:..##:.   ###:...
           #####    ####:..   ######::.   ###:.   #######:.   ###:.
            :::##   ##:##.    ##:##::..   ###:.   ######::.   ###:.
             ..##:  ##:.##    ##:.##..    ###:.   ##:::::..   ###:.
          #######:. ##:. ##   ##:. ##   #######   ##:.....    ###:.
           #####::. ##:. ##:  ##:. ##:  #######:  ##:.        ###:.
            :::::..  ::.  ::.  ::.  ::.  :::::::.  ::.         :::.
             .....    ..   ..   ..   ..   .......   ..          ...

                 |     .       |       .       |       .     |
                 .     |       .       |       .       |     .
                                       .
                                      /#\
                                     /###\
                                    /#####\
                                    \#####/
                                     \###/
                                       V
                                  \    |    /
                                   \\  |  //
                                ____\\_|_//____
                ____..---====#####################====---..____
           _.--==###########======~~~~~~~~~~~======###########==--._
         .-==########====~~~~~    .---===---.    ~~~~~====########==-.
          (########====~~~   .--==(###===###)==--.   ~~~====########)
           '==########====~~~ '--===#######===--' ~~~====########=='
               '--==##########======~~~~~~~======##########==--'
                   '---====#########################====---'
                     '--------===================--------'
                           ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~

                      //  LUGBAKA SKRIPT  //  LOCAL AI  //
LUGBAKA80
  fi
  printf '\n  LUGBAKA SKRIPT  //  BRODYAGA  //  Ubuntu 26.10\n\n'
  [[ ! -t 1 || -n "${NO_COLOR:-}" ]] || printf '\033[0m'
}

usage() {
  cat <<'HELP'
Запуск: bash lugbaka.sh [команда] [параметры]

Без параметров: зависимости + Docker/Compose + WebUI/Ollama + Kimi + две модели.
  install              Установить и дождаться готовности (по умолчанию)
  prepare              Только установить системные зависимости
  status | logs | down Состояние, логи или остановка; модели и чаты сохраняются
  pull                 Скачать/докачать обе модели
  check                Проверить HTTP и наличие обеих моделей
  gpu-check            Проверить драйвер, CUDA и GPU внутри Docker
  kimi [ПАПКА]         Открыть Kimi Code с локальной моделью
  banner               Только ASCII-заставка

  --gpu | --cpu        Режим; без флага NVIDIA определяется автоматически
  --light              Qwen 3 4B + Qwen 3 VL 4B вместо пары 8B
  --skip-models        Проверить установку без скачивания весов моделей
  --skip-kimi          Не устанавливать терминальный Kimi Code
  --port N             Порт WebUI (по умолчанию 3000)
  --ollama-port N      Локальный порт Ollama (по умолчанию 11434)
  --bind IPv4          Адрес WebUI (по умолчанию сетевой IPv4 этой машины)
  --subnet CIDR        Свободная приватная /24–/28 подсеть для этого стека
  --project NAME       Отдельное имя Docker Compose (по умолчанию lugbaka)
  --directory PATH     Папка репозитория; при отсутствии скачивается с GitHub
  --docker-context N   Явный Docker context (по умолчанию default)
  --no-system-changes Проверить установленный Docker без изменения пакетов ОС
  --qa-id NAME         Изолированная временная проверка с ограничением ресурсов

GPU: драйвер >=550; для CUDA 13.x и RTX 50xx нужен драйвер >=580.
Драйвер, CUDA Toolkit и перезагрузка ОС автоматически не выполняются.
HELP
}

need_value() { [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || die "Для $1 нужно значение."; }
KIMI_PROJECT=""
while (($#)); do
  case "$1" in
    install|prepare|status|logs|down|pull|check|gpu-check|banner) ACTION="$1"; shift ;;
    kimi) ACTION=kimi; shift; if (($#)) && [[ "$1" != --* ]]; then KIMI_PROJECT="$1"; shift; fi ;;
    --gpu|--cpu) MODE="${1#--}"; shift ;;
    --no-system-changes) NO_SYSTEM_CHANGES=1; shift ;;
    --qa-id) need_value "$@"; QA_ID="$2"; shift 2 ;;
    --light) LIGHT=1; shift ;;
    --skip-models) SKIP_MODELS=1; shift ;;
    --skip-kimi) SKIP_KIMI=1; shift ;;
    --port) need_value "$@"; WEB_PORT="$2"; shift 2 ;;
    --ollama-port) need_value "$@"; OLLAMA_PORT_ARG="$2"; shift 2 ;;
    --bind) need_value "$@"; BIND_ARG="$2"; shift 2 ;;
    --subnet) need_value "$@"; SUBNET_ARG="$2"; shift 2 ;;
    --project) need_value "$@"; PROJECT="$2"; shift 2 ;;
    --directory) need_value "$@"; ROOT="$2"; shift 2 ;;
    --docker-context) need_value "$@"; DOCKER_CONTEXT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "Неизвестный параметр: $1. См. --help." ;;
  esac
done
[[ -z "$PROJECT" || "$PROJECT" =~ ^[a-z0-9][a-z0-9_-]*$ ]] || die 'Недопустимое имя --project.'
for p in "$WEB_PORT" "$OLLAMA_PORT_ARG"; do
  [[ -z "$p" ]] || { [[ "$p" =~ ^[0-9]{1,5}$ ]] && ((10#$p > 0 && 10#$p <= 65535)); } || die 'Порт должен быть от 1 до 65535.'
done
banner
[[ "$ACTION" != banner ]] || exit 0

root_access() {
  if ((EUID != 0)) && ((${#AS_ROOT[@]} == 0)); then
    command -v sudo >/dev/null || die 'Для установки зависимостей нужен root или sudo.'
    # sudo reads a password directly from the terminal; never through this script.
    sudo -v
    AS_ROOT=(sudo -n)
  fi
}
apt_sources() {
  local suite arch mirror security source
  root_access
  ubuntu
  suite="${UBUNTU_CODENAME:-$VERSION_CODENAME}"
  arch="$(dpkg --print-architecture)"
  if [[ -z "$APT_WORK" ]]; then
    APT_WORK="$("${AS_ROOT[@]}" mktemp -d /var/tmp/lugbaka-apt.XXXXXXXX)"
    "${AS_ROOT[@]}" chmod 0755 "$APT_WORK"
    "${AS_ROOT[@]}" install -d -m 0755 "$APT_WORK/sources" "$APT_WORK/lists"
    APT_OPTIONS=(-o Dir::Etc::sourcelist=/dev/null -o "Dir::Etc::sourceparts=$APT_WORK/sources"
      -o "Dir::State::lists=$APT_WORK/lists" -o Dir::Cache::pkgcache= -o Dir::Cache::srcpkgcache=
      -o APT::Update::Error-Mode=any -o APT::Get::AllowUnauthenticated=false
      -o Acquire::AllowInsecureRepositories=false -o Acquire::AllowDowngradeToInsecureRepositories=false)
    say 'APT: отдельные подписанные источники Ubuntu/Docker/NVIDIA; системные источники сохранены'
  fi
  [[ -r /usr/share/keyrings/ubuntu-archive-keyring.gpg ]] || die 'Отсутствует штатный ключ ubuntu-archive-keyring.'
  case "$arch" in
    amd64|i386) mirror=http://archive.ubuntu.com/ubuntu; security=http://security.ubuntu.com/ubuntu ;;
    *) mirror=http://ports.ubuntu.com/ubuntu-ports; security="$mirror" ;;
  esac
  printf 'Types: deb\nURIs: %s\nSuites: %s %s-updates\nComponents: main restricted universe multiverse\nArchitectures: %s\nSigned-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg\n\nTypes: deb\nURIs: %s\nSuites: %s-security\nComponents: main restricted universe multiverse\nArchitectures: %s\nSigned-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg\n' \
    "$mirror" "$suite" "$suite" "$arch" "$security" "$suite" "$arch" |
    "${AS_ROOT[@]}" tee "$APT_WORK/sources/ubuntu.sources" >/dev/null
  # Only add sources created and validated by this invocation, never host PPAs.
  for source in "${INSTALLER_APT_SOURCES[@]}"; do
    "${AS_ROOT[@]}" cp -- "$source" "$APT_WORK/sources/"
  done
  "${AS_ROOT[@]}" chmod 0644 "$APT_WORK/sources/"*
}
INSTALLER_APT_SOURCES=()
apt_install() {
  [[ -n "$APT_WORK" ]] || apt_update
  root_access
  "${AS_ROOT[@]}" env DEBIAN_FRONTEND=noninteractive apt-get "${APT_OPTIONS[@]}" install -y --no-install-recommends "$@"
}
apt_update() { apt_sources; "${AS_ROOT[@]}" apt-get "${APT_OPTIONS[@]}" update; }
https() { curl --proto '=https' --tlsv1.2 --retry 3 --connect-timeout 15 -fsSL "$@"; }

ubuntu() {
  [[ "$(uname -s)" == Linux && -r /etc/os-release ]] || die 'Этот установщик предназначен для Ubuntu Linux.'
  # /etc/os-release is an OS-owned file, never a project .env.
  # shellcheck disable=SC1091
  . /etc/os-release
  [[ "$ID" == ubuntu ]] || die "Ожидается Ubuntu, обнаружено $ID."
  case "$VERSION_ID" in 24.04|26.04|26.10) ;; *) die "Непроверенная Ubuntu $VERSION_ID. Нужна 24.04, 26.04 или 26.10." ;; esac
  say "$PRETTY_NAME / $(dpkg --print-architecture)"
}

docker_repository() {
  local suite arch source_text
  suite="${UBUNTU_CODENAME:-$VERSION_CODENAME}"
  arch="$(dpkg --print-architecture)"
  https "https://download.docker.com/linux/ubuntu/dists/$suite/Release" -o /dev/null
  root_access
  "${AS_ROOT[@]}" install -d -m 0755 /etc/apt/keyrings
  https https://download.docker.com/linux/ubuntu/gpg | "${AS_ROOT[@]}" tee /etc/apt/keyrings/lugbaka-docker.asc >/dev/null
  "${AS_ROOT[@]}" chmod 0644 /etc/apt/keyrings/lugbaka-docker.asc
  source_text="$(printf 'Types: deb\nURIs: https://download.docker.com/linux/ubuntu\nSuites: %s\nComponents: stable\nArchitectures: %s\nSigned-By: /etc/apt/keyrings/lugbaka-docker.asc\n' "$suite" "$arch")"
  if [[ -e /etc/apt/sources.list.d/lugbaka-docker.sources ]]; then
    [[ "$(cat /etc/apt/sources.list.d/lugbaka-docker.sources)" == "$source_text" ]] || die 'Существующий lugbaka-docker.sources отличается; автоматически не заменяю.'
  else
    printf '%s\n' "$source_text" | "${AS_ROOT[@]}" tee /etc/apt/sources.list.d/lugbaka-docker.sources >/dev/null
  fi
  INSTALLER_APT_SOURCES+=(/etc/apt/sources.list.d/lugbaka-docker.sources)
  apt_update
}

install_dependencies() {
  local package conflict
  ubuntu
  local missing=()
  for package in curl git iproute2 ca-certificates gnupg python3; do
    dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q '^install ok installed$' || missing+=("$package")
  done
  if ((${#missing[@]})); then apt_update; apt_install "${missing[@]}"; fi
  if ! command -v docker >/dev/null; then
    [[ "$DOCKER_CONTEXT" == default ]] || die 'Для удалённого context Docker CLI должен быть уже установлен.'
    # Never remove an existing engine/container runtime to make installation pass.
    for conflict in docker.io docker-compose docker-compose-v2 podman-docker containerd runc; do
      if dpkg-query -W -f='${Status}' "$conflict" 2>/dev/null | grep -q '^install ok installed$'; then
        die "Установлен $conflict. Автоматическая замена существующего runtime запрещена."
      fi
    done
    docker_repository
    apt_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    if [[ -d /run/systemd/system ]]; then "${AS_ROOT[@]}" systemctl enable --now docker; fi
  elif ! docker --context "$DOCKER_CONTEXT" compose version >/dev/null 2>&1; then
    if dpkg-query -W -f='${Status}' docker.io 2>/dev/null | grep -q '^install ok installed$'; then
      apt_install docker-compose-v2
    else
      docker_repository
      apt_install docker-compose-plugin
    fi
  fi
  say 'Системные зависимости установлены'
  docker --context "$DOCKER_CONTEXT" --version
  docker --context "$DOCKER_CONTEXT" compose version
}

docker_access() {
  DOCKER=(docker --context "$DOCKER_CONTEXT")
  if ! "${DOCKER[@]}" info >/dev/null 2>&1; then
    if [[ "$DOCKER_CONTEXT" == default ]] && ((EUID != 0)); then
      root_access
      DOCKER=(sudo -n docker --context default)
      "${DOCKER[@]}" info >/dev/null || die 'Docker недоступен и с правами sudo.'
    else
      die 'Docker Engine недоступен. Проверьте его состояние и права; группы и чужой Engine скрипт не меняет.'
    fi
  fi
}

driver_check() {
  local row name version cap major cuda
  command -v nvidia-smi >/dev/null || die 'nvidia-smi отсутствует. Установите рекомендуемый драйвер Ubuntu, перезагрузитесь и повторите запуск; либо используйте --cpu.'
  row="$(nvidia-smi --query-gpu=name,driver_version,compute_cap --format=csv,noheader | head -1)"
  IFS=, read -r name version cap <<<"$row"
  version="${version// /}"; cap="${cap// /}"
  major="${version%%.*}"
  [[ "$major" =~ ^[0-9]+$ ]] || die 'Не удалось определить версию драйвера NVIDIA.'
  cuda="$(nvidia-smi | sed -n 's/.*CUDA Version: *\([0-9.]*\).*/\1/p' | head -1)"
  say "GPU: $name | драйвер $version | CUDA API ${cuda:-не определена} | compute $cap"
  ((major >= 550)) || die "Драйвер $version слишком стар для Ollama. Нужен >=550; для CUDA 13.x — >=580."
  if [[ "$cuda" == 13.* || "$cap" == 12.* ]]; then
    ((major >= 580)) || die "Для CUDA 13.x / RTX 50xx нужен драйвер >=580, обнаружен $version."
  fi
  case "$cap" in 5.*|6.*) ((major >= 570)) || die 'Для GPU compute 5.x–6.x Ollama требует драйвер >=570.' ;; esac
  awk -v cap="$cap" 'BEGIN {exit !(cap+0 >= 5)}' || die 'Ollama требует compute capability >=5.0.'
  printf 'Полный CUDA Toolkit на хосте не нужен: CUDA runtime входит в образ Ollama.\n'
}

setup_gpu() {
  driver_check
  # Use native Docker CDI: no daemon reconfiguration or restart of running services.
  if "${DOCKER[@]}" info --format '{{json .Runtimes}}' | grep -q '"nvidia"'; then
    GPU_STYLE=nvidia
    return
  fi
  if compgen -G '/etc/cdi/*nvidia*' >/dev/null || compgen -G '/var/run/cdi/*nvidia*' >/dev/null; then
    GPU_STYLE=cdi
    return
  fi
  [[ "$NO_SYSTEM_CHANGES" != 1 ]] || die 'NVIDIA Container Toolkit/CDI не настроен; системные изменения отключены для этой проверки.'
  local engine_version
  engine_version="$("${DOCKER[@]}" version --format '{{.Server.Version}}')"
  dpkg --compare-versions "$engine_version" ge 28.3.0 || die 'Для установки GPU без перезапуска Docker нужен Docker >=28.3 с CDI. Обновите Engine в согласованное время или используйте --cpu.'
  if ! command -v nvidia-ctk >/dev/null; then
    root_access
    https https://nvidia.github.io/libnvidia-container/gpgkey |
      "${AS_ROOT[@]}" gpg --dearmor --batch --yes -o /usr/share/keyrings/lugbaka-nvidia.gpg
    "${AS_ROOT[@]}" chmod 0644 /usr/share/keyrings/lugbaka-nvidia.gpg
    https https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list |
      sed 's#deb https://#deb [signed-by=/usr/share/keyrings/lugbaka-nvidia.gpg] https://#g' |
      "${AS_ROOT[@]}" tee /etc/apt/sources.list.d/lugbaka-nvidia.list >/dev/null
    INSTALLER_APT_SOURCES+=(/etc/apt/sources.list.d/lugbaka-nvidia.list)
    apt_update
    apt_install nvidia-container-toolkit
  fi
  # The toolkit's refresh service can already have generated this spec.
  if compgen -G '/etc/cdi/*nvidia*' >/dev/null || compgen -G '/var/run/cdi/*nvidia*' >/dev/null; then
    GPU_STYLE=cdi
    return
  fi
  root_access
  "${AS_ROOT[@]}" install -d -m 0755 /etc/cdi
  "${AS_ROOT[@]}" nvidia-ctk cdi generate --output=/etc/cdi/lugbaka-nvidia.yaml
  GPU_STYLE=cdi
}

read_env() {
  python3 - "$RUNTIME_DIR/settings.json" "$1" <<'PY'
import json, sys
keys = {'WEBUI_BIND': 'webui_bind', 'WEBUI_PORT': 'webui_port', 'OLLAMA_PORT': 'ollama_port',
        'QWEN_MODEL': 'qwen_model', 'VLM_MODEL': 'vlm_model', 'PROJECT': 'project'}
print(json.load(open(sys.argv[1]))[keys[sys.argv[2]]])
PY
}
lan_ip() { ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") {print $(i+1);exit}}'; }
compose() { "${DOCKER[@]}" compose --project-directory "$ROOT" --env-file /dev/null --project-name "$PROJECT" -f "$CONFIG" "$@"; }

configure() {
  local old_mode project_dir default_bind
  command -v python3 >/dev/null || die 'Нужен python3. Выполните bash lugbaka.sh prepare.'
  RUNTIME_DIR="$ROOT/.runtime/lugbaka"
  if [[ -n "$QA_ID" ]]; then
    [[ "$QA_ID" =~ ^[a-z0-9][a-z0-9_-]*$ ]] || die 'Недопустимый QA ID.'
    RUNTIME_DIR="$ROOT/.runtime/lugbaka-qa/$QA_ID"
  fi
  mkdir -p "$RUNTIME_DIR"
  if [[ "$MODE" == auto && -f "$RUNTIME_DIR/mode" ]]; then
    old_mode="$(cat "$RUNTIME_DIR/mode")"
    case "$old_mode" in cpu|gpu) MODE="$old_mode" ;; *) die 'Повреждено сохранённое значение режима.' ;; esac
  fi
  if [[ "$MODE" == auto ]]; then
    if command -v nvidia-smi >/dev/null; then
      nvidia-smi -L >/dev/null 2>&1 || die 'NVIDIA обнаружена, но nvidia-smi не работает. Исправьте драйвер либо явно выберите --cpu.'
      MODE=gpu
    elif grep -lq '^0x10de$' /sys/bus/pci/devices/*/vendor 2>/dev/null; then
      die 'Найдена NVIDIA без nvidia-smi. Установите рекомендуемый драйвер Ubuntu и перезагрузитесь; либо явно выберите --cpu.'
    else MODE=cpu
    fi
  fi
  GPU_STYLE=none
  if [[ "$MODE" == gpu ]]; then
    if [[ "$ACTION" == install ]]; then setup_gpu
    elif [[ -f "$RUNTIME_DIR/gpu-style" ]]; then
      GPU_STYLE="$(cat "$RUNTIME_DIR/gpu-style")"
      case "$GPU_STYLE" in nvidia|cdi) ;; *) die 'Повреждено сохранённое значение GPU.' ;; esac
    else die 'Сначала выполните install --gpu.'
    fi
  fi
  project_dir="$ROOT"
  if [[ "$ACTION" == kimi && -n "$KIMI_PROJECT" ]]; then project_dir="$(cd -- "$KIMI_PROJECT" && pwd -P)"; fi
  default_bind="$BIND_ARG"
  if [[ -z "$default_bind" || "$default_bind" == 0.0.0.0 ]]; then default_bind="$(lan_ip || :)"; fi
  python3 - "$ROOT" "$RUNTIME_DIR" "$project_dir" "$GPU_STYLE" "$LIGHT" "$WEB_PORT" "$OLLAMA_PORT_ARG" "$BIND_ARG" "$default_bind" "$SUBNET_ARG" "$PROJECT" "$QA_ID" <<'PY'
import ipaddress, json, os, pathlib, re, shlex, socket, sys, time
root = pathlib.Path(sys.argv[1])
runtime = pathlib.Path(sys.argv[2])
workspace, gpu, light, web_port, ollama_port, bind, detected_bind, subnet, project, qa_id = sys.argv[3:]
settings_path = runtime / 'settings.json'
data = dict(webui_bind=detected_bind, webui_port=3000, ollama_port=11434, webui_name='БРОДЯГА',
            qwen_model='qwen3:8b', vlm_model='qwen3-vl:8b', project='lugbaka', subnet='',
            ollama_image='ollama/ollama:0.32.15', webui_image='ghcr.io/open-webui/open-webui:v0.11.0',
            enable_signup='true', webui_auth='true', ollama_context_length='16384', ollama_keep_alive='0',
            ollama_max_loaded_models='1', ollama_num_parallel='1', ollama_flash_attention='1', ollama_kv_cache_type='q8_0')
legacy_keys = {'WEBUI_BIND':'webui_bind', 'WEBUI_PORT':'webui_port', 'OLLAMA_PORT':'ollama_port',
               'WEBUI_NAME':'webui_name', 'QWEN_MODEL':'qwen_model', 'VLM_MODEL':'vlm_model',
               'OLLAMA_IMAGE':'ollama_image', 'OPEN_WEBUI_IMAGE':'webui_image',
               'ENABLE_SIGNUP':'enable_signup', 'WEBUI_AUTH':'webui_auth', 'LUGBAKA_SUBNET':'subnet',
               **{key: key.lower() for key in ('OLLAMA_CONTEXT_LENGTH','OLLAMA_KEEP_ALIVE','OLLAMA_MAX_LOADED_MODELS','OLLAMA_NUM_PARALLEL','OLLAMA_FLASH_ATTENTION','OLLAMA_KV_CACHE_TYPE')}}
# Read repository defaults and migrate known old settings as data, never as shell code.
for filename in ('.env.example', '.env'):
    if (root / filename).is_file():
        for line in (root / filename).read_text().splitlines():
            key, sep, value = line.partition('=')
            if sep and key in legacy_keys and not (filename == '.env.example' and key.lower().startswith(('ollama_context_', 'ollama_keep_', 'ollama_max_', 'ollama_num_', 'ollama_flash_', 'ollama_kv_'))):
                value = value.strip()
                if value.startswith(('"', "'")):
                    value = ' '.join(shlex.split(value, comments=True))
                else:
                    value = re.split(r'\s+#', value, maxsplit=1)[0].strip()
                data[legacy_keys[key]] = value
if settings_path.exists(): data.update(json.loads(settings_path.read_text()))
if not settings_path.exists() and not (root / '.env').exists(): data['webui_bind'] = detected_bind
if qa_id:
    expected_project = 'lugbaka-qa-' + qa_id
    if project and project != expected_project: raise SystemExit('Для QA используется отдельный проект: ' + expected_project)
    data['project'] = expected_project
    project = expected_project
    if not settings_path.exists():
        data['webui_bind'] = '127.0.0.1'
        allocated = []
        for key in ('webui_port', 'ollama_port'):
            sock = socket.socket()
            sock.bind(('127.0.0.1', 0))
            data[key] = sock.getsockname()[1]
            allocated.append(sock)
        for sock in allocated: sock.close()
elif str(data['project']).startswith('lugbaka-qa-') or project.startswith('lugbaka-qa-'):
    raise SystemExit('Имя lugbaka-qa- зарезервировано: укажите --qa-id для временной проверки.')
for key, value in [('webui_port', web_port), ('ollama_port', ollama_port), ('webui_bind', bind), ('subnet', subnet), ('project', project)]:
    if value: data[key] = value
if light == '1': data.update(qwen_model='qwen3:4b', vlm_model='qwen3-vl:4b')
try:
    ipaddress.IPv4Address(data['webui_bind'])
    for key in ('webui_port', 'ollama_port'):
        if not re.fullmatch(r'[0-9]{1,5}', str(data[key])) or not 1 <= int(data[key]) <= 65535: raise ValueError('Порт должен быть от 1 до 65535.')
        data[key] = int(data[key])
    if data['webui_port'] == data['ollama_port']: raise ValueError('Порты WebUI и Ollama должны различаться.')
    if not re.fullmatch(r'[a-z0-9][a-z0-9_-]*', data['project']): raise ValueError('Недопустимое имя проекта.')
    for key in ('qwen_model', 'vlm_model'):
        if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._/-]*(?::[A-Za-z0-9][A-Za-z0-9._-]*)?', data[key]): raise ValueError('Недопустимое имя модели.')
    for key in ('ollama_image', 'webui_image'):
        if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._/:@-]*', data[key]): raise ValueError('Недопустимое имя образа.')
    for key in ('enable_signup', 'webui_auth'):
        value = str(data[key]).lower()
        if value not in ('true', 'false'): raise ValueError(key + ' должен быть true или false.')
        data[key] = value
    if (root / '.env').exists():
        for line in (root / '.env').read_text().splitlines():
            if line.startswith('OLLAMA_BIND=') and line.partition('=')[2].strip(" '\"") != '127.0.0.1': raise ValueError('OLLAMA_BIND должен оставаться 127.0.0.1.')
    if data['subnet']:
        network = ipaddress.IPv4Network(data['subnet'], strict=True)
        allowed = [ipaddress.IPv4Network(x) for x in ('10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16')]
        if not 24 <= network.prefixlen <= 28 or not any(network.subnet_of(x) for x in allowed): raise ValueError('Нужна приватная подсеть /24–/28.')
    if qa_id and not re.fullmatch(r'[a-zA-Z0-9_-]+', qa_id): raise ValueError('Недопустимый QA ID.')
except (ValueError, TypeError) as error:
    raise SystemExit('ОШИБКА конфигурации: ' + str(error))
def volume(source, target, readonly=False):
    return dict(type='bind', source=str(source), target=target, read_only=readonly, bind=dict(create_host_path=False))
def literal_compose(value):
    if isinstance(value, str): return value.replace('$', '$$')
    if isinstance(value, list): return [literal_compose(item) for item in value]
    if isinstance(value, dict): return {key: literal_compose(item) for key, item in value.items()}
    return value
created = data.get('qa_created', int(time.time())) if data.get('qa_id') == qa_id else int(time.time())
labels = {'com.facex.qa.temporary':str(bool(qa_id)).lower(), 'com.facex.qa.owner':qa_id or 'lugbaka',
          'com.facex.qa.kind':'container', 'com.facex.qa.created_at':str(created), 'com.facex.qa.expires_at':str(created+1800)}
restart = 'no' if qa_id else 'unless-stopped'
ollama = dict(image=data['ollama_image'], restart=restart, cpus=1 if qa_id else 4, mem_limit='768m' if qa_id else '12g', labels=labels,
    ports=[dict(target=11434, published=str(data['ollama_port']), host_ip='127.0.0.1', protocol='tcp')],
    environment={key:str(data[key.lower()]) for key in ('OLLAMA_CONTEXT_LENGTH','OLLAMA_KEEP_ALIVE','OLLAMA_MAX_LOADED_MODELS','OLLAMA_NUM_PARALLEL','OLLAMA_FLASH_ATTENTION','OLLAMA_KV_CACHE_TYPE')},
    volumes=['ollama-data:/root/.ollama'], healthcheck=dict(test=['CMD','ollama','list'], interval='10s', timeout='5s', retries=12, start_period='15s'))
if gpu == 'nvidia':
    ollama['runtime'] = 'nvidia'
    ollama['deploy'] = dict(resources=dict(reservations=dict(devices=[dict(driver='nvidia', count='all', capabilities=['gpu'])])))
elif gpu == 'cdi': ollama['devices'] = ['nvidia.com/gpu=all']
webui = dict(image=data['webui_image'], restart=restart, cpus=1 if qa_id else 2, mem_limit='2g' if qa_id else '4g', labels=labels,
    depends_on={'ollama':dict(condition='service_healthy')},
    ports=[dict(target=8080, published=str(data['webui_port']), host_ip=data['webui_bind'], protocol='tcp')],
    environment=dict(OLLAMA_BASE_URL='http://ollama:11434', WEBUI_NAME=data['webui_name'], ENABLE_SIGNUP=data['enable_signup'], WEBUI_AUTH=data['webui_auth'], RAG_EMBEDDING_MODEL_AUTO_UPDATE='false', WHISPER_MODEL_AUTO_UPDATE='false'),
    volumes=['open-webui-data:/app/backend/data'],
    healthcheck=dict(test=['CMD','python','-c',"import json,urllib.request; assert json.load(urllib.request.urlopen('http://localhost:8080/health',timeout=4))['status'] is True"], interval='10s', timeout='5s', start_period='120s', retries=36))
public_ip = data['webui_bind'] if data['webui_bind'] != '0.0.0.0' else (detected_bind or '127.0.0.1')
port_suffix = '' if data['webui_port'] == 80 else ':' + str(data['webui_port'])
origins = [f'http://{address}{port_suffix}' for address in dict.fromkeys((public_ip, '127.0.0.1', 'localhost'))]
webui['environment'].update(WEBUI_URL=origins[0], CORS_ALLOW_ORIGIN=';'.join(origins))
kimi = dict(profiles=['tools'], image='node:22.21.1-bookworm', init=True, cpus=1, mem_limit='1g', labels=labels,
    working_dir='/workspace', entrypoint=['bash','/lugbaka/kimi-entry.sh'], environment=dict(KIMI_CODE_HOME='/root/.kimi-code'),
    volumes=['kimi-tools:/opt/kimi','kimi-home:/root/.kimi-code','kimi-npm-cache:/root/.npm',volume(runtime,'/lugbaka',True),volume(workspace,'/workspace')])
doc = dict(services=dict(ollama=ollama, **{'open-webui':webui}, kimi=kimi), volumes={k:{} for k in ('ollama-data','open-webui-data','kimi-tools','kimi-home','kimi-npm-cache')})
if qa_id:
    # Disposable QA data stays inside this checkout; production volumes are untouched.
    for service in doc['services'].values():
        binds = []
        for item in service['volumes']:
            if isinstance(item, str):
                name, target = item.split(':', 1)
                directory = runtime / 'qa-data' / name
                directory.mkdir(parents=True, exist_ok=True)
                binds.append(volume(directory, target))
            else: binds.append(item)
        service['volumes'] = binds
    doc['volumes'] = {}
if data['subnet']: doc['networks'] = {'default':dict(ipam=dict(config=[dict(subnet=data['subnet'])]))}
data.update(qa_id=qa_id, qa_created=created)
for name, value in [('settings.json', data), ('compose.yaml', doc)]:
    if name == 'compose.yaml': value = literal_compose(value)
    target = runtime / name
    temporary = target.with_suffix(target.suffix + '.tmp')
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')
    os.chmod(temporary, 0o600)
    temporary.replace(target)
model = data['qwen_model']
(runtime / 'kimi.toml').write_text(f'''default_model = "ollama/{model}"
default_permission_mode = "manual"
telemetry = false
[providers.ollama]
type = "openai"
base_url = "http://ollama:11434/v1"
api_key = "ollama"
[models."ollama/{model}"]
provider = "ollama"
model = "{model}"
max_context_size = 16384
capabilities = ["thinking", "tool_use"]
''')
PY
  QWEN_MODEL="$(read_env QWEN_MODEL)"; VLM_MODEL="$(read_env VLM_MODEL)"; PROJECT="$(read_env PROJECT)"
  printf '%s\n' "$MODE" >"$RUNTIME_DIR/mode"
  printf '%s\n' "$GPU_STYLE" >"$RUNTIME_DIR/gpu-style"
  CONFIG="$RUNTIME_DIR/compose.yaml"
  cat >"$RUNTIME_DIR/kimi-entry.sh" <<'SH'
#!/usr/bin/env bash
set -Eeuo pipefail
version=2.5.2
if [[ "${1:-}" == install ]]; then
  mkdir -p /opt/kimi /root/.npm
  current="$(node -p 'require("/opt/kimi/node_modules/@moonshot-ai/kimi-code/package.json").version' 2>/dev/null || :)"
  if [[ "$current" != "$version" || -f /opt/kimi/.lugbaka-install-incomplete ]] || ! /opt/kimi/node_modules/.bin/kimi --version >/dev/null 2>&1; then
    touch /opt/kimi/.lugbaka-install-incomplete
    for attempt in 1 2 3; do
      printf '\nУстановка Kimi: попытка %s/3 (до 3 минут).\n' "$attempt"
      if timeout --kill-after=10s 180s npm install --prefix /opt/kimi --no-audit --no-fund \
        --cache /root/.npm --prefer-offline --update-notifier=false \
        --fetch-retries=1 --fetch-timeout=60000 --fetch-retry-factor=2 \
        --fetch-retry-mintimeout=2000 --fetch-retry-maxtimeout=5000 \
        "@moonshot-ai/kimi-code@$version" 2>&1 | tee /root/.npm/lugbaka-last-attempt.log; then
        /opt/kimi/node_modules/.bin/kimi --version >/dev/null
        rm -f /opt/kimi/.lugbaka-install-incomplete
        break
      else
        statuses=("${PIPESTATUS[@]}")
        rc="${statuses[0]}"
        if ((statuses[1] != 0)); then printf 'Не удалось сохранить журнал npm.\n' >&2; exit 1; fi
        case "$rc" in 130|137|143) exit "$rc" ;; esac
        if ((rc != 124)) && ! grep -Eq 'ETIMEDOUT|ECONNRESET|ECONNREFUSED|EAI_AGAIN|ENETUNREACH|ENOTFOUND' /root/.npm/lugbaka-last-attempt.log; then
          printf 'Установка Kimi прервана: ошибка npm, код %s.\n' "$rc" >&2
          exit "$rc"
        fi
        if ((attempt == 3)); then
          printf 'Kimi пока не установлен: исчерпаны повторы загрузки. Проверьте доступ контейнера к npm registry. Основной стек можно установить с --skip-kimi.\n' >&2
          exit "$rc"
        fi
        printf 'Сетевая ошибка загрузки; повтор через %s секунд. Кэш сохранён.\n' "$((attempt*5))" >&2
        sleep "$((attempt*5))"
      fi
    done
  fi
  cp /lugbaka/kimi.toml /root/.kimi-code/config.toml
  exec /opt/kimi/node_modules/.bin/kimi --version
fi
[[ -x /opt/kimi/node_modules/.bin/kimi ]] || { printf 'Сначала запустите установку lugbaka.sh.\n' >&2; exit 1; }
cp /lugbaka/kimi.toml /root/.kimi-code/config.toml
exec /opt/kimi/node_modules/.bin/kimi "$@"
SH
}

dc() { compose "$@"; }

control_command() {
  printf 'bash %q %q --directory %q --project %q --docker-context %q' "$SELF" "$1" "$ROOT" "$PROJECT" "$DOCKER_CONTEXT"
  if [[ -n "$QA_ID" ]]; then printf ' --qa-id %q' "$QA_ID"; fi
}

wait_http() {
  local url="$1" attempts=120 i
  for ((i=0; i<attempts; i++)); do
    if curl -fsS --connect-timeout 2 --max-time 5 "$url" >/dev/null 2>&1; then return; fi
    sleep 3
  done
  die "Сервис не ответил: $url. Посмотрите: $(control_command logs)"
}
pull_models() {
  local model
  for model in "$QWEN_MODEL" "$VLM_MODEL"; do
    if dc exec -T ollama ollama show "$model" >/dev/null 2>&1; then
      say "Модель $model уже установлена"
      continue
    fi
    say "Скачивание / докачка $model"
    dc exec -T ollama ollama pull "$model"
    dc exec -T ollama ollama show "$model" >/dev/null
  done
}
result() {
  local bind port
  bind="$(read_env WEBUI_BIND)"; port="$(read_env WEBUI_PORT)"
  [[ "$bind" != 0.0.0.0 ]] || bind="$(lan_ip)"
  printf '\n============================================================\n'
  printf '  БРОДЯГА готова: http://%s:%s\n' "$bind" "$port"
  printf '  Режим: %s | Docker context: %s | Проект: %s\n' "$MODE" "$DOCKER_CONTEXT" "$PROJECT"
  if ((SKIP_MODELS)); then printf '  Веса моделей пропущены (--skip-models).\n'; else printf '  Модели: %s + %s\n' "$QWEN_MODEL" "$VLM_MODEL"; fi
  printf '  Создайте первую учётную запись в браузере.\n'
  printf '  Остановка с сохранением данных: %s\n' "$(control_command down)"
  printf '============================================================\n'
}

if [[ "$ACTION" == install || "$ACTION" == prepare ]]; then
  if [[ "$NO_SYSTEM_CHANGES" == 1 ]]; then ubuntu; else install_dependencies; fi
fi
[[ "$ACTION" != prepare ]] || exit 0
docker_access
if [[ "$ACTION" == gpu-check ]]; then
  setup_gpu
  if [[ "$GPU_STYLE" == cdi ]]; then GPU_FLAGS=(--device nvidia.com/gpu=all); else GPU_FLAGS=(--runtime=nvidia --gpus all); fi
  "${DOCKER[@]}" run --rm "${GPU_FLAGS[@]}" --entrypoint nvidia-smi ollama/ollama:0.32.15 --query-gpu=name,driver_version --format=csv,noheader
  exit 0
fi
if [[ ! -f "$ROOT/compose.yaml" ]]; then
  [[ "$ROOT" != "$SCRIPT_DIR" ]] || ROOT="$SCRIPT_DIR/BRODYAGA"
  if [[ ! -e "$ROOT" ]]; then
    [[ "$ACTION" == install ]] || die 'Установка ещё не выполнена. Сначала запустите install.'
    git clone -- https://github.com/media314/BRODYAGA.git "$ROOT"
    git -C "$ROOT" checkout --detach "$UPSTREAM_SHA"
  fi
  [[ -f "$ROOT/compose.yaml" && -f "$ROOT/.env.example" ]] || die "В $ROOT нет файлов БРОДЯГИ. Укажите --directory с репозиторием."
  if [[ -d "$ROOT/.git" ]]; then
    repository_origin="$(git -C "$ROOT" remote get-url origin)"
    case "${repository_origin,,}" in
      https://github.com/media314/brodyaga|https://github.com/media314/brodyaga.git|git@github.com:media314/brodyaga.git) ;;
      *) die 'Папка BRODYAGA принадлежит другому репозиторию; её содержимое сохранено.' ;;
    esac
  fi
  if ! cmp -s -- "$SELF" "$ROOT/lugbaka.sh"; then
    mkdir -p "$ROOT/.runtime/lugbaka"
    if [[ -f "$ROOT/lugbaka.sh" ]]; then
      previous_installer="$(mktemp "$ROOT/.runtime/lugbaka/installer-previous.XXXXXX")"
      cp -- "$ROOT/lugbaka.sh" "$previous_installer"
    fi
    next_installer="$(mktemp "$ROOT/.runtime/lugbaka/installer-next.XXXXXX")"
    cp -- "$SELF" "$next_installer"
    chmod 0755 "$next_installer"
    mv -- "$next_installer" "$ROOT/lugbaka.sh"
  fi
fi
ROOT="$(cd -- "$ROOT" && pwd)"
configure
dc config --quiet
WEBUI_URL="http://$(read_env WEBUI_BIND):$(read_env WEBUI_PORT)"
[[ "$(read_env WEBUI_BIND)" != 0.0.0.0 ]] || WEBUI_URL="http://127.0.0.1:$(read_env WEBUI_PORT)"
case "$ACTION" in
  install)
    say 'Загрузка образов и запуск Ollama / Open WebUI'
    dc pull --policy missing ollama open-webui
    if [[ "$MODE" == gpu ]]; then
      say 'Проверка видимости NVIDIA внутри контейнера'
      dc run --rm --no-deps -T --entrypoint nvidia-smi ollama --query-gpu=name,driver_version --format=csv,noheader
    fi
    dc up -d --wait --wait-timeout 600 ollama open-webui
    wait_http "http://127.0.0.1:$(read_env OLLAMA_PORT)/api/tags"
    if ((SKIP_KIMI == 0)); then
      say 'Установка Kimi Code 2.5.2 в отдельный контейнер'
      printf 'Журнал установки Kimi: %s/kimi-install.log\n' "$RUNTIME_DIR"
      dc run --rm --no-deps -T kimi install 2>&1 | tee "$RUNTIME_DIR/kimi-install.log"
    fi
    if ((SKIP_MODELS == 0)); then pull_models; fi
    wait_http "$WEBUI_URL/health"
    result
    ;;
  pull) pull_models ;;
  check)
    wait_http "$WEBUI_URL/health"
    wait_http "http://127.0.0.1:$(read_env OLLAMA_PORT)/api/tags"
    dc exec -T ollama ollama show "$QWEN_MODEL" >/dev/null
    dc exec -T ollama ollama show "$VLM_MODEL" >/dev/null
    say 'HTTP и обе модели проверены'
    ;;
  status) dc ps ;;
  logs) dc logs --tail 100 -f ollama open-webui ;;
  down) dc down; say 'Контейнеры остановлены. Модели, чаты и настройки сохранены.' ;;
  kimi) dc run --rm --no-deps kimi -m "ollama/$QWEN_MODEL" ;;
esac
