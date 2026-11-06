#!/usr/bin/env bash
# Also accept: sh lugbaka.sh (Ubuntu's /bin/sh is dash).
if [ -z "${BASH_VERSION:-}" ]; then exec bash "$0" "$@"; fi
set -Eeuo pipefail
umask 077

SELF="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/$(basename -- "${BASH_SOURCE[0]}")"
ROOT="$(dirname -- "$SELF")"
UPSTREAM_SHA=0a8c37804d7f65faf8da458e55f3d2705ba8e92c
ACTION=install
MODE=auto
LIGHT=0
SKIP_MODELS=0
SKIP_KIMI=0
PROJECT=lugbaka
WEB_PORT=""
OLLAMA_PORT_ARG=""
BIND_ARG=""
SUBNET_ARG=""
DOCKER_CONTEXT="${DOCKER_CONTEXT:-default}"
DOCKER=(docker --context "$DOCKER_CONTEXT")
AS_ROOT=()
CONFIG=""

say() { printf '\n==> %s\n' "$*"; }
die() { printf '\nОШИБКА: %s\n' "$*" >&2; exit 1; }
on_error() {
  local rc="$1" line="$2"
  printf '\nУстановка прервана (код %s, строка %s). Данные сохранены; повторите ту же команду.\n' "$rc" "$line" >&2
  exit "$rc"
}
trap 'on_error "$?" "$LINENO"' ERR

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

GPU: драйвер >=550; для CUDA 13.x и RTX 50xx нужен драйвер >=580.
Драйвер, CUDA Toolkit и перезагрузка ОС автоматически не выполняются.
HELP
}

need_value() { [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || die "Для $1 нужно значение."; }
KIMI_PROJECT="$PWD"
while (($#)); do
  case "$1" in
    install|prepare|status|logs|down|pull|check|gpu-check|banner) ACTION="$1"; shift ;;
    kimi) ACTION=kimi; shift; if (($#)) && [[ "$1" != --* ]]; then KIMI_PROJECT="$1"; shift; fi ;;
    --gpu|--cpu) MODE="${1#--}"; shift ;;
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
[[ "$PROJECT" =~ ^[a-z0-9][a-z0-9_-]*$ ]] || die 'Недопустимое имя --project.'
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
apt_install() { root_access; "${AS_ROOT[@]}" env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@"; }
apt_update() { root_access; "${AS_ROOT[@]}" apt-get update; }
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

install_dependencies() {
  local package suite arch conflict
  ubuntu
  local missing=()
  for package in curl git iproute2 ca-certificates gnupg; do
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
    suite="${UBUNTU_CODENAME:-$VERSION_CODENAME}"
    arch="$(dpkg --print-architecture)"
    https "https://download.docker.com/linux/ubuntu/dists/$suite/Release" -o /dev/null
    root_access
    "${AS_ROOT[@]}" install -d -m 0755 /etc/apt/keyrings
    https https://download.docker.com/linux/ubuntu/gpg | "${AS_ROOT[@]}" tee /etc/apt/keyrings/lugbaka-docker.asc >/dev/null
    "${AS_ROOT[@]}" chmod 0644 /etc/apt/keyrings/lugbaka-docker.asc
    local source_text
    source_text="$(printf 'Types: deb\nURIs: https://download.docker.com/linux/ubuntu\nSuites: %s\nComponents: stable\nArchitectures: %s\nSigned-By: /etc/apt/keyrings/lugbaka-docker.asc\n' "$suite" "$arch")"
    if [[ -e /etc/apt/sources.list.d/lugbaka-docker.sources ]]; then
      [[ "$(cat /etc/apt/sources.list.d/lugbaka-docker.sources)" == "$source_text" ]] || die 'Существующий lugbaka-docker.sources отличается; автоматически не заменяю.'
    else
      printf '%s\n' "$source_text" | "${AS_ROOT[@]}" tee /etc/apt/sources.list.d/lugbaka-docker.sources >/dev/null
    fi
    apt_update
    apt_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    if [[ -d /run/systemd/system ]]; then "${AS_ROOT[@]}" systemctl enable --now docker; fi
  elif ! docker --context "$DOCKER_CONTEXT" compose version >/dev/null 2>&1; then
    apt_install docker-compose-plugin
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
  [[ "${LUGBAKA_NO_SYSTEM_CHANGES:-0}" != 1 ]] || die 'NVIDIA Container Toolkit/CDI не настроен; системные изменения отключены для этой проверки.'
  local engine_version
  engine_version="$("${DOCKER[@]}" version --format '{{.Server.Version}}')"
  dpkg --compare-versions "$engine_version" ge 28.3.0 || die 'Для установки GPU без перезапуска Docker нужен Docker >=28.3 с CDI. Обновите Engine в согласованное время или используйте --cpu.'
  if ! command -v nvidia-ctk >/dev/null; then
    root_access
    https https://nvidia.github.io/libnvidia-container/gpgkey |
      "${AS_ROOT[@]}" gpg --dearmor --batch --yes -o /usr/share/keyrings/lugbaka-nvidia.gpg
    https https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list |
      sed 's#deb https://#deb [signed-by=/usr/share/keyrings/lugbaka-nvidia.gpg] https://#g' |
      "${AS_ROOT[@]}" tee /etc/apt/sources.list.d/lugbaka-nvidia.list >/dev/null
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

read_env() { awk -F= -v k="$1" '$1==k {sub(/^[^=]*=/, ""); print; exit}' "$ROOT/.env"; }
set_env() {
  local tmp
  tmp="$(mktemp "$ROOT/.runtime/lugbaka/env.XXXXXX")"
  awk -F= -v k="$1" -v v="$2" '$1==k {if (!found++) print k "=" v; next} {print} END {if (!found) print k "=" v}' "$ROOT/.env" >"$tmp"
  chmod 0600 "$tmp"; mv -- "$tmp" "$ROOT/.env"
}
lan_ip() { ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") {print $(i+1);exit}}'; }
ipv4() { awk -F. 'NF!=4 {exit 1} {for(i=1;i<=4;i++) if($i !~ /^[0-9]+$/ || $i>255) exit 1}' <<<"$1"; }
validate_subnet() {
  local address prefix last
  [[ "$1" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/2[4-8]$ ]] || die 'Нужна приватная IPv4 подсеть с маской /24–/28.'
  address="${1%/*}"; prefix="${1##*/}"; last="${address##*.}"
  ipv4 "$address" || die 'Некорректный IPv4 подсети.'
  case "$address" in 10.*|192.168.*|172.1[6-9].*|172.2[0-9].*|172.3[01].*) ;; *) die 'Подсеть должна быть приватной (10/8, 172.16/12 или 192.168/16).' ;; esac
  ((10#$last % (1 << (32-prefix)) == 0)) || die 'В --subnet нужен адрес сети, а не отдельного узла.'
}
compose() { "${DOCKER[@]}" compose --project-directory "$ROOT" --env-file "$ROOT/.env" --project-name "$PROJECT" -f "$ROOT/compose.yaml" -f "$CONFIG" "$@"; }

configure() {
  local bind old_mode subnet
  mkdir -p "$ROOT/.runtime/lugbaka"
  if [[ ! -f "$ROOT/.env" ]]; then
    cp -- "$ROOT/.env.example" "$ROOT/.env"
    bind="${BIND_ARG:-$(lan_ip)}"
    [[ -n "$bind" ]] || die 'Сетевой IPv4 не найден. Укажите --bind IPv4.'
    set_env WEBUI_BIND "$bind"
    set_env OLLAMA_CONTEXT_LENGTH 16384
    set_env OLLAMA_KEEP_ALIVE 0
  fi
  [[ -z "$WEB_PORT" ]] || set_env WEBUI_PORT "$WEB_PORT"
  [[ -z "$OLLAMA_PORT_ARG" ]] || set_env OLLAMA_PORT "$OLLAMA_PORT_ARG"
  [[ -z "$BIND_ARG" ]] || set_env WEBUI_BIND "$BIND_ARG"
  if [[ -n "$SUBNET_ARG" ]]; then validate_subnet "$SUBNET_ARG"; set_env LUGBAKA_SUBNET "$SUBNET_ARG"; fi
  subnet="$(read_env LUGBAKA_SUBNET)"
  [[ -z "$subnet" ]] || validate_subnet "$subnet"
  bind="$(read_env WEBUI_BIND)"; ipv4 "$bind" || die 'WEBUI_BIND должен быть IPv4.'
  for p in "$(read_env WEBUI_PORT)" "$(read_env OLLAMA_PORT)"; do
    if [[ ! "$p" =~ ^[0-9]{1,5}$ ]]; then die 'Недопустимый порт в .env.'; fi
    if ((10#$p < 1 || 10#$p > 65535)); then die 'Недопустимый порт в .env.'; fi
  done
  [[ "$(read_env OLLAMA_BIND)" == 127.0.0.1 ]] || die 'OLLAMA_BIND должен оставаться 127.0.0.1.'
  if ((LIGHT)); then set_env QWEN_MODEL qwen3:4b; set_env VLM_MODEL qwen3-vl:4b; fi
  QWEN_MODEL="$(read_env QWEN_MODEL)"; VLM_MODEL="$(read_env VLM_MODEL)"
  for model in "$QWEN_MODEL" "$VLM_MODEL"; do
    [[ "$model" =~ ^[A-Za-z0-9][A-Za-z0-9._/-]*(:[A-Za-z0-9][A-Za-z0-9._-]*)?$ ]] || die 'Недопустимое имя модели в .env.'
  done
  if [[ "$MODE" == auto && -f "$ROOT/.runtime/lugbaka/mode" ]]; then
    old_mode="$(cat "$ROOT/.runtime/lugbaka/mode")"
    case "$old_mode" in cpu|gpu) MODE="$old_mode" ;; *) die 'Повреждено сохранённое значение режима.' ;; esac
  fi
  if [[ "$MODE" == auto ]]; then
    if command -v nvidia-smi >/dev/null; then
      nvidia-smi -L >/dev/null 2>&1 || die 'NVIDIA обнаружена, но nvidia-smi не работает. Исправьте драйвер либо явно выберите --cpu.'
      MODE=gpu
    elif grep -lq '^0x10de$' /sys/bus/pci/devices/*/vendor 2>/dev/null; then
      die 'Найдена NVIDIA без nvidia-smi. Установите рекомендуемый драйвер Ubuntu и перезагрузитесь; либо явно выберите --cpu.'
    else
      MODE=cpu
    fi
  fi
  GPU_STYLE=none
  if [[ "$MODE" == gpu ]]; then
    if [[ "$ACTION" == install ]]; then
      setup_gpu
    elif [[ -f "$ROOT/.runtime/lugbaka/gpu-style" ]]; then
      GPU_STYLE="$(cat "$ROOT/.runtime/lugbaka/gpu-style")"
      case "$GPU_STYLE" in nvidia|cdi) ;; *) die 'Повреждено сохранённое значение GPU.' ;; esac
    else
      die 'Сначала выполните install --gpu.'
    fi
  fi
  printf '%s\n' "$MODE" >"$ROOT/.runtime/lugbaka/mode"
  printf '%s\n' "$GPU_STYLE" >"$ROOT/.runtime/lugbaka/gpu-style"
  CONFIG="$ROOT/.runtime/lugbaka/compose.yaml"
  export LUGBAKA_RUNTIME_DIR="$ROOT/.runtime/lugbaka"
  export LUGBAKA_PROJECT_DIR
  if [[ "$ACTION" == kimi ]]; then
    LUGBAKA_PROJECT_DIR="$(cd -- "$KIMI_PROJECT" && pwd)"
  else
    LUGBAKA_PROJECT_DIR="$ROOT"
  fi
  cat >"$CONFIG" <<'YAML'
services:
  ollama:
    cpus: ${LUGBAKA_OLLAMA_CPUS:-4}
    mem_limit: ${LUGBAKA_OLLAMA_MEMORY:-12g}
    restart: ${LUGBAKA_RESTART:-unless-stopped}
    labels: &qa
      com.facex.qa.temporary: "${LUGBAKA_QA_TEMPORARY:-false}"
      com.facex.qa.owner: "${LUGBAKA_QA_OWNER:-lugbaka}"
      com.facex.qa.kind: container
      com.facex.qa.created_at: "${LUGBAKA_QA_CREATED:-0}"
      com.facex.qa.expires_at: "${LUGBAKA_QA_EXPIRES:-0}"
  open-webui:
    cpus: ${LUGBAKA_WEBUI_CPUS:-2}
    mem_limit: ${LUGBAKA_WEBUI_MEMORY:-4g}
    restart: ${LUGBAKA_RESTART:-unless-stopped}
    environment:
      RAG_EMBEDDING_MODEL_AUTO_UPDATE: "false"
      WHISPER_MODEL_AUTO_UPDATE: "false"
    healthcheck:
      test: [CMD-SHELL, "curl --silent --fail http://localhost:8080/health | jq -ne 'input.status == true'"]
      interval: 10s
      timeout: 5s
      start_period: 120s
      retries: 36
    labels: *qa
  kimi:
    profiles: [tools]
    image: ${LUGBAKA_KIMI_IMAGE:-node:22.21.1-bookworm}
    init: true
    cpus: 1
    mem_limit: 1g
    working_dir: /workspace
    entrypoint: [bash, /lugbaka/kimi-entry.sh]
    environment:
      KIMI_CODE_HOME: /root/.kimi-code
    volumes:
      - kimi-tools:/opt/kimi
      - kimi-home:/root/.kimi-code
      - ${LUGBAKA_RUNTIME_DIR}:/lugbaka:ro
      - ${LUGBAKA_PROJECT_DIR}:/workspace
    labels: *qa
volumes:
  kimi-tools:
  kimi-home:
YAML
  if [[ -n "$subnet" ]]; then
    printf '\nnetworks:\n  default:\n    ipam:\n      config:\n        - subnet: %s\n' "$subnet" >>"$CONFIG"
  fi
  case "$GPU_STYLE" in
    nvidia) cat >>"$CONFIG" <<'YAML'
x-gpu-selected: nvidia
YAML
      # Add the upstream NVIDIA reservation as a third compose file below.
      ;;
    cdi) cat >"$ROOT/.runtime/lugbaka/gpu-cdi.yaml" <<'YAML'
services:
  ollama:
    devices:
      - nvidia.com/gpu=all
YAML
      ;;
  esac
  cat >"$ROOT/.runtime/lugbaka/kimi-entry.sh" <<'SH'
#!/usr/bin/env bash
set -Eeuo pipefail
version=2.5.2
if [[ "${1:-}" == install ]]; then
  current="$(node -p 'require("/opt/kimi/node_modules/@moonshot-ai/kimi-code/package.json").version' 2>/dev/null || :)"
  if [[ "$current" != "$version" ]]; then
    npm install --prefix /opt/kimi --no-audit --no-fund "@moonshot-ai/kimi-code@$version"
  fi
  cp /lugbaka/kimi.toml /root/.kimi-code/config.toml
  exec /opt/kimi/node_modules/.bin/kimi --version
fi
[[ -x /opt/kimi/node_modules/.bin/kimi ]] || { printf 'Сначала запустите установку lugbaka.sh.\n' >&2; exit 1; }
cp /lugbaka/kimi.toml /root/.kimi-code/config.toml
exec /opt/kimi/node_modules/.bin/kimi "$@"
SH
  cat >"$ROOT/.runtime/lugbaka/kimi.toml" <<TOML
default_model = "ollama/$QWEN_MODEL"
default_permission_mode = "manual"
telemetry = false
[providers.ollama]
type = "openai"
base_url = "http://ollama:11434/v1"
api_key = "ollama"
[models."ollama/$QWEN_MODEL"]
provider = "ollama"
model = "$QWEN_MODEL"
max_context_size = 16384
capabilities = ["thinking", "tool_use"]
TOML
}

# Include GPU configuration consistently for up, pull, exec and down.
dc() {
  local files=()
  case "$GPU_STYLE" in nvidia) files=(-f "$ROOT/compose.gpu.yaml") ;; cdi) files=(-f "$ROOT/.runtime/lugbaka/gpu-cdi.yaml") ;; esac
  compose "${files[@]}" "$@"
}

wait_http() {
  local url="$1" attempts="${LUGBAKA_READY_ATTEMPTS:-120}" i
  for ((i=0; i<attempts; i++)); do
    if curl -fsS --connect-timeout 2 --max-time 5 "$url" >/dev/null 2>&1; then return; fi
    sleep 3
  done
  die "Сервис не ответил: $url. Посмотрите: bash $SELF logs --project $PROJECT"
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
  printf '  Остановка с сохранением данных: bash %q down --project %q\n' "$SELF" "$PROJECT"
  printf '============================================================\n'
}

if [[ "$ACTION" == install || "$ACTION" == prepare ]]; then
  if [[ "${LUGBAKA_NO_SYSTEM_CHANGES:-0}" == 1 ]]; then ubuntu; else install_dependencies; fi
fi
[[ "$ACTION" != prepare ]] || exit 0
docker_access
if [[ "$ACTION" == gpu-check ]]; then
  setup_gpu
  if [[ "$GPU_STYLE" == cdi ]]; then GPU_FLAGS=(--device nvidia.com/gpu=all); else GPU_FLAGS=(--gpus all); fi
  "${DOCKER[@]}" run --rm "${GPU_FLAGS[@]}" --entrypoint nvidia-smi "${OLLAMA_IMAGE:-ollama/ollama:0.32.15}" --query-gpu=name,driver_version --format=csv,noheader
  exit 0
fi
if [[ ! -f "$ROOT/compose.yaml" ]]; then
  [[ "$ACTION" == install ]] || die 'Репозиторий не найден. Сначала выполните install.'
  [[ "$ROOT" != "$(dirname -- "$SELF")" ]] || ROOT="$PWD/BRODYAGA"
  [[ ! -e "$ROOT" ]] || die "Папка $ROOT уже существует; укажите отдельную --directory."
  git clone -- https://github.com/media314/BRODYAGA.git "$ROOT"
  git -C "$ROOT" checkout --detach "$UPSTREAM_SHA"
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
      dc run --rm --no-deps -T kimi install
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
