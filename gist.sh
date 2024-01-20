#########
# Setup #
#########

FIXME: Add secrets to AWS

FIXME: Test in AWS

FIXME: Add secrets to Azure

FIXME: Test in Azure

# Make sure that Docker Desktop is up-and-running.

# Watch https://youtu.be/BII6ZY2Rnlc if you are not familiar with GitHub CLI (`gh`).
gh repo fork vfarcic/crossplane-openfunction-dapr-demo \
    --clone --remote

cd crossplane-openfunction-dapr-demo

gh repo set-default

# Select the fork as the default repository

# Watch FIXME: if you are not familiar with Nix.
# As an alternative, you can skip using Nix Shell but, in that
#   case you need to make sure that you are all the CLIs used in
#   this demo.
nix-shell --run $SHELL

chmod +x setup.sh

./setup.sh

kubectl get clustersecretstores

# FIXME: Add it to the remote cluster
kubectl --namespace a-team apply --filename yyy.yaml






# FIXME: Move to the Compositions
kubectl --namespace a-team apply --filename db.yaml

# FIXME: Push DB secret to secret store from the control plane cluster

# FIXME: Pull DB secret from secret store to the apps cluster

# FIXME: Move to the script
yq --inplace ".spec.build.srcRepo.url = \"https://github.com/$GITHUB_ORG/openfunction-demo.git\"" \
    function.yaml

# FIXME: Move to the script
yq --inplace ".spec.image = \"$REGISTRY_SERVER/openfunction-demo:v0.0.1\"" \
    function.yaml

source .env

###########################
# Cluster with Everything #
###########################

# Open https://marketplace.upbound.io/configurations/devops-toolkit/dot-kubernetes/v0.12.3/xrds in a browser

cat cluster/$HYPERSCALER.yaml

kubectl --namespace a-team apply \
    --filename cluster/$HYPERSCALER.yaml

crossplane beta trace clusterclaim cluster --namespace a-team

# Wait until all the resources are available

export KUBECONFIG=$PWD/kubeconfig.yaml

# Execute only if using Google Cloud
gcloud container clusters get-credentials a-team-cluster \
    --region us-east1 --project $PROJECT_ID

# Execute only if using AWS
aws eks update-kubeconfig --region us-east-1 \
    --name cluster-01 --kubeconfig $KUBECONFIG

# Execute only if using Azure
az aks get-credentials --resource-group cluster-01 \
    --name cluster-01 --file $KUBECONFIG

kubectl get namespaces

helm ls --all-namespaces

kubectl get clustersecretstores

kubectl --namespace crossplane-system get externalsecrets

kubectl --namespace crossplane-system get secrets

#########################################
# Functions in Docker With OpenFunction #
#########################################

cat main.go

pack build openfunction-demo \
    --builder openfunction/builder-go:v2.4.0-1.17 \
    --env FUNC_NAME="SillyDemo" \
    --env FUNC_CLEAR_SOURCE=true

docker container run --name openfunction-demo \
    --env="FUNC_CONTEXT={\"name\":\"SillyDemo\",\"version\":\"v0.0.1\",\"port\":\"8080\",\"runtime\":\"Knative\"}" \
    --env="CONTEXT_MODE=self-host" --publish 8080:8080 --detach \
    openfunction-demo

curl "http://localhost:8080"

docker container rm openfunction-demo --force

##########################################
# Kubernetes Functions With OpenFunction #
##########################################

cat function.yaml

kubectl --namespace a-team apply --filename function.yaml

kubectl --namespace a-team get functions

kubectl --namespace a-team get function openfunction-demo \
    --output jsonpath='{.status.addresses}' | jq .

kubectl --namespace a-team run curl \
    --image=radial/busyboxplus:curl -i --tty

# Replace `[...]` with the `Internal` URL.
curl "[...]"

exit

# Replace `[...]` with the `External` URL.
curl "[...]"

kubectl --namespace a-team get routes

# Replace `[...]` with the `URL`
export EXTERNAL_URL=[...]

# ...so let me store it as the environment variable and...

curl "$EXTERNAL_URL"

curl -X POST "$EXTERNAL_URL/video?id=1&title=An%20Amazing%20Video"

curl "$EXTERNAL_URL/videos" | jq .

kubectl --namespace a-team get pods

kubectl --namespace a-team get pods

kubectl --namespace a-team get pods

curl "$EXTERNAL_URL"

kubectl --namespace a-team get pods

#############################################
# Kubernetes Applications With OpenFunction #
#############################################

## Statestore component for Dapr
### Before applying this resource make sure to update the connection string with the right value from the secret, get the password by running: 

kubectl get secrets/openfunction-demo-db-app -n a-team --template={{.data.password}} | base64 -D

### Alternatively we can create a new secret to contain the whole connection string based on the secret called: openfunction-demo-db-app, that was created by PostgreSQL

kubectl --namespace a-team apply --filename dapr.yaml

cat app-no-build.yaml # The app-no-build.yaml contains references to the docker image that uses the Dapr APIs to connect to the configured Dapr Statestore

kubectl --namespace a-team apply --filename app-no-build.yaml

kubectl --namespace a-team get functions

kubectl --namespace a-team get all

## Getting URL 

kubectl get ksvc --namespace a-team

# Replace `[...]` with the `URL`
export EXTERNAL_URL=[...]

curl "$EXTERNAL_URL"

curl -X POST "$EXTERNAL_URL/video?id=1&title=An%20Amazing%20Video"

curl "$EXTERNAL_URL/videos" | jq .

###########
# Destroy #
###########

chmod +x destroy.sh

./destroy.sh

exit