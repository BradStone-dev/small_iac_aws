#!/bin/bash
sudo apt update -y && sudo apt upgrade -y
sudo apt install docker.io git -y
sudo systemctl enable docker
sudo systemctl start docker
git clone https://github.com/BradStone-dev/go-http-server
cd go-http-server
sudo docker build -t go-http-app .
sudo docker run -d -p 80:8080/tcp --restart=always --env MY_SPECIAL_DEBUG_VARIABLE=$1 --env MY_SPECIAL_VERSION=`git describe --tags --abbrev=0` go-http-app
