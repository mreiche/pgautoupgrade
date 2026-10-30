#!/usr/bin/env sh

flavor=${FLAVOR:-alpine}

docker build \
  -f ${flavor}.Dockerfile \
  -t pgautoupgrade-${flavor}:latest \
   .

