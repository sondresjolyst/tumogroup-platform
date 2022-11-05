#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Install flux in radix cluster.

#######################################################################################
### HOW TO USE
###

# Normal usage
# ZONE_ENV=../zone/production.env CLUSTER_NAME="kubernetes-admin@kubernetes" ./bootstrap.sh

#######################################################################################
### START
###

echo ""
echo "Start installing Flux..."

#######################################################################################
### Check for prerequisites binaries
###

echo ""
printf "Check for neccesary executables... "

hash kubectl 2>/dev/null || {
    echo -e "\nERROR: kubectl not found in PATH. Exiting..." >&2
    exit 1
}

hash helm 2>/dev/null || {
    echo -e "\nERROR: helm not found in PATH. Exiting..." >&2
    exit 1
}

hash flux 2>/dev/null || {
    echo -e "\nERROR: flux not found in PATH. Exiting..." >&2
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

if [[ -z "$GIT_REPO" ]]; then
    echo "ERROR: Please provide GIT_REPO" >&2
    exit 1
fi

if [[ -z "$GIT_BRANCH" ]]; then
    echo "ERROR: Please provide GIT_BRANCH" >&2
    exit 1
fi

if [[ -z "$GIT_DIR" ]]; then
    echo "ERROR: Please provide GIT_DIR" >&2
    exit 1
fi

if [[ -z "$FLUX_VERSION" ]]; then
    echo "ERROR: Please provide FLUX_VERSION" >&2
    exit 1
fi

FLUX_LOCAL="$(flux version -ojson | jq -r .flux)"

#######################################################################################
### Verify task at hand
###

echo -e ""
echo -e "Install Flux v2 will use the following configuration:"
echo -e ""
echo -e "   > WHERE:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  ZONE                             : $ZONE"
echo -e "   -  CLUSTER_NAME                     : $CLUSTER_NAME"
echo -e ""
echo -e "   > WHAT:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  GIT_REPO                         : $GIT_REPO"
echo -e "   -  GIT_BRANCH                       : $GIT_BRANCH"
echo -e "   -  GIT_DIR                          : $GIT_DIR"
echo -e "   -  FLUX_VERSION                     : $FLUX_VERSION"
echo -e "   -  FLUX_LOCAL                       : $FLUX_LOCAL"
echo -e ""

echo ""

if [[ $USER_PROMPT == true ]]; then
    while true; do
        read -p "Is this correct? (Y/n) " yn
        case $yn in
            [Yy]* ) break;;
            [Nn]* ) echo ""; echo "Quitting."; exit 0;;
            * ) echo "Please answer yes or no.";;
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
if [[ $(kubectl get namespace flux-system 2>&1) == *"Error"* ]];then
    kubectl create ns flux-system 2>&1 >/dev/null
fi
printf "...Done"

#######################################################################################
### INSTALLATION

echo ""
printf "Starting installation of Flux...\n"

FLUX_PRIVATE_KEY_NAME=tumogroup-production-cluster

flux bootstrap git \
    --private-key-file="$FLUX_PRIVATE_KEY_NAME" \
    --url="$GIT_REPO" \
    --branch="$GIT_BRANCH" \
    --path="$GIT_DIR" \
    --components-extra=image-reflector-controller,image-automation-controller \
    --version="$FLUX_VERSION" \
    --silent
if [[ "$?" != "0" ]]
then
  printf "\nERROR: flux bootstrap git failed. Exiting...\n" >&2
#   rm "$FLUX_PRIVATE_KEY_NAME"
  exit 1
else
#   rm "$FLUX_PRIVATE_KEY_NAME"
  echo " Done."
fi

echo -e ""
echo -e "A Flux service has been provisioned in the cluster to follow the GitOps way of thinking."

if [ "$FLUX_DEPLOY_KEYS_GENERATED" = true ]; then
    FLUX_DEPLOY_KEY_NOTIFICATION="*** IMPORTANT ***\nPlease add a new deploy key in the radix-flux repository (https://github.com/equinor/radix-flux/settings/keys) with the value from $FLUX_PUBLIC_KEY_NAME secret in $AZ_RESOURCE_KEYVAULT Azure keyvault."
    echo ""
    echo -e "${__style_yellow}$FLUX_DEPLOY_KEY_NOTIFICATION${__style_end}"
    echo ""
fi

#######################################################################################
### END
###

echo "Bootstrap of Flux is done!"
echo ""