FROM alpine:edge

RUN apk --no-cache add \
    curl \
    jq

COPY cluster-init.sh /cluster-init.sh

CMD [ "/cluster-init.sh" ]