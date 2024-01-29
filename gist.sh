# FIXME: Serverless: Here's source code, build it and run it. Scale it up and down depending on the load.

# FIXME: Reference to the OpenFunction and Dapr videos.

cat function.yaml

# FIXME: Which cluster it runs in? Who created it? Can anyone create it?

# FIXME: `spec.imageCredentials.name`: how did those credentials get into the cluster?

# FIXME: Which database it uses? Who created it? Can anyone create it?

# FIXME: `STATESTORE_NAME` env: How was it created? Who created it?

# FIXME: It's all about being autonomous hence, we need Kubernetes-as-a-Service and Database-as-a-Service.

#########
# Setup #
#########

# FIXME: Change the status of `app-openfunction` resources

# Make sure that Docker Desktop is up-and-running.

git clone \
    https://github.com/vfarcic/crossplane-openfunction-dapr-demo

cd crossplane-openfunction-dapr-demo

# Replace `[...]` with hyperscaler you'd like to use. Choices are: `aws` and `google`.
export HYPERSCALER=[...]

# Nix Shell will install all the tools required for this demo
#   (except Docker).
# Watch FIXME: if you are not familiar with Nix.
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

kubectl --namespace production get components

##########################################
# Kubernetes Functions With OpenFunction #
##########################################

 cat function.yaml

kubectl --namespace production apply --filename function.yaml

kubectl --namespace production get functions

kubectl --namespace production get function openfunction-demo \
    --output jsonpath='{.status.addresses}' | jq .

export EXTERNAL_URL=$(kubectl --namespace production get routes \
    --output jsonpath='{.items[0].status.url}')

curl "$EXTERNAL_URL"

curl -X POST "$EXTERNAL_URL/video?id=1&title=An%20Amazing%20Video"

curl "$EXTERNAL_URL/videos" | jq .

kubectl --namespace production get pods

# FIXME: Wait for a while

kubectl --namespace production get pods

curl "$EXTERNAL_URL/videos" | jq .

kubectl --namespace production get pods

cat video.go

# FIXME: From here on, just push changes to the Git repo and keep changing the versions in `function.yaml`. Just don't push it to my repo :)

###########
# Destroy #
###########

chmod +x destroy.sh

./destroy.sh

exit