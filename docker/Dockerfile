
ARG BASE_IMAGE=deploy-php-app/system
FROM ${BASE_IMAGE}

RUN mkdir -p /var/www/conf
RUN mkdir -p /var/www/arch
RUN mkdir -p /var/www/html

COPY . /app

WORKDIR /app
ENTRYPOINT [ "tini", "--", "make" ]
CMD [ "help" ]
