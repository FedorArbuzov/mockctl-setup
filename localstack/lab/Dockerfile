FROM python:3.12-slim-bookworm

ARG TF_VERSION=1.9.8
ARG TARGETARCH

LABEL org.opencontainers.image.source="https://github.com/FedorArbuzov/mock-exams" \
      org.opencontainers.image.description="aws-terraform lab (Terraform + AWS CLI)"

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
         ca-certificates \
         curl \
         socat \
         unzip \
    && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    arch="${TARGETARCH:-$(uname -m)}"; \
    echo "TARGETARCH=${TARGETARCH:-} arch=${arch} uname=$(uname -m)"; \
    case "$arch" in \
      amd64|x86_64) aws_arch=x86_64; tf_arch=amd64 ;; \
      arm64|aarch64) aws_arch=aarch64; tf_arch=arm64 ;; \
      *) echo "unsupported arch=${arch}" >&2; exit 1 ;; \
    esac; \
    curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-${aws_arch}.zip" -o /tmp/awscliv2.zip; \
    unzip -q /tmp/awscliv2.zip -d /tmp; \
    /tmp/aws/install; \
    rm -rf /tmp/aws /tmp/awscliv2.zip; \
    /usr/local/bin/aws --version

RUN set -eux; \
    arch="${TARGETARCH:-$(uname -m)}"; \
    case "$arch" in \
      amd64|x86_64) tf_arch=amd64 ;; \
      arm64|aarch64) tf_arch=arm64 ;; \
      *) echo "unsupported arch=${arch}" >&2; exit 1 ;; \
    esac; \
    curl -fsSL "https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_${tf_arch}.zip" -o /tmp/tf.zip; \
    unzip -q /tmp/tf.zip -d /usr/local/bin; \
    rm /tmp/tf.zip; \
    /usr/local/bin/terraform version

COPY entrypoint.sh /entrypoint.sh
COPY verify-final.sh /usr/local/bin/verify-final
COPY lab-help /usr/local/bin/lab-help
RUN chmod +x /entrypoint.sh /usr/local/bin/verify-final /usr/local/bin/lab-help

WORKDIR /aws-labs
ENTRYPOINT ["/entrypoint.sh"]
CMD ["sleep", "infinity"]
