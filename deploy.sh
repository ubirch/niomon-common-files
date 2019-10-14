#!/usr/bin/env bash
set -e

# this works as long as the executed script is not a symlink
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
cd "${DIR}"
cd ./helm-charts

function usage() {
  echo -e "$0 {env name: dev/demo/prod} {microservices...} [ -- {rest passed to helm.sh install}...]
example:\n\t$0 dev auth\n\t$0 demo decoder enricher -- --set image.tag=foobar"
}

if [[ ! -f "${HELMSH}" ]]; then
  if [[ -f "/keybase/team/ubirchdevops/bin/helm.sh" ]]; then
    HELMSH="/keybase/team/ubirchdevops/bin/helm.sh"
  elif [[ -f "/keybase/team/ubirch_developer/devkube/bin/helm.sh" ]]; then
    HELMSH="/keybase/team/ubirch_developer/devkube/bin/helm.sh"
  else
    echo "helm.sh not found"
    exit 1
  fi
fi

if [[ -z "$1" ]]; then
  usage
  exit 1
fi

UBIRCH_ENV=$1
shift
NIOMON_MICROSERVICES=()

while [ "$1" != "--" ] && [ -n "$1" ]; do
  NIOMON_MICROSERVICES+=("$1")
  shift
done

if [ "$1" = "--" ]; then
  shift
fi

ADDITIONAL_ARGS=$*

for HELM_PROJECT_NAME in "${NIOMON_MICROSERVICES[@]}"; do
  echo "Microservice: $HELM_PROJECT_NAME"
  VALUES_FILE="./${HELM_PROJECT_NAME}/values.${UBIRCH_ENV}.yaml"
  echo "Values file: $VALUES_FILE"

  # we allow errors here, because it's normal for the delete command to fail, ex. it's the first time we're deploying
  set +e
  set -x

  if ! echo "${ADDITIONAL_ARGS}" | grep "dry-run"; then
    ${HELMSH} "${UBIRCH_ENV}" delete "niomon-${HELM_PROJECT_NAME}-${UBIRCH_ENV}" --purge
  fi

  ${HELMSH} "${UBIRCH_ENV}" install \
    "${HELM_PROJECT_NAME}" --namespace "ubirch-${UBIRCH_ENV}" \
    --name "niomon-${HELM_PROJECT_NAME}-${UBIRCH_ENV}" --debug \
    -f "${VALUES_FILE}" \
    --set "image.tag=${UBIRCH_ENV}" \
    $ADDITIONAL_ARGS
done
