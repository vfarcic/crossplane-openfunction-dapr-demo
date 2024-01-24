#########
# Setup #
#########

# Make sure that Docker Desktop is up-and-running.

# Watch https://youtu.be/BII6ZY2Rnlc if you are not familiar with GitHub CLI (`gh`).
gh repo fork vfarcic/crossplane-openfunction-dapr-demo \
    --clone --remote

cd crossplane-openfunction-dapr-demo

gh repo set-default

# Select the fork as the default repository

# Replace `[...]` with hyperscaler you'd like to use. Choices are: `aws` and `google`.
export HYPERSCALER=[...]

# Watch FIXME: if you are not familiar with Nix.
# Nix Shell will install all the tools, except `gcloud` (if you
#    choose to use Google Cloud),)
# As an alternative, you can skip using Nix Shell but, in that
#   case you need to make sure that you are all the CLIs used in
#   this demo.
nix-shell --run $SHELL shell-$HYPERSCALER.nix

chmod +x setup.sh

./setup.sh

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
    --name a-team-cluster --kubeconfig $KUBECONFIG

helm ls --all-namespaces

# FIXME: Comment on what was installed

kubectl get namespaces

# FIXME: Comment on what was installed

kubectl --namespace crossplane-system get secrets

# FIXME: Comment on `aws-creds` or `gcp-creds`

kubectl get clustersecretstores

kubectl --namespace production \
    get externalsecrets.external-secrets.io

kubectl --namespace production get secrets

############
# Database #
############

cat db/$HYPERSCALER.yaml

unset KUBECONFIG

kubectl --namespace a-team apply --filename db/$HYPERSCALER.yaml

crossplane beta trace sqlclaim my-db --namespace a-team

export PGUSER=$(kubectl --namespace a-team \
    get secret my-db --output jsonpath="{.data.username}" \
    | base64 -d)

export PGPASSWORD=$(kubectl --namespace a-team \
    get secret my-db --output jsonpath="{.data.password}" \
    | base64 -d)

export PGHOST=$(kubectl --namespace a-team \
    get secret my-db --output jsonpath="{.data.endpoint}" \
    | base64 -d)

kubectl run postgresql-client --rm -ti --restart='Never' \
    --image docker.io/bitnami/postgresql:16 \
    --env PGPASSWORD=$PGPASSWORD --env PGHOST=$PGHOST \
    --env PGUSER=$PGUSER --command -- sh

psql --host $PGHOST -U $PGUSER -d postgres -p 5432

\l

\c my-db

\dt

exit

exit

kubectl --namespace a-team \
    get externalsecrets.external-secrets.io

kubectl --namespace a-team get secrets

kubectl --namespace a-team get pushsecrets

# Open the hyperscaler console and confirm that the secret with DB auth was pushed.

export KUBECONFIG=$PWD/kubeconfig.yaml

kubectl --namespace production \
    get externalsecrets.external-secrets.io

kubectl --namespace production get secrets

# FIXME: Create a video about Secrets

##########################################
# Kubernetes Functions With OpenFunction #
##########################################

# FIXME: Remove the whole section?

# FIXME: Move to the App Composition

cat function.yaml

kubectl --namespace production apply --filename function.yaml

kubectl --namespace production get functions

kubectl --namespace production get function openfunction-demo \
    --output jsonpath='{.status.addresses}' | jq .

kubectl --namespace production run curl \
    --image=radial/busyboxplus:curl -i --tty

# Replace `[...]` with the `Internal` URL.
curl "[...]"

exit

# Replace `[...]` with the `External` URL.
curl "[...]"

kubectl --namespace production get routes

# Replace `[...]` with the `URL`
export EXTERNAL_URL=[...]

# ...so let me store it as the environment variable and...

curl "$EXTERNAL_URL"

curl -X POST "$EXTERNAL_URL/video?id=1&title=An%20Amazing%20Video"

curl "$EXTERNAL_URL/videos" | jq .

kubectl --namespace production get pods

kubectl --namespace production get pods

kubectl --namespace production get pods

curl "$EXTERNAL_URL"

kubectl --namespace production get pods

#############################################
# Kubernetes Applications With OpenFunction #
#############################################

## Statestore component for Dapr
### Before applying this resource make sure to update the connection string with the right value from the secret, get the password by running: 

kubectl get secrets/openfunction-demo-db-app -n production --template={{.data.password}} | base64 -D

### Alternatively we can create a new secret to contain the whole connection string based on the secret called: openfunction-demo-db-app, that was created by PostgreSQL

kubectl --namespace production apply --filename dapr.yaml

# FIXME: Add `dapr.yaml` to the SQL Composition

cat app-no-build.yaml # The app-no-build.yaml contains references to the docker image that uses the Dapr APIs to connect to the configured Dapr Statestore

kubectl --namespace production apply --filename app-no-build.yaml

kubectl --namespace production get functions

kubectl --namespace production get all

## Getting URL 

kubectl get ksvc --namespace production

# Replace `[...]` with the `URL`
export EXTERNAL_URL=[...]

curl "$EXTERNAL_URL"

curl -X POST "$EXTERNAL_URL/video?id=1&title=An%20Amazing%20Video"

curl "$EXTERNAL_URL/videos" | jq .

###########
# Destroy #
###########

# FIXME: Remove `countour`.

chmod +x destroy.sh

./destroy.sh

exit