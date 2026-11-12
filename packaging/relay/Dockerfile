# SPDX-License-Identifier: GPL-3.0-or-later
# The PocketDesk relay in a small container. Build from the repository root:
#   docker build -f packaging/relay/Dockerfile -t pocketdesk-relay .
#   docker run -d --restart=always -p 443:47900 -p 47900:47900 pocketdesk-relay
FROM rust:1-alpine AS build
RUN apk add --no-cache musl-dev
WORKDIR /src
COPY relay/ .
RUN cargo build --release --locked

FROM scratch
COPY --from=build /src/target/release/pocketdesk-relay /pocketdesk-relay
ENV RUST_LOG=info
EXPOSE 47900
USER 65534
ENTRYPOINT ["/pocketdesk-relay", "--listen", "0.0.0.0:47900"]
