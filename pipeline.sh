#!/bin/bash

# change to script's containing folder, and store it
cd `dirname "$0"`
SCRIPT_ROOT=`pwd -P`

all_args="$@"

cmd=$1
env_type=${2:-local}  # (local) | staging | production

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

    if [ $cmd = "build" ]; then
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

🌷() {
    echo -en ${YELLOW}
    printf '🌷 %s\n' "$*"
    echo -en ${RESET}
    "$@"
}

# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

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

setup() {
    purple "One time!"

    mkdir -p ~/.aws-lambda-rie

    curl -Lo ~/.aws-lambda-rie/aws-lambda-rie \
        https://github.com/aws/aws-lambda-runtime-interface-emulator/releases/latest/download/aws-lambda-rie

    chmod +x ~/.aws-lambda-rie/aws-lambda-rie
}

# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

build() {
    cd docker-image

    purple "Building Docker image"
    🌷 docker build -t lambda-test .  # --no-cache

    purple "Tagging Docker image"
    🌷 docker tag lambda-test:latest 795730031374.dkr.ecr.us-east-1.amazonaws.com/ls-lambda:latest

    docker rm -f FOO && :  # suppress exit-on-fail

    # purple "Running Docker image in bg"
    # 🌷 docker run \
    #     -d \
    #     -e AWS_LAMBDA_RUNTIME_API=1 \
    #     --name FOO \
    #     -p 9000:8080 lambda-test:latest
    #     # daemon mode

    # TODO: stop/remove any running container
    # docker ps
    # docker rm -f b82a8c23395b

    🌷 docker run -d \
        -v ~/.aws-lambda-rie:/aws-lambda \
        -p 9000:8080 --entrypoint /aws-lambda/aws-lambda-rie \
        lambda-test:latest \
            /entry.sh app.handler

    🌷 sleep 5

    purple "Testing endpoint"
    🌷 curl -XPOST "http://localhost:9000/2015-03-31/functions/function/invocations" -d '{}'
}

# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

build_and_deploy() {
    cd docker-image

    purple "Building Docker image"
    🌷 docker build -t lambda-test .  # --no-cache

    purple "Tagging Docker image"
    🌷 docker tag lambda-test:latest 795730031374.dkr.ecr.us-east-1.amazonaws.com/ls-lambda:latest

    # purple "Running Docker image in bg"
    # 🌷 docker run -p 9000:8080 lambda-test:latest &

    # TODO: Test this!
    # 🌷 docker login \
    #     --username AWS \
    #     --password-stdin \
    #     795730031374.dkr.ecr.us-east-1.amazonaws.com \
    #         << $( aws ecr get-login-password )

    aws ecr get-login-password | docker login \
        --username AWS \
        --password-stdin \
            795730031374.dkr.ecr.us-east-1.amazonaws.com

    🌷 docker push 795730031374.dkr.ecr.us-east-1.amazonaws.com/ls-lambda:latest

    repo_info=$( aws ecr describe-repositories --repository-names ls-lambda | jq -r '.repositories[0]' )
    # echo $repo_info | jq

    arn=$( echo "$repo_info" | jq -r '.repositoryArn' )
    uri=$( echo "$repo_info" | jq -r '.repositoryUri' )
    echo $arn
    echo $uri

    #aws lambda invoke --function-name lambda_to_pdf_converter --payload '{"filename":"test-template.docx"}' output.txt && cat output.txt
}

# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

main "$@"
