FROM alpine:3.22

RUN apk add --no-cache bash findutils grep sed

COPY rename-find-replace.sh /usr/local/bin/rename-find-replace.sh
COPY .renamerignore /.renamerignore

RUN chmod +x /usr/local/bin/rename-find-replace.sh

WORKDIR /data

ENTRYPOINT ["/usr/local/bin/rename-find-replace.sh"]
