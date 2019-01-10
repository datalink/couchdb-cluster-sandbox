FROM alpine:edge

RUN apk --no-cache add \
    curl \
    jq

COPY docker-entrypoint.sh /docker-entrypoint.sh

CMD [ "/docker-entrypoint.sh" ]