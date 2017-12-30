#!/bin/sh
ACTION="$1"
NAME="$2"

# helper functions
RESTORE='\033[0m'
RED='\033[00;31m'
GREEN='\033[00;32m'
YELLOW='\033[00;33m'
BLUE='\033[00;34m'
PURPLE='\033[00;35m'
CYAN='\033[00;36m'
LIGHTGRAY='\033[00;37m'

getImageVersion()
{
    imageUrl="$registerBaseUrl/$projectName/$1"
    gcloud container images list-tags $imageUrl --limit=1 | tail -1 | awk  '{print $2}'
}
getDeployedImageVersion(){
    imageUrl="$registerBaseUrl/$projectName/$1"
    if [ $# -eq 1 ]; then
        deploymentName="$1-deployment"
    else
        deploymentName=$2
    fi
    imageLength="$(echo $imageUrl: | wc -c)"
    kubectl describe deployment $deploymentName | grep -Go "$imageUrl:[a-zA-Z0-9]*" | awk -v l="$imageLength" '{print substr($0, l);}'
}
redeployIfVersionMismatch(){
    echo "\tchecking ${CYAN}$1${RESTORE} version"
    if [ $# -eq 1 ]; then
        deploymentName="$1-deployment"
        deployedImageTag="$(getDeployedImageVersion $1)"
    else
        deploymentName=$2
        deployedImageTag="$(getDeployedImageVersion $1 $2)"
    fi
    
    latestImageTag="$(getImageVersion $1)"
    
    if [ $latestImageTag == $deployedImageTag ]; then
        echo "\t\t${GREEN}✓${RESTORE} $1 image is up to date: $latestImageTag"
    else
        echo "\t\t${GREEN}↑${RESTORE} updating $1 image from $deployedImageTag to $latestImageTag"
        image="$registerBaseUrl/$projectName/$1:$latestImageTag"
        kubectl set image deployment/$deploymentName $1-container=$image
    fi
}

# print services
printServices()
{
    echo "${PURPLE}Services:${RESTORE}"
    kubectl get services
}

# print pods
printPods(){
    echo "${PURPLE}Pods:${RESTORE}"
    kubectl get pods
}

# redeploy pods
redeployPods(){
    echo "Redeploying ${PURPLE}$projectName${RESTORE}"

    redeployIfVersionMismatch $frontendImage
    redeployIfVersionMismatch $restApiImage

    echo "${GREEN}Done${RESTORE}"
}
scalePod(){
    echo "\tscaling ${CYAN}$1${RESTORE} to $2 instances"
    if [ $# -lt 3 ]; then
        deploymentName="$1-deployment"
    else
        deploymentName=$3
    fi
    
    kubectl scale --replicas=$2 deployment/$deploymentName
}
startPods(){
    echo "Starting ${PURPLE}$projectName${RESTORE}..."

    scalePod $frontendImage 3
    scalePod $restApiImage 1

}
stopPods(){
    echo "Stopping ${PURPLE}$projectName${RESTORE}..."
    scalePod $frontendImage 0
    scalePod $restApiImage 0
}
printHelp()
{
    echo "infrastructure.sh"
    echo "flags:"
    echo "\t${PURPLE}stop${RESTORE}"
    echo "\t\tstops all pods"
    echo "\t${PURPLE}start${RESTORE}"
    echo "\t\tstarts all pods"
    echo "\t${PURPLE}redeploy${RESTORE}"
    echo "\t\tredeploys the most recent image of each component (frontend, rest-api, mongo)"
    echo "\t${PURPLE}status${RESTORE}"
    echo "\t\tprints the status of pods and services"
    echo "\t${PURPLE}provision${RESTORE} cluster-1"
    echo "\t\tcreates a new cluster to deploy to"
}
createCluster(){
    clusterName="$1"
    if [ "$clusterName" == "" ]; then
        echo "${RED}error: ${RESTORE}please provide a name for the cluster as second argument"
    else
        echo "creating cluster"
        gcloud beta container --project $projectName clusters create "$clusterName" --zone "us-central1-a" --username="admin" --cluster-version "1.7.8-gke.0" --machine-type "n1-standard-2" --image-type "COS" --disk-size "100" --scopes "https://www.googleapis.com/auth/compute","https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" --num-nodes "4" --network "default" --enable-cloud-logging --enable-cloud-monitoring --subnetwork "default" --enable-legacy-authorization
        echo "${GREEN}Done${RESTORE}"
    fi
}
# setup variables
projectName="telefon-190611"
registerBaseUrl="gcr.io"

frontendImage="frontend"
restApiImage="rest-api"

case "$ACTION" in
    "start")
        startPods
    ;;
    "stop")
        stopPods
    ;;
    "redeploy")
        redeployPods
    ;;
    "status")
        printPods
        printServices
    ;;
    "provision")
        createCluster $NAME
    ;;
    "help")
        printHelp
    ;;
    *)
        echo "type ${PURPLE}help${RESTORE} to get help"
    ;;
esac