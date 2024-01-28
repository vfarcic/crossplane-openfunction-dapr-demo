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
|kubectl CLI     |Yes                  |'https://kubernetes.io/docs/tasks/tools/#kubectl'  |
|kind CLI        |Yes                  |'https://kind.sigs.k8s.io/docs/user/quick-start/#installation'|
|Google Cloud CLI|If using Google Cloud|'https://cloud.google.com/sdk/docs/install'        |

If you are running this script from **Nix shell**, most of the requirements are already set with the exception of **Docker**.
" | gum format

gum confirm "
Do you have those tools installed?
" || exit 0

##############
# Crossplane #
##############

if [[ "$HYPERSCALER" == "aws" ]]; then

    aws eks update-kubeconfig --region us-east-1 \
        --name a-team-cluster --kubeconfig kubeconfig.yaml

    # Contour created a LoadBalancer Service which, in turn,
    #   created an AWS ELB. We need to delete the ELB to avoid
    #   deleting a cluster first and leaving the ELB behind.
    kubectl --kubeconfig kubeconfig.yaml \
        --namespace projectcontour delete service contour-envoy

fi

if [[ "$HYPERSCALER" == "google" ]]; then

    gcloud projects delete $PROJECT_ID --quiet

elif [[ "$HYPERSCALER" == "aws" ]]; then

    # Crossplane will delete the secret, but, by default, AWS
    #   only schedules it for deletion. 
    # The command that follows removes the secret immediately
    #   just in case you want to re-run the demo.
    aws secretsmanager delete-secret --secret-id my-db \
        --region us-east-1 --force-delete-without-recovery \
        --no-cli-pager

    kubectl --namespace a-team delete \
        --filename cluster/$HYPERSCALER.yaml

    kubectl --namespace a-team delete \
        --filename db/$HYPERSCALER.yaml

    COUNTER=$(kubectl get managed --no-headers | grep -v object \
        | grep -v release | grep -v database | wc -l)

    while [ $COUNTER -ne 0 ]; do
        echo "Waiting for all Crossplane managed resource to be deleted..."
        sleep 10
        COUNTER=$(kubectl get managed --no-headers | grep -v object \
            | grep -v release | grep -v database| wc -l)
    done

fi

kind delete cluster