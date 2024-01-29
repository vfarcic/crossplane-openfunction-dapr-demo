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
|gke-gcloud-auth-plugin|If using Google Cloud|'https://cloud.google.com/blog/products/containers-kubernetes/kubectl-auth-changes-in-gke'|
|AWS account with admin permissions|If using AWS|'https://aws.amazon.com'                  |
|AWS CLI         |If using AWS         |'https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html'|

If you are running this script from **Nix shell**, most of the requirements are already set with the exception of **Docker** and the **hyperscaler account**.
" | gum format

gum confirm "
Do you have those tools installed?
" || exit 0

rm -f .env

#########################
# Variables & Manifests #
#########################

GITHUB_ORG=$(gum input --placeholder "GitHub Organization" \
    --value "$GITHUB_ORG")

REGISTRY_SERVER=$(gum input \
    --placeholder "Container image registry server (e.g., ghcr.io)" \
    --value "$REGISTRY_SERVER")

REGISTRY_USER=$(gum input \
    --placeholder "Container image registry username (e.g., vfarcic)" \
    --value "$REGISTRY_USER")

REGISTRY_PASSWORD=$(gum input \
    --placeholder "Container image registry password (e.g., YouWillNeverFindOut)" \
    --value "$REGISTRY_PASSWORD")

# echo
# echo "## Which Hyperscaler do you want to use?" | gum format
# echo
# echo "Only Google Cloud and AWS are currently supported by this script. Please open an issue if you'd like to add others."

# HYPERSCALER=$(gum choose "google" "aws")

echo "export HYPERSCALER=$HYPERSCALER" >> .env

yq --inplace \
    ".spec.build.srcRepo.url = \"https://github.com/$GITHUB_ORG/crossplane-openfunction-dapr-demo\"" \
    function.yaml

yq --inplace ".spec.image = \"$REGISTRY_SERVER/$REGISTRY_USER/crossplane-openfunction-dapr-demo:v0.0.1\"" \
    function.yaml

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

kubectl apply --filename crossplane-packages/dot-sql.yaml

kubectl apply \
    --filename crossplane-packages/kubernetes-incluster.yaml

kubectl apply --filename crossplane-packages/helm-incluster.yaml

echo "## Waiting for Crossplane Packages..." | gum format

sleep 60

kubectl wait --for=condition=healthy provider.pkg.crossplane.io \
    --all --timeout=600s

if [[ "$HYPERSCALER" == "google" ]]; then

    gcloud auth login

    set +e
    gcloud components install gke-gcloud-auth-plugin
    set -e

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

echo "## Open https://console.cloud.google.com/apis/library/sqladmin.googleapis.com?project=$PROJECT_ID in a browser and *ENABLE* the API." \
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
        --from-file creds=./aws-creds.conf \
        --from-literal accessKeyID=$AWS_ACCESS_KEY_ID \
        --from-literal secretAccessKey=$AWS_SECRET_ACCESS_KEY
    
    kubectl apply \
        --filename crossplane-packages/aws-config.yaml

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

    echo "{\".dockerconfigjson\": $REGISTRY_AUTH }" \
        | gcloud secrets --project $PROJECT_ID \
        create registry-auth --data-file=-

elif [[ "$HYPERSCALER" == "aws" ]]; then

    set +e
    aws secretsmanager create-secret \
        --name registry-auth --region us-east-1 \
        --secret-string "{\".dockerconfigjson\": $REGISTRY_AUTH }"
    set -e

fi

##################
# Atlas Operator #
##################

helm upgrade --install atlas-operator \
    oci://ghcr.io/ariga/charts/atlas-operator \
    --namespace atlas-operator --create-namespace --wait

####################
# External Secrets #
####################

helm upgrade --install \
    external-secrets external-secrets/external-secrets \
    --namespace external-secrets --create-namespace --wait

if [[ "$HYPERSCALER" == "google" ]]; then

    yq --inplace \
        ".spec.provider.gcpsm.projectID = \"$PROJECT_ID\"" \
        external-secrets/google.yaml

    echo "{\"password\": \"IWillNeverTell\" }" \
        | gcloud secrets --project $PROJECT_ID \
        create db-password --data-file=-

elif [[ "$HYPERSCALER" == "aws" ]]; then

    set +e
    aws secretsmanager create-secret \
        --name db-password --region us-east-1 \
        --secret-string "{\"password\": \"IWillNeverTell\" }"
    set -e

fi

kubectl apply --filename external-secrets/$HYPERSCALER.yaml
