# docker build . -t cosmwasm/wasmd:latest
# docker run --rm -it cosmwasm/wasmd:latest /bin/sh
FROM golang:1.14-alpine3.12 AS go-builder

# this comes from standard alpine nightly file
#  https://github.com/rust-lang/docker-rust-nightly/blob/master/alpine3.12/Dockerfile
# with some changes to support our toolchain, etc
RUN set -eux; apk add --no-cache ca-certificates build-base;

RUN apk add git
# NOTE: add these to run with LEDGER_ENABLED=true
# RUN apk add libusb-dev linux-headers

WORKDIR /code
COPY . /code/

# See https://github.com/CosmWasm/wasmvm/releases
ADD https://github.com/CosmWasm/wasmvm/releases/download/v0.12.0/libwasmvm_muslc.a /lib/libwasmvm_muslc.a
RUN sha256sum /lib/libwasmvm_muslc.a | grep 00ee24fefe094d919f5f83bf1b32948b1083245479dad8ccd5654c7204827765

# force it to use static lib (from above) not standard libgo_cosmwasm.so file
RUN LEDGER_ENABLED=false BUILD_TAGS=muslc make build
# we also (temporarily?) build the testnet binaries here
RUN LEDGER_ENABLED=false BUILD_TAGS=muslc make build-coral
RUN LEDGER_ENABLED=false BUILD_TAGS=muslc make build-gaiaflex

# --------------------------------------------------------
FROM alpine:3.12

COPY --from=go-builder /code/build/wasmd /usr/bin/wasmd

# testnet
COPY --from=go-builder /code/build/corald /usr/bin/corald
COPY --from=go-builder /code/build/gaiaflexd /usr/bin/gaiaflexd

COPY docker/* /opt/
RUN chmod +x /opt/*.sh

WORKDIR /opt

# rest server
EXPOSE 1317
# tendermint p2p
EXPOSE 26656
# tendermint rpc
EXPOSE 26657

CMD ["/usr/bin/wasmd version"]