docker build \
  -f alpine.Dockerfile \
  --build-arg PGTARGET="18.6" \
  -t ghcr.io/mreiche/pgautoupgrade:latest \
   .
