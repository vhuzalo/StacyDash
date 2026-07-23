#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Uso:
  ./deploy.sh [--dry-run] [/caminho/para/raiz-do-cartao]

Exemplos:
  ./deploy.sh
  ./deploy.sh --dry-run
  ./deploy.sh --dry-run /run/media/$USER/EDGETX
  ./deploy.sh /run/media/$USER/EDGETX

Sem um destino, o script procura automaticamente um cartão EdgeTX montado em
/run/media, /media ou /mnt. O destino explícito deve ser a raiz do cartão SD,
onde ficam WIDGETS/ e IMAGES/.
O script atualiza o widget, os áudios e as imagens, mas nunca sobrescreve um
flights-count.csv que já exista no rádio.
EOF
}

dry_run=false
radio_root=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run) dry_run=true ;;
    -h|--help) usage; exit 0 ;;
    --*)
      printf 'Erro: opção desconhecida: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
    *)
      if [[ -n $radio_root ]]; then
        printf 'Erro: informe no máximo um destino.\n' >&2
        usage >&2
        exit 2
      fi
      radio_root=${1%/}
      ;;
  esac
  shift
done

is_edgetx_root() {
  local candidate=$1
  [[ -d $candidate/WIDGETS ]] || return 1
  [[ -d $candidate/RADIO || -d $candidate/SCRIPTS || -d $candidate/SOUNDS \
     || -d $candidate/IMAGES ]]
}

detect_radio_root() {
  local default_roots="/run/media/${USER:-}:/media/${USER:-}:/run/media:/media:/mnt"
  local configured_roots=${STACYDASH_MOUNT_ROOTS:-$default_roots}
  local search_root candidate
  local -a roots candidates
  local -A seen=()
  IFS=: read -r -a roots <<< "$configured_roots"

  for search_root in "${roots[@]}"; do
    [[ -n $search_root && -d $search_root ]] || continue
    if is_edgetx_root "$search_root" && [[ -z ${seen["$search_root"]+x} ]]; then
      candidates+=("$search_root")
      seen["$search_root"]=1
    fi
    while IFS= read -r -d '' candidate; do
      is_edgetx_root "$candidate" || continue
      [[ -z ${seen["$candidate"]+x} ]] || continue
      candidates+=("$candidate")
      seen["$candidate"]=1
    done < <(find "$search_root" -mindepth 1 -maxdepth 2 -type d -print0 2>/dev/null)
  done

  if [[ ${#candidates[@]} -eq 1 ]]; then
    radio_root=${candidates[0]}
    printf 'Rádio EdgeTX detectado automaticamente: %s\n' "$radio_root"
    return
  fi
  if [[ ${#candidates[@]} -eq 0 ]]; then
    printf 'Erro: nenhum cartão EdgeTX montado foi detectado.\n' >&2
  else
    printf 'Erro: mais de um cartão EdgeTX foi detectado:\n' >&2
    printf '  %s\n' "${candidates[@]}" >&2
  fi
  printf 'Informe a raiz desejada: ./deploy.sh /caminho/para/o/cartao\n' >&2
  exit 1
}

project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if [[ -z $radio_root ]]; then
  detect_radio_root
fi

if [[ ! -d $radio_root ]]; then
  printf 'Erro: o destino não existe ou não é uma pasta: %s\n' "$radio_root" >&2
  exit 1
fi

case $radio_root in
  ""|/|"$project_dir")
    printf 'Erro: destino inseguro: %s\n' "$radio_root" >&2
    exit 1
    ;;
esac

required_files=(
  "WIDGETS/StacyDashV4/main.lua"
  "WIDGETS/StacyDashV4/flights.lua"
  "WIDGETS/StacyDashV4/status.lua"
  "WIDGETS/StacyDashV4/themes.lua"
  "WIDGETS/StacyDashV4/ui.lua"
  "WIDGETS/StacyDashV4/leds.lua"
  "WIDGETS/StacyDashV4/elrs.lua"
  "WIDGETS/StacyDashV4/default.png"
  "flights-count.csv"
)

for relative_path in "${required_files[@]}"; do
  if [[ ! -f $project_dir/$relative_path ]]; then
    printf 'Erro: arquivo necessário não encontrado: %s\n' "$relative_path" >&2
    exit 1
  fi
done

copy_file() {
  local source=$1
  local destination=$2

  if [[ -f $destination ]] && cmp -s -- "$source" "$destination"; then
    return
  fi

  if $dry_run; then
    if [[ -e $destination ]]; then
      printf '[dry-run] Atualizar: %s\n' "${source#"$project_dir"/}"
    else
      printf '[dry-run] Instalar: %s\n' "${source#"$project_dir"/}"
    fi
    return
  fi

  mkdir -p -- "$(dirname -- "$destination")"
  cp -p -- "$source" "$destination"
  printf 'Atualizado: %s\n' "${source#"$project_dir"/}"
}

copy_matching_files() {
  local source_dir=$1
  local destination_dir=$2
  shift 2
  local pattern source

  for pattern in "$@"; do
    while IFS= read -r -d '' source; do
      copy_file "$source" "$destination_dir/$(basename -- "$source")"
    done < <(find "$source_dir" -maxdepth 1 -type f -name "$pattern" -print0)
  done
}

printf 'Destino do rádio: %s\n' "$radio_root"

copy_matching_files \
  "$project_dir/WIDGETS/StacyDashV4" \
  "$radio_root/WIDGETS/StacyDashV4" \
  '*.lua'
copy_file \
  "$project_dir/WIDGETS/StacyDashV4/default.png" \
  "$radio_root/WIDGETS/StacyDashV4/default.png"

copy_matching_files \
  "$project_dir/WIDGETS/StacyDashV4/BatterySounds" \
  "$radio_root/WIDGETS/StacyDashV4/BatterySounds" \
  '*.wav'

copy_matching_files \
  "$project_dir/WIDGETS/StacyDashV4/audio" \
  "$radio_root/WIDGETS/StacyDashV4/audio" \
  '*.wav'
copy_matching_files \
  "$project_dir/WIDGETS/StacyDashV4/audio/gov" \
  "$radio_root/WIDGETS/StacyDashV4/audio/gov" \
  '*.wav'
copy_matching_files \
  "$project_dir/WIDGETS/StacyDashV4/audio/profile" \
  "$radio_root/WIDGETS/StacyDashV4/audio/profile" \
  '*.wav'

copy_matching_files \
  "$project_dir/IMAGES" \
  "$radio_root/IMAGES" \
  '*.png' '*.bmp'

if [[ -e $radio_root/flights-count.csv ]]; then
  printf 'Preservado: flights-count.csv já existe no rádio.\n'
else
  copy_file "$project_dir/flights-count.csv" "$radio_root/flights-count.csv"
fi

if $dry_run; then
  printf 'Dry-run concluído; nenhum arquivo foi alterado.\n'
else
  printf 'Deploy do StacyDash concluído.\n'
fi
