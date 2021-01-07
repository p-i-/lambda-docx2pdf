#!/bin/bash

# change to script's containing folder, and store it
cd `dirname "$0"`
SCRIPT_ROOT=`pwd -P`

all_args="$@"

cmd=$1
env_type=${2:-local}  # (local) | staging | production

AWS_ECR_REPO_NAME=ls-lambda
DOCKER_IMAGE_TAG=ls-lambda-${env_type}
DOCKER_RUNNING_CONTAINER_NAME=ls-lambda-${env_type}

yellow "AWS_ECR_REPO_NAME: $AWS_ECR_REPO_NAME"
yellow "DOCKER_IMAGE_TAG: $DOCKER_IMAGE_TAG"
yellow "DOCKER_RUNNING_CONTAINER_NAME: $DOCKER_RUNNING_CONTAINER_NAME"

repo_info=$( aws ecr describe-repositories --repository-names $AWS_ECR_REPO_NAME | jq -r '.repositories[0]' )

lambda_arn=$( echo "$repo_info" | jq -r '.repositoryArn' )  # e.g. arn:aws:ecr:us-east-1:795730031374:repository/ls-lambda
lambda_uri=$( echo "$repo_info" | jq -r '.repositoryUri' )  # e.g. 795730031374.dkr.ecr.us-east-1.amazonaws.com/ls-lambda
lambda_uri="795730031374.dkr.ecr.us-east-1.amazonaws.com"

echo -e "${GREEN}Lambda ARN: ${YELLOW}$lambda_arn"
echo -e "${GREEN}Lambda URI: ${YELLOW}$lambda_uri"

# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
#  S W I T C H B O A R D
# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

main() {
    # `set -v` (rather than -x) to echo commands
    # `set -e` to quit on error
    # `set -a` to store all defined vars in shell environment
    # (use + to OFF the flag)
    set -e

    if [ -z $cmd ] || [  $cmd = "help" ]; then
        green "`cat << EOF
Syntax:
    magic.sh Command [EnvType] [Options]

    EnvType: (local) staging production

    Command:
        build local|staging|production
            - builds image
            - runs it
            - tests with curl

        build-and-deploy staging|production
            - builds image
            - runs it
            - tests with curl
            - deploys to AWS
            - tests with curl
EOF
        `"
        exit 0
    fi

    check_cli_tools

    # # .env is always generated at project root
    # # Django looks for {project-root}/.env
    # # Docker Image for localdev copies this .env
    # generate_and_load_env .env
    # echo -en $YELLOW
    # cat .env
    # echo -en $RESET

    if [ $cmd = "setup" ]; then
        setup

    elif [ $cmd = "build" ]; then
        build

    elif [ $cmd = "build-and-deploy" ]; then
        build_and_deploy

    else
        red "Unknown command. 'magic.sh help' for available commands."
    fi
}

# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
#  H E L P E R S
# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

# Color helper functions

# https://stackoverflow.com/questions/5947742/how-to-change-the-output-color-of-echo-in-linux
PURPLE='\033[0;35m'
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'

BOLD='\033[1m'
RESET='\033[0m'  # No Color

red() {
    echo -e "\n${RED}$1${RESET}"
}

purple() {
    echo -e "\n${PURPLE}$1${RESET}"
}

green() {
    echo -e "${GREEN}$1${RESET}"
}

blue() {
    echo -e "${BLUE}$1${RESET}"
}

yellow() {
    echo -e "${YELLOW}$1${RESET}"
}

# - - - - - - -

🌷() {
    echo -en ${YELLOW}
    printf '\n🌷 %s\n' "$*"  # >&2 makes pipes work, even tho' they don't print properly
    echo -en ${RESET}
    "$@"
}

# - - - - - - -

assert_exists () {
    if hash $1 2>/dev/null; then
        green "$1 exists"
    else
        red "Fatal Error: $1 does not exist" >&2
        exit 1
    fi
}

check_cli_tools() {
    purple "Checking CLI tools"

    assert_exists docker
    assert_exists aws
    # assert_exists eksctl
}

# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

setup_one_time() {
    aws ecr create-repository --repository-name $AWS_ECR_REPO_NAME
}

# - - - - - - -

setup_one_time_per_devbox() {
    purple "One time!"

    mkdir -p ~/.aws-lambda-rie

    curl -Lo ~/.aws-lambda-rie/aws-lambda-rie \
        https://github.com/aws/aws-lambda-runtime-interface-emulator/releases/latest/download/aws-lambda-rie

    chmod +x ~/.aws-lambda-rie/aws-lambda-rie
}

# - - - - - - -

setup() {
    echo "Empty"
}

# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

build() {
    cd docker-image

    purple "Building Docker image"
    🌷 docker build -t $DOCKER_IMAGE_TAG .  # --no-cache

    purple "Tagging Docker image"
    🌷 docker tag $DOCKER_IMAGE_TAG:latest \
        ${lambda_uri}/${AWS_ECR_REPO_NAME}:latest

    # remove if running container exists
    docker container inspect $DOCKER_RUNNING_CONTAINER_NAME >/dev/null \
        && 🌷 docker rm -f $DOCKER_RUNNING_CONTAINER_NAME

    # purple "Running Docker image in bg"
    # 🌷 docker run -p 9000:8080 $DOCKER_IMAGE_TAG:latest &

    # purple "Running Docker image in daemon mode"
    # 🌷 docker run \
    #     -d \
    #     -e AWS_LAMBDA_RUNTIME_API=1 \
    #     --name $DOCKER_RUNNING_CONTAINER_NAME \
    #     -p 9000:8080 \
    #     $DOCKER_IMAGE_TAG:latest

    purple "Running Docker image in daemon mode"
    🌷 docker run -d \
        -v ~/.aws-lambda-rie:/aws-lambda \
        -p 9000:8080 \
        --name $DOCKER_RUNNING_CONTAINER_NAME \
        --entrypoint /aws-lambda/aws-lambda-rie \
        $DOCKER_IMAGE_TAG:latest \
            /entry.sh app.handler

    🌷 sleep 5

    purple "Testing endpoint"
    🌷 curl -XPOST "http://localhost:9000/2015-03-31/functions/function/invocations" -d '{}'

    purple "Deleting local Docker container instance"
    🌷 docker rm -f $DOCKER_RUNNING_CONTAINER_NAME
}

# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

deploy() {
    🌷 cd docker-image

    yellow "🌷 aws ecr get-login-password | docker login --username AWS --password-stdin $lambda_uri"  # Can't mix 🌷 with pipes
    aws ecr get-login-password | \
        docker login \
            --username AWS \
            --password-stdin \
            $lambda_uri

    🌷 docker push $lambda_uri/${AWS_ECR_REPO_NAME}:latest

    # TODO: Fix this:
    # aws lambda invoke --function-name lambda_to_pdf_converter --payload '{"filename":"test-template.docx"}' output.txt && cat output.txt
}

# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

main "$@"
