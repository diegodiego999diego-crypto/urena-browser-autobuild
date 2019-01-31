FROM ubuntu:18.04

ENV DEPOT_TOOLS "/depot_tools"
ENV PATH "$PATH:${DEPOT_TOOLS}"
ENV CHROMIUM_DIR "/srv/chromium"
ENV DEBIAN_FRONTEND noninteractive

COPY packages.txt /packages.txt

RUN apt-get -qq update && \
    cat /packages.txt | xargs apt-get install -qqy

RUN rm /packages.txt

RUN git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git ${DEPOT_TOOLS}

RUN mkdir ${CHROMIUM_DIR}

WORKDIR ${CHROMIUM_DIR}

ENTRYPOINT /bin/bash
