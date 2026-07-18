#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Uso:
  ./deploy.sh [--dry-run] /caminho/para/raiz-do-cartao

Exemplos:
  ./deploy.sh --dry-run /run/media/$USER/EDGETX
  ./deploy.sh /run/media/$USER/EDGETX

O destino deve ser a raiz do cartão SD, onde ficam WIDGETS/ e IMAGES/.
O script atualiza o widget, os áudios e as imagens, mas nunca sobrescreve um
flights-count.csv que já exista no rádio.
EOF
}

dry_run=false
if [[ ${1:-} == "--dry-run" ]]; then
  dry_run=true
  shift
fi

if [[ $# -ne 1 || ${1:-} == "-h" || ${1:-} == "--help" ]]; then
  usage
  [[ $# -eq 1 ]] && exit 0
  exit 2
fi

project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
radio_root=${1%/}

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

  if $dry_run; then
    printf '[dry-run] %s -> %s\n' "$source" "$destination"
    return
  fi

  mkdir -p -- "$(dirname -- "$destination")"
  cp -p -- "$source" "$destination"
  printf 'Copiado: %s\n' "${source#"$project_dir"/}"
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

copy_file \
  "$project_dir/WIDGETS/StacyDashV4/main.lua" \
  "$radio_root/WIDGETS/StacyDashV4/main.lua"
copy_file \
  "$project_dir/WIDGETS/StacyDashV4/default.png" \
  "$radio_root/WIDGETS/StacyDashV4/default.png"

copy_matching_files \
  "$project_dir/WIDGETS/StacyDashV4/BatterySounds" \
  "$radio_root/WIDGETS/StacyDashV4/BatterySounds" \
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
