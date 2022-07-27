FROM golang:alpine AS build-env

RUN apk add --no-cache gcc libc-dev git && \
    mkdir -p /build/app /build/config && \
    git clone https://git.sr.ht/~emersion/soju
WORKDIR /go/soju
RUN git checkout v0.5.0 && \
    go build -o /build/app/soju ./cmd/soju/ && \
    go build -o /build/app/sojuctl ./cmd/sojuctl/

COPY entrypoint.sh /build/app/entrypoint.sh

FROM alpine:3.13.6
RUN apk add --no-cache bash ca-certificates openssl
WORKDIR /app
COPY --from=build-env /build/ /
CMD ["/app/entrypoint.sh"]
