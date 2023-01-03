FROM ubuntu:18.04

ENV CHROMIUM_DIR "/srv/chromium"
ENV DEBIAN_FRONTEND noninteractive

# Enable foreign architectures support
RUN dpkg --print-architecture && \
	dpkg --print-foreign-architectures

RUN dpkg --add-architecture i386 && \
	dpkg --print-foreign-architectures

# Install required packages
COPY packages.txt /packages.txt

RUN apt-get -qq update && \
    cat /packages.txt | xargs apt-get install -qqy

RUN rm /packages.txt

# Install and setup python 3.10 as default
RUN add-apt-repository -y ppa:deadsnakes/ppa

RUN apt-get -qq update && \
    apt-get install -qqy --no-install-recommends \
    python3.8 lib32z1 lighttpd xvfb libncurses5:i386 libstdc++6:i386 zlib1g:i386 ccache

RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.6 2
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.8 1
RUN update-alternatives  --set python3 /usr/bin/python3.8

# Install chromium build dependencies
RUN curl -s https://raw.githubusercontent.com/chromium/chromium/main/build/install-build-deps.sh \
    | perl -pe 's/apt-get install \$\{do_quietly-}/DEBIAN_FRONTEND=noninteractive apt-get install -y/' \
    | bash -e -s - \
    --no-syms --lib32 --no-arm --no-chromeos-fonts --no-nacl --no-prompt

RUN apt-get -f install

# Setup locale
RUN localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.UTF-8

RUN git config --global user.name "John Doe"
RUN git config --global user.email "johndoe@example.com"

RUN mkdir ${CHROMIUM_DIR}

WORKDIR ${CHROMIUM_DIR}

ENTRYPOINT /bin/bash
