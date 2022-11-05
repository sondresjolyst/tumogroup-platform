#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Configure metallb

#######################################################################################
### HOW TO USE
###

# Normal usage
# ZONE_ENV=../zone/production.env CLUSTER_NAME="kubernetes-admin@kubernetes" ./bootstrap.sh

#######################################################################################
### START
###

echo ""
echo "Start installing metallb..."

#######################################################################################
### Check for prerequisites binaries
###

echo ""
printf "Check for neccesary executables... "

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
echo -e "Install metallb will use the following configuration:"
echo -e ""
echo -e "   > WHERE:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  ZONE                             : $ZONE"
echo -e "   -  CLUSTER_NAME                     : $CLUSTER_NAME"
echo -e ""
echo -e "   > WHAT:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  TUMOGROUP_IPADDRESSPOOL          : ${TUMOGROUP_IPADDRESSPOOL}"
echo -e ""

echo ""

if [[ $USER_PROMPT == true ]]; then
    while true; do
        read -p "Is this correct? (Y/n) " yn
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
    echo "ERROR: Please set your kubectl current-context to be $CLUSTER_NAME" >&2
    exit 1
fi

#######################################################################################
### Check namespace
###

printf "\nWorking on namespace..."
if [[ $(kubectl get namespace flux-system 2>&1) == *"Error"* ]]; then
    kubectl create ns flux-system 2>&1 >/dev/null
fi
printf "...Done"

#######################################################################################
### INSTALLATION
###

printf "\nConfigure kube-proxy... "

kubectl get configmap kube-proxy -n kube-system -o yaml |
    sed -e "s/strictARP: false/strictARP: true/" |
    kubectl apply -f - -n kube-system

kubectl create namespace metallb-system --dry-run=client -o yaml |
    kubectl apply -f -

printf "Creating IPAddressPool... "
# metadata name has to match configMap name in equinor/radix-flux/clusters/development/overlay/third-party/ingress-nginx/ingress-nginx.yaml
cat <<EOF | kubectl apply -f - 2>&1 >/dev/null
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: ipaddresspool1
  namespace: metallb-system
spec:
  addresses:
  - "${TUMOGROUP_IPADDRESSPOOL}"
  autoAssign: true
EOF
printf "Done.\n"

printf "Creating L2Advertisement... "
# metadata name has to match configMap name in equinor/radix-flux/clusters/development/overlay/third-party/ingress-nginx/ingress-nginx.yaml
cat <<EOF | kubectl apply -f - 2>&1 >/dev/null
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: l2advertisement
  namespace: metallb-system
spec:
  ipAddressPools:
  - ipaddresspool1
EOF
printf "Done.\n"

#######################################################################################
### END
###

printf "\nDone.\n"
