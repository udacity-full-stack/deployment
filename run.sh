#!/bin/bash
set -o nounset
set -o errexit

if [ ! -d venv ]; then
    python3 -m venv venv
fi

. venv/bin/activate

case $1 in

  install-deps)
    pip install -r requirements.txt
    ;;

  lint)
    pycodestyle app
    ;;

  test)
    cd app && pytest
    ;;

  format)
    black --line-length 79 app
    ;;

  start-dev)
    cd app && python main.py
    ;;

  kill-old-container)
    OLD_CONTAINER_ID="$(cat .run_status)"

    if [ ! -z ${OLD_CONTAINER_ID} ]; then
        echo "killing old container..."
        docker container stop ${OLD_CONTAINER_ID} > /dev/null || true 
        docker container rm ${OLD_CONTAINER_ID} > /dev/null || true
    fi

    echo "" > .run_status
    ;;

  build)
    docker build -t udacity_app_image .
    ;;

  start-container)
    ./run.sh build
    ./run.sh kill-old-container

    echo "starting new container..."
    NEW_CONTAINER_ID=$(docker run --name udacity_app_container --env-file=.env_file -p 80:8080 --detach -it udacity_app_image)

    echo "done"
    echo ${NEW_CONTAINER_ID} > .run_status
    ;;

  # ***********************************
  # **** AFTER DEPLOYMENT COMMANDS ****

  get-nodes)
    kubectl get nodes
    ;;

  get-endpoint)
    kubectl get services simple-jwt-api -o wide
    ;;

  # ********************************************* 
  # **** DEPLOYMENT COMMANDS (ORDER MATTERS) ****

  create-cluster)
    eksctl create cluster --name simple-jwt-api
    ;;

  create-role)
    aws iam create-role --role-name UdacityFlaskDeployCBKubectlRole --assume-role-policy-document file://deployment/trust.json --output text --query 'Role.Arn'
    aws iam put-role-policy --role-name UdacityFlaskDeployCBKubectlRole --policy-name eks-describe --policy-document file://deployment/iam-role-policy.json
    ;;

  get-cluster-config)
    kubectl get -n kube-system configmap/aws-auth -o yaml > ./deployment/aws-auth-patch.yml
    # the above will save the current config to deployment/aws-auth-patch.yml
    # modify it and add under data
        # mapRoles: |
        #     - groups:
        #         - system:masters
        #         rolearn: arn:aws:iam::<ACCOUNT_ID>:role/UdacityFlaskDeployCBKubectlRole
        #         username: build  
    ;;

  allow-role-to-access-cluster)
    kubectl patch configmap/aws-auth -n kube-system --patch "$(cat ./deployment/aws-auth-patch.yml)"
    ;;

  # NEXT: create a stack by using the template ci-cd-codepipeline.cfn.yml in the AWS CONSOLE

  set-secret) 
    #   usage: ./run.sh set-secret thisISaSECRET
    aws ssm put-parameter --name JWT_SECRET --overwrite --value "$2" --type SecureString
    ;;

  # *************************** 
  # **** CLEAN UP COMMANDS ****

  remove-cluster)
    eksctl delete cluster simple-jwt-api
    ;;

  remove-stack)
    aws cloudformation delete-stack --stack-name simple-jwt-api-pipeline
    ;;

  remove-secret)
    aws ssm delete-parameter --name JWT_SECRET
    ;;

  remove)
    ./run.sh remove-cluster
    ./run.sh remove-stack
    ./run.sh remove-secret
    ;;

  *)
    echo "Command $1 not implemented, exiting..."
esac