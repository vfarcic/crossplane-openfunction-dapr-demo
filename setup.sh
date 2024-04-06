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
|AWS account with admin permissions|If using AWS|'https://aws.amazon.com'                  |
|AWS CLI         |If using AWS         |'https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html'|

If you are running this script from **Nix shell**, most of the requirements are already set with the exception of **Docker** and the **AWS account**.
" | gum format

gum confirm "
Do you have those tools installed?
" || exit 0

rm -f .env

#########################
# Variables & Manifests #
#########################

echo "# Variables & Manifests" | gum format

REGISTRY_SERVER=$(gum input \
    --placeholder "Container image registry server (e.g., ghcr.io)" \
    --value "$REGISTRY_SERVER")

REGISTRY_USER=$(gum input \
    --placeholder "Container image registry username (e.g., vfarcic)" \
    --value "$REGISTRY_USER")

REGISTRY_PASSWORD=$(gum input \
    --placeholder "Container image registry password (e.g., YouWillNeverFindOut)" \
    --value "$REGISTRY_PASSWORD")

yq --inplace ".spec.image = \"$REGISTRY_SERVER/$REGISTRY_USER/crossplane-openfunction-dapr-demo:v0.0.1\"" \
    function.yaml

#########################
# Control Plane Cluster #
#########################

echo "# Control Plane Cluster" | gum format

eksctl create cluster --config-file eksctl.yaml

kubectl create namespace a-team

##############
# Crossplane #
##############

echo "# Crossplane" | gum format

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

############
# Registry #
############

echo "# Registry" | gum format

kubectl --namespace a-team \
    create secret docker-registry push-secret \
    --docker-server=$REGISTRY_SERVER \
    --docker-username=$REGISTRY_USER \
    --docker-password=$REGISTRY_PASSWORD

REGISTRY_AUTH=$(kubectl --namespace a-team \
    get secret push-secret \
    --output jsonpath='{.data.\.dockerconfigjson}' | base64 -d)

kubectl --namespace a-team delete secret push-secret

echo '## We are about to create a Secret in AWS Secret Manager. The command that follows will display output and you should press `q` to continue.' \
    | gum format
gum input --placeholder "Press the enter key to continue."
set +e
aws secretsmanager create-secret \
    --name registry-auth --region us-east-1 \
    --secret-string "{\".dockerconfigjson\": $REGISTRY_AUTH }"
set -e

##################
# Atlas Operator #
##################

echo "# Atlas Operator" | gum format

helm upgrade --install atlas-operator \
    oci://ghcr.io/ariga/charts/atlas-operator \
    --namespace atlas-operator --create-namespace --wait

####################
# External Secrets #
####################

echo "# External Secrets" | gum format

helm upgrade --install \
    external-secrets external-secrets/external-secrets \
    --namespace external-secrets --create-namespace --wait

echo '## We are about to create a Secret in AWS Secret Manager. The command that follows will display output and you should press `q` to continue.' \
    | gum format
gum input --placeholder "Press the enter key to continue."
set +e
aws secretsmanager create-secret \
    --name db-password --region us-east-1 \
    --secret-string "{\"password\": \"IWillNeverTell\" }"
set -e

kubectl apply --filename external-secrets/aws.yaml

#######################
# Crossplane (Part 2) #
#######################

echo "# Crossplane (Part 2)" | gum format

echo "## Waiting for Crossplane Packages (<= 20 min.)..." \
    | gum format

sleep 60

kubectl wait --for=condition=healthy provider.pkg.crossplane.io \
    --all --timeout=1200s

kubectl apply \
    --filename crossplane-packages/aws-config.yaml
