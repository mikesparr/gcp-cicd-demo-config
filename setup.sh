#!/usr/bin/env bash

source .env # see README

# export PROJECT_ID=<from .env>
# export AUTH_NETWORK=<from .env>

export GCP_REGION=us-central1
export GCP_ZONE=us-central1-b
export CLUSTER_VERSION="1.16.13-gke.1"

# enable apis
gcloud services enable cloudbuild.googleapis.com \
    container.googleapis.com \
    storage.googleapis.com \
    containerregistry.googleapis.com

# authorize cloud build to connect to demo app Github repo (not config repo)
# https://console.cloud.google.com/cloud-build/triggers/connect?project=${PROJECT_ID}&provider=github_app

# helper functions
set_location () {
    case $1 in
        "west")
            export ZONE="us-west2-b"
            export REGION="us-west2"
            ;;
        "central")
            export ZONE="us-central1-a"
            export REGION="us-central1"
            ;;
        "east")
            export ZONE="us-east1-c"
            export REGION="us-east1"
            ;;
        *)
            echo $"Usage: $0 {west|central|east}"
            exit 1
    esac
}

install_argo_cd () {
    echo "Installing Argo CD ..."

    kubectl create clusterrolebinding cluster-admin-binding \
        --clusterrole=cluster-admin --user="$(gcloud config get-value account)"
    kubectl create namespace argocd
    kubectl apply -n argocd \
        -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

    # configure app-of-apps git repo
    echo "Configuring app-of-apps repo ..."
    kubectl apply -f app-of-apps.yaml
}

create_cluster () {
    CLUSTER_NAME=$1

    set_location $CLUSTER_NAME

    echo "Creating cluster $CLUSTER_NAME in zone $ZONE ..."

    gcloud beta container --project $PROJECT_ID clusters create "$CLUSTER_NAME" \
        --zone "$ZONE" \
        --no-enable-basic-auth \
        --cluster-version $CLUSTER_VERSION \
        --machine-type "e2-standard-2" \
        --image-type "COS" \
        --disk-type "pd-standard" --disk-size "100" \
        --node-labels location=west \
        --metadata disable-legacy-endpoints=true \
        --scopes "https://www.googleapis.com/auth/compute","https://www.googleapis.com/auth/devstorage.read_write","https://www.googleapis.com/auth/sqlservice.admin","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring","https://www.googleapis.com/auth/pubsub","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" \
        --preemptible \
        --num-nodes "1" \
        --enable-stackdriver-kubernetes \
        --enable-ip-alias \
        --network "projects/${PROJECT_ID}/global/networks/default" \
        --subnetwork "projects/${PROJECT_ID}/regions/${REGION}/subnetworks/default" \
        --default-max-pods-per-node "110" \
        --enable-autoscaling --min-nodes "0" --max-nodes "3" \
        --enable-network-policy \
        --enable-master-authorized-networks --master-authorized-networks $AUTH_NETWORK \
        --addons HorizontalPodAutoscaling,HttpLoadBalancing \
        --enable-autoupgrade \
        --enable-autorepair --max-surge-upgrade 1 --max-unavailable-upgrade 1 \
        --labels env=sandbox \
        --enable-vertical-pod-autoscaling \
        --enable-shielded-nodes \
        --shielded-secure-boot \
        --tags "k8s","$1"
    
    # authenticate
    echo "Authenticating kubectl ..."
    gcloud container clusters get-credentials $CLUSTER_NAME --zone $ZONE

    # install argo cd
    echo "Installing Argo CD ..."
    install_argo_cd

    echo "Cluster $CLUSTER_NAME created in zone $ZONE"
}

# create clusters
echo "Creating and configuring clusters ..."
locations=("central")
for loc in ${locations[@]}; do
    create_cluster $loc
done

# add kong
echo "Adding Kong Ingress install ..."
kubectl apply -f https://bit.ly/k4k8s --dry-run=client -o yaml > kong/01-install.yaml

# add cert-manager
echo "Adding Cert Manager install ..."
kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v0.16.1/cert-manager.yaml --dry-run=client -o yaml > cert-manager/01-install.yaml
