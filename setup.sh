#!/bin/sh
set -e

gum style \
	--foreground 212 --border-foreground 212 --border double \
	--margin "1 2" --padding "2 4" \
	'This script assumes that you jumped straight into this chapter.
If that is not the case (if you are continuing from the previous
chapter), please answer with "No" when asked whether you are
ready to start.'

gum confirm '
Are you ready to start?
Select "Yes" only if you did NOT follow the story from the start (if you jumped straight into this chapter).
Feel free to say "No" and inspect the script if you prefer setting up resources manually.
' || exit 0

echo "
## You will need following tools installed:
|Name            |Required             |More info                                          |
|----------------|---------------------|---------------------------------------------------|
|Docker          |Yes                  |'https://docs.docker.com/engine/install'           |
|gitHub CLI      |Yes                  |'https://cli.github.com/'                          |
|git CLI         |Yes                  |'https://git-scm.com/downloads'                    |
|helm CLI        |If using Helm        |'https://helm.sh/docs/intro/install/'              |
|kubectl CLI     |Yes                  |'https://kubernetes.io/docs/tasks/tools/#kubectl'  |
|kind CLI        |Yes                  |'https://kind.sigs.k8s.io/docs/user/quick-start/#installation'|
|yq CLI          |Yes                  |'https://github.com/mikefarah/yq#install'          |
|jq CLI          |Yes                  |'https://jqlang.github.io/jq/download'             |
|pack CLI        |Yes                  |'https://buildpacks.io/docs/tools/pack'            |
|Google Cloud account with admin permissions|If using Google Cloud|'https://cloud.google.com'|
|Google Cloud CLI|If using Google Cloud|'https://cloud.google.com/sdk/docs/install'        |
|AWS account with admin permissions|If using AWS|'https://aws.amazon.com'                  |
|AWS CLI         |If using AWS         |'https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html'|
|Azure account with admin permissions|If using Azure|'https://azure.microsoft.com'         |
|az CLI          |If using Azure       |'https://learn.microsoft.com/cli/azure/install-azure-cli'|

If you are running this script from **Nix shell**, most of the requirements are already set with the exception of **Docker** and the **hyperscaler account**.
" | gum format

gum confirm "
Do you have those tools installed?
" || exit 0

#############
# Variables #
#############

GITHUB_ORG=$(gum input --placeholder "GitHub Organization" \
    --value "$GITHUB_ORG")

REGISTRY_SERVER=$(gum input \
    --placeholder "Container image registry server (e.g., ghcr.io/vfarcic)" \
    --value "$REGISTRY_SERVER")

REGISTRY_USER=$(gum input \
    --placeholder "Container image registry username (e.g., ghcr.io/vfarcic)" \
    --value "$REGISTRY_USER")

REGISTRY_PASSWORD=$(gum input \
    --placeholder "Container image registry password (e.g., ghcr.io/vfarcic)" \
    --value "$REGISTRY_PASSWORD")

echo "## Which Hyperscaler do you want to use?" | gum format

HYPERSCALER=$(gum choose "google" "aws" "azure")

echo "export HYPERSCALER=$HYPERSCALER" >> .env

###########
# Cluster #
###########

kind create cluster

kubectl create namespace a-team

##############
# Crossplane #
##############

helm repo add crossplane-stable \
    https://charts.crossplane.io/stable

helm repo update

helm upgrade --install crossplane crossplane-stable/crossplane \
    --namespace crossplane-system --create-namespace --wait

kubectl apply --filename crossplane-packages/dot-kubernetes.yaml

kubectl apply \
    --filename crossplane-packages/kubernetes-incluster.yaml

kubectl apply --filename crossplane-packages/helm-incluster.yaml

echo "## Waiting for Crossplane Packages..." | gum format

sleep 60

kubectl wait --for=condition=healthy provider.pkg.crossplane.io --all --timeout=600s

if [[ "$HYPERSCALER" == "google" ]]; then

    gcloud auth login

    gcloud components install gke-gcloud-auth-plugin

    # Project

    PROJECT_ID=dot-$(date +%Y%m%d%H%M%S)

    echo "export PROJECT_ID=$PROJECT_ID" >> .env

    gcloud projects create ${PROJECT_ID}

    # APIs

    echo "## Open https://console.cloud.google.com/marketplace/product/google/container.googleapis.com?project=$PROJECT_ID in a browser and *ENABLE* the API." \
        | gum format

    gum input --placeholder "
Press the enter key to continue."

echo "## Open https://console.cloud.google.com/marketplace/product/google/secretmanager.googleapis.com?project=$PROJECT_ID in a browser and *ENABLE* the API." \
        | gum format

    gum input --placeholder "
Press the enter key to continue."

    # Service Account (general)

    export SA_NAME=devops-toolkit

    export SA="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

    gcloud iam service-accounts create $SA_NAME \
        --project $PROJECT_ID

    export ROLE=roles/admin

    gcloud projects add-iam-policy-binding --role $ROLE \
        $PROJECT_ID --member serviceAccount:$SA

    gcloud iam service-accounts keys create gcp-creds.json \
        --project $PROJECT_ID --iam-account $SA

    kubectl --namespace crossplane-system \
        create secret generic gcp-creds \
        --from-file creds=./gcp-creds.json

    # Crossplane

    yq --inplace ".spec.projectID = \"$PROJECT_ID\"" \
        crossplane-packages/google-config.yaml

    kubectl apply \
        --filename crossplane-packages/google-config.yaml

elif [[ "$HYPERSCALER" == "aws" ]]; then

    AWS_ACCESS_KEY_ID=$(gum input --placeholder "AWS Access Key ID" --value "$AWS_ACCESS_KEY_ID")
    echo "export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID" >> .env
    
    AWS_SECRET_ACCESS_KEY=$(gum input --placeholder "AWS Secret Access Key" --value "$AWS_SECRET_ACCESS_KEY" --password)
    echo "export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY" >> .env

    AWS_ACCOUNT_ID=$(gum input --placeholder "AWS Account ID" --value "$AWS_ACCOUNT_ID")
    echo "export AWS_ACCOUNT_ID=$AWS_ACCOUNT_ID" >> .env

    echo "[default]
aws_access_key_id = $AWS_ACCESS_KEY_ID
aws_secret_access_key = $AWS_SECRET_ACCESS_KEY
" >aws-creds.conf

    kubectl --namespace crossplane-system \
        create secret generic aws-creds \
        --from-file creds=./aws-creds.conf
    
    kubectl apply \
        --filename crossplane-packages/aws-config.yaml

elif [[ "$HYPERSCALER" == "azure" ]]; then

    AZURE_TENANT_ID=$(gum input --placeholder "Azure Tenant ID" \
        --value "$AZURE_TENANT_ID")

    az login --tenant $AZURE_TENANT_ID

    export LOCATION=eastus

    export SUBSCRIPTION_ID=$(az account show --query id -o tsv)

    az ad sp create-for-rbac --sdk-auth --role Owner \
        --scopes /subscriptions/$SUBSCRIPTION_ID \
        | tee azure-creds.json

    kubectl --namespace crossplane-system \
        create secret generic azure-creds \
        --from-file creds=./azure-creds.json

    kubectl apply \
        --filename crossplane-packages/azure-config.yaml

fi

############
# Registry #
############

kubectl --namespace a-team \
    create secret docker-registry push-secret \
    --docker-server=$REGISTRY_SERVER \
    --docker-username=$REGISTRY_USER \
    --docker-password=$REGISTRY_PASSWORD

REGISTRY_AUTH=$(kubectl --namespace a-team \
    get secret push-secret \
    --output jsonpath='{.data.\.dockerconfigjson}' | base64 -d)

kubectl --namespace a-team delete secret push-secret

if [[ "$HYPERSCALER" == "google" ]]; then

    echo -ne $REGISTRY_AUTH \
        | gcloud secrets --project $PROJECT_ID \
        create registry-auth --data-file=-

fi

##################
# Atlas Operator #
##################

helm upgrade --install atlas-operator \
    oci://ghcr.io/ariga/charts/atlas-operator \
    --namespace atlas-operator --create-namespace --wait
