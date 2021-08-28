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

  *)
    echo "Command $1 not implemented, exiting..."
esac