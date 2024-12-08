ARG BASE_IMAGE=php:cli-bookworm
FROM ${BASE_IMAGE}

ENV DEBIAN_FRONTEND=noninteractive

# install dependencies
# build-essential: for make
RUN apt-get update && apt-get install -y tzdata
RUN apt-get install -y --install-recommends \
    build-essential \
    vim \
	git \
	tini \
    && apt-get clean

# install dependency, make-do
WORKDIR /usr/local/
RUN git clone https://github.com/caracolazuldev/make-do.git
WORKDIR /usr/local/make-do
RUN make install
# clean-up
RUN rm -rf /usr/local/make-do/
