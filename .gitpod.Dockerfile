FROM gitpod/workspace-full

USER root

### jq ###
RUN apt-get update \
    && apt-get install -yq jq

USER gitpod

### Setup /opt ###
RUN sudo chown gitpod: /opt

### Google Cloud ###
ARG GCS_DIR=/opt/google-cloud-sdk
ARG GCS_VER=245.0.0
ENV PATH=$GCS_DIR/bin:$PATH
RUN mkdir $GCS_DIR \
    && curl -fsSL https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-${GCS_VER}-linux-x86_64.tar.gz \
    | tar -xzvC /opt \
    && /opt/google-cloud-sdk/install.sh --quiet --usage-reporting=false --bash-completion=true

### Terraform ###
ARG TF_DIR=/opt/terraform
ARG TF_VER=0.12.24
ENV PATH=$TF_DIR:$PATH
RUN mkdir $TF_DIR \
    && curl -OJ https://releases.hashicorp.com/terraform/${TF_VER}/terraform_${TF_VER}_linux_amd64.zip \
    && unzip terraform_${TF_VER}_linux_amd64.zip -d $TF_DIR \
    && rm terraform_${TF_VER}_linux_amd64.zip

### Kubectl ###
ARG K8S_DIR=/opt/kubernetes
ARG K8S_VER=v1.18.0
ENV PATH=$K8S_DIR:$PATH
RUN mkdir /usr/local/kubernetes/ && \
    curl -L https://storage.googleapis.com/kubernetes-release/release/${K8S_VER}/bin/linux/amd64/kubectl -o ${K8S_DIR}/kubectl \
    chmod +x ${K8S_DIR}/kubectl