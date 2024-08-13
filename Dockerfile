FROM ubuntu:20.04

ENV CHROMIUM_DIR "/srv/chromium"
ENV CHROMIUM_VER "127.0.6533.103"

RUN dpkg --add-architecture i386

RUN apt-get update &&\
    DEBIAN_FRONTEND=noninteractive \
    apt-get -f -y install sudo lsb-release cl-base64 bash wget apt-utils ccache jq python3 \
    python-is-python3 sed tzdata build-essential lib32gcc-9-dev g++-multilib dos2unix wiggle git curl

RUN apt-get update &&\
    apt-get -y install p7zip-full

RUN mkdir ${CHROMIUM_DIR}

RUN curl -s https://raw.githubusercontent.com/chromium/chromium/${CHROMIUM_VER}/build/install-build-deps.py \
       | python - --android --lib32 --no-chromeos-fonts --no-prompt

RUN git config --global user.name "John Doe"
RUN git config --global user.email "johndoe@example.com"
RUN git config --global --add safe.directory "*"

WORKDIR ${CHROMIUM_DIR}

ENTRYPOINT /bin/bash
