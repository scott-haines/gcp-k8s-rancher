FROM gitpod/workspace-full

USER gitpod

### Google Cloud ###
ARG GCS_DIR=/opt/google-cloud-sdk
ARG GCS_VER=245.0.0
ENV PATH=$GCS_DIR/bin:$PATH
RUN sudo chown gitpod: /opt \
    && mkdir $GCS_DIR \
    && curl -fsSL https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-${GCS_VER}-linux-x86_64.tar.gz \
    | tar -xzvC /opt \
    && /opt/google-cloud-sdk/install.sh --quiet --usage-reporting=false --bash-completion=true