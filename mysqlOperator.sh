#!/bin/bash

set -ex

CHART_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/mysql-operator-chart" && pwd)"

if [[ $# -eq 2 ]]; then
    OPERATOR_NAMESPACE=$2
else
  OPERATOR_NAMESPACE=$1
fi

function deleteMysqlCR () {
  mysqlcluster_list=($(kubectl get mysqlcluster -n "${OPERATOR_NAMESPACE}" | awk 'FNR > 1 {print $1}'))
  for mysqlcluster in "${mysqlcluster_list[@]}"; do
      echo "Deleting mysqlcluster"
      kubectl delete mysqlcluster -n "${OPERATOR_NAMESPACE}" "${mysqlcluster}" --force --grace-period=0 --timeout=5s || true
      kubectl patch mysqlcluster -n "${OPERATOR_NAMESPACE}" "${mysqlcluster}" --type=json -p='[{"op": "remove", "path": "/metadata/finalizers"}]' || true
  done
}

echo "Checking for the operation in sample-release"
if [[ $# -ne 0 && $1 == "delete" ]]; then
    echo "deleting helm sample-release"
    if [[ "${HELM_VERSION}" == "v2" ]]; then
       helm2 del --purge sample-release
    else
       helm delete sample-release -n "${OPERATOR_NAMESPACE}"
    fi

    deleteMysqlCR

elif [[ $# -ne 0 && $1 == "upgrade" ]]; then
     echo "upgrading helm release"
     if [[ "${HELM_VERSION}" == "v2" ]]; then
        helm2 upgrade --set orchestrator.persistence.storageClass="${STORAGE_CLASS}",operatorNamespace="${OPERATOR_NAMESPACE}",replicas=2 sample-release "${CHART_PATH}" --namespace "${OPERATOR_NAMESPACE}"
     else
        helm upgrade sample-release "${CHART_PATH}" -n "${OPERATOR_NAMESPACE}"  --set orchestrator.persistence.storageClass="${STORAGE_CLASS}",operatorNamespace="${OPERATOR_NAMESPACE}",replicas=2
     fi

elif [[ $# -ne 0 && $1 == "rollback" ]]; then
     echo "rolling back helm release to previous version"
     if [[ "${HELM_VERSION}" == "v2" ]]; then
        helm2 rollback sample-release 0 --wait || true
     else
        helm rollback sample-release -n "${OPERATOR_NAMESPACE}" --wait || true
     fi

else
    echo "Installing mysql operator with release name 'sample-release' in namespace: ${OPERATOR_NAMESPACE}"
    if [[ "${HELM_VERSION}" == "v2" ]]; then
        helm2 install --set orchestrator.persistence.storageClass="${STORAGE_CLASS}" --set operatorNamespace="${OPERATOR_NAMESPACE}" \
        "${CHART_PATH}" -n sample-release --namespace "${OPERATOR_NAMESPACE}"
    else
        helm install sample-release -n "${OPERATOR_NAMESPACE}" "${CHART_PATH}" --set orchestrator.persistence.storageClass="${STORAGE_CLASS}" \
      --set operatorNamespace="${OPERATOR_NAMESPACE}"
    fi
fi
