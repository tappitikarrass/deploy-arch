FROM archlinux:base

WORKDIR /deploy

COPY deploy.sh .
COPY settings.json .

RUN bash
