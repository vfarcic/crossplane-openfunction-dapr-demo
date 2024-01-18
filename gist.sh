#########
# Setup #
#########

# Create a remote Kubernetes cluster (do NOT use a local
#   cluster like Minikube, KinD, ...).

# Make sure that Docker Desktop is up-and-running.

# Install `pack` CLI by following the instructions at
#   https://buildpacks.io/docs/tools/pack/#pack-cli.

# Install `yq` CLI by following the instructions at
#   https://github.com/mikefarah/yq.

# Install `jq` CLI by following the instructions at
#   https://stedolan.github.io/jq/download.

# Replace `[...]` with your GitHub organization or user.
export GITHUB_ORG=[...]

# Replace `[...]` with your container image registry server
#   (e.g., `c8n.io/vfarcic`).
export REGISTRY_SERVER=[...]

# Replace `[...]` with your container image registry user.
export REGISTRY_USER=[...]

# Replace `[...]` with your container image registry password.
export REGISTRY_PASSWORD=[...]

git clone https://github.com/vfarcic/openfunction-demo

cd openfunction-demo

gh repo set-default

# Select the fork as the default repository

helm upgrade --install openfunction openfunction \
    --repo https://openfunction.github.io/charts \
    --namespace openfunction --create-namespace \
    --set revisionController.enable=true --wait

# Watch https://youtu.be/Ny9RxM6H6Hg if you are not familiar with
#   CloudNativePG (CNPG).
helm upgrade --install cnpg cloudnative-pg \
    --repo https://cloudnative-pg.github.io/charts \
    --namespace cnpg-system --create-namespace --wait

# Watch https://youtu.be/1iZoEFzlvhM if you are not familiar with
#   Atlas Operator.
helm upgrade --install atlas-operator \
    oci://ghcr.io/ariga/charts/atlas-operator \
    --namespace atlas-operator --create-namespace --wait

kubectl create namespace a-team

kubectl --namespace a-team create secret \
    docker-registry push-secret \
    --docker-server=$REGISTRY_SERVER \
    --docker-username=$REGISTRY_USER \
    --docker-password=$REGISTRY_PASSWORD

kubectl --namespace a-team apply --filename db.yaml

yq --inplace ".spec.build.srcRepo.url = \"https://github.com/$GITHUB_ORG/openfunction-demo.git\"" \
    function.yaml

yq --inplace ".spec.image = \"$REGISTRY_SERVER/openfunction-demo:v0.0.1\"" \
    function.yaml

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

# Destroy the cluster
