FROM ubuntu:20.04

ENV CHROMIUM_DIR "/srv/chromium"

RUN dpkg --add-architecture i386

RUN apt-get update &&\
    DEBIAN_FRONTEND=noninteractive \
    apt-get -f -y install sudo lsb-release cl-base64 bash wget apt-utils ccache jq python3 \
    python-is-python3 sed tzdata build-essential lib32gcc-9-dev g++-multilib dos2unix wiggle git curl

RUN mkdir ${CHROMIUM_DIR}

RUN curl -s https://raw.githubusercontent.com/chromium/chromium/123.0.6312.86/build/install-build-deps.py \
       | python - --android --lib32 --no-chromeos-fonts --no-prompt

RUN git config --global user.name "John Doe"
RUN git config --global user.email "johndoe@example.com"
RUN git config --global --add safe.directory "*"

WORKDIR ${CHROMIUM_DIR}

ENTRYPOINT /bin/bash
