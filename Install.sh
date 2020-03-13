#!/bin/bash

cmd=$1
export HELM_VERSION="v3"
export INSTALL_NAMESPACE="openshift-marketplace"
export STORAGE_CLASS="csi-hostpath-sc"

function InstallMySql(){
    kubectl get scc mysql
    if [[ $? -ne 0 ]]; then
	oc apply -f scc.yaml
    fi
    kubectl apply -f crd.yaml
    ./mysqlOperator.sh $INSTALL_NAMESPACE
    kubectl apply -f mysqlCluster-secret.yaml -n $INSTALL_NAMESPACE
    kubectl apply -f mysqlCluster.yaml -n $INSTALL_NAMESPACE
}

function UninstallMySql(){
    ./mysqlOperator.sh delete "$INSTALL_NAMESPACE"
    kubectl delete -f mysqlCluster.yaml -n "$INSTALL_NAMESPACE"
    kubectl delete -f mysqlCluster-secret.yaml -n "$INSTALL_NAMESPACE"
    kubectl delete -f crd.yaml
}

if [[ $cmd == "install" ]]; then
	InstallMySql
elif [[ $cmd == "uninstall" ]]; then
	UninstallMySql
else
	echo "No Input Provided. Please give either of install/uninstall argument to script" 
fi
