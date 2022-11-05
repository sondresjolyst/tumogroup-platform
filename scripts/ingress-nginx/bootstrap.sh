#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Bootstrap ingress-nginx in cluster

#######################################################################################
### HOW TO USE
###

# Normal usage
# ZONE_ENV=../zone/production.env CLUSTER_NAME="kubernetes-admin@kubernetes" ./bootstrap.sh

#######################################################################################
### START
###

echo ""
echo "Start bootstrap of ingress-nginx..."

#######################################################################################
### Check for prerequisites binaries
###

echo ""
printf "Check for neccesary executables... "

hash jq 2>/dev/null || {
    echo -e "\nERROR: jq not found in PATH. Exiting..." >&2
    exit 1
}

hash kubectl 2>/dev/null || {
    echo -e "\nERROR: kubectl not found in PATH. Exiting..." >&2
    exit 1
}

printf "All is good."
echo ""

#######################################################################################
### Read inputs and configs
###

# Required inputs

if [[ -z "$ZONE_ENV" ]]; then
    echo "ERROR: Please provide ZONE_ENV" >&2
    exit 1
else
    if [[ ! -f "$ZONE_ENV" ]]; then
        echo "ERROR: ZONE_ENV=$ZONE_ENV is invalid, the file does not exist." >&2
        exit 1
    fi
    source "$ZONE_ENV"
fi

if [[ -z "$CLUSTER_NAME" ]]; then
    echo "ERROR: Please provide CLUSTER_NAME" >&2
    exit 1
fi

if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT=true
fi

#######################################################################################
### Verify task at hand
###

echo -e ""
echo -e "Install ingress-nginx will use the following configuration:"
echo -e ""
echo -e "   > WHERE:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  ZONE                             : $ZONE"
echo -e "   -  CLUSTER_NAME                     : $CLUSTER_NAME"
echo -e ""

echo ""

if [[ $USER_PROMPT == true ]]; then
    while true; do
        read -r -p "Is this correct? (Y/n) " yn
        case $yn in
        [Yy]*) break ;;
        [Nn]*)
            echo ""
            echo "Quitting."
            exit 0
            ;;
        *) echo "Please answer yes or no." ;;
        esac
    done
    echo ""
fi

#######################################################################################
### CLUSTER?
###

kubectl_context="$(kubectl config current-context)"

if [ "$kubectl_context" = "$CLUSTER_NAME" ] || [ "$kubectl_context" = "${CLUSTER_NAME}" ]; then
    echo "kubectl is ready..."
else
    echo "ERROR: Please set your kubectl current-context to be ${CLUSTER_NAME}" >&2
    exit 1
fi

#######################################################################################
### Create secret required by ingress-nginx
###

echo "Install secret ingress-ip in cluster"

SELECTED_INGRESS_IP_RAW_ADDRESS=$(dig +short myip.opendns.com @resolver1.opendns.com)

kubectl create namespace ingress-nginx --dry-run=client -o yaml |
    kubectl apply -f -

kubectl create secret generic ingress-nginx-raw-ip --namespace ingress-nginx \
    --from-literal=rawIp=$SELECTED_INGRESS_IP_RAW_ADDRESS \
    --dry-run=client -o yaml |
    kubectl apply -f -

echo "controller:
  service:
    loadBalancerIP: $SELECTED_INGRESS_IP_RAW_ADDRESS" > config

kubectl create secret generic ingress-nginx-ip --namespace ingress-nginx \
    --from-file=./config \
    --dry-run=client -o yaml |
    kubectl apply -f -

rm config

printf "Done.\n"
