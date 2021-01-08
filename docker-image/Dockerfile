# https://aws.amazon.com/blogs/aws/new-for-aws-lambda-container-image-support/

# Define global args
ARG FUNCTION_DIR="/home/app/"
ARG RUNTIME_VERSION="3.9"
ARG DISTRO_VERSION="3.12"


# Stage 1 - bundle base image + runtime

# Grab a fresh copy of the image
FROM python:${RUNTIME_VERSION}-alpine${DISTRO_VERSION} AS python-alpine

# Install GCC (Alpine uses musl but we compile and link dependencies with GCC)
RUN apk add --no-cache \
    libstdc++

# Need these for poetry to work: https://stackoverflow.com/questions/53835198/integrating-python-poetry-with-docker
RUN apk add --no-cache \
    gcc \
    libffi-dev \
    musl-dev \
    openssl-dev

RUN apk add --no-cache \
    brotli

# Stage 2 - build function and dependencies
FROM python-alpine AS build-image
# Install aws-lambda-cpp build dependencies
RUN apk add --no-cache \
    build-base \
    libtool \
    autoconf \
    automake \
    libexecinfo-dev \
    make \
    cmake \
    libcurl

# Include global args in this stage of the build
ARG FUNCTION_DIR
ARG RUNTIME_VERSION

# Create function directory
RUN mkdir -p ${FUNCTION_DIR}
RUN chmod a+rwx ${FUNCTION_DIR}

# Optional – Install the function's dependencies
# RUN python${RUNTIME_VERSION} -m pip install -r requirements.txt --target ${FUNCTION_DIR}
# Install Lambda Runtime Interface Client for Python
RUN python${RUNTIME_VERSION} -m pip install awslambdaric --target ${FUNCTION_DIR}

# Stage 3 - final runtime image
# Grab a fresh copy of the Python image
FROM python-alpine

ARG FUNCTION_DIR

# install libreoffice (https://github.com/renothing/docker-libreoffice)
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories \
    && apk update \
    && apk add --no-cache \
        openjdk8 \
        tzdata \
        libreoffice
# ^ sed: can't create temp file '/etc/apk/repositoriesXXXXXX': Permission denied

WORKDIR ${FUNCTION_DIR}

COPY app/app.py app.py

# Sequencing is important here
RUN pip install poetry

COPY pyproject.toml ./

# COPY poetry.lock /app/

RUN poetry config virtualenvs.create false
RUN poetry install --no-interaction  # --no-dev

# Copy in the built dependencies
COPY --from=build-image ${FUNCTION_DIR} ${FUNCTION_DIR}

COPY entry.sh /
RUN chmod u+x /entry.sh

COPY test-template.docx /tmp/

# # Create a group and user (https://stackoverflow.com/questions/49955097/how-do-i-add-a-user-when-im-using-alpine-as-a-base-image)
# RUN addgroup --system worker_group \
#     && adduser \
#         --disabled-password \
#         --system \
#         --ingroup worker_group \
#         --home ${FUNCTION_DIR} \
#         app
# USER worker
# ^ this fails

ENTRYPOINT [ "/entry.sh" ]

CMD [ "app.handler" ]
