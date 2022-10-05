# source: https://github.com/chemidy/smallest-secured-golang-docker-image/blob/master/docker/scratch.Dockerfile

ARG _GOVERSION

FROM golang:${_GOVERSION:+${_GOVERSION}-}alpine AS builder
RUN apk update && apk add --no-cache git ca-certificates tzdata make && update-ca-certificates

# Create appuser
ENV USER=appuser
ENV UID=10001

# See https://stackoverflow.com/a/55757473/12429735
RUN adduser \
    --disabled-password \
    --gecos "" \
    --home "/nonexistent" \
    --shell "/sbin/nologin" \
    --no-create-home \
    --uid "${UID}" \
    "${USER}"

WORKDIR /workspace
COPY . /workspace

ARG _VERSION
RUN BUILD_OUTPUT=/workspace/out VERSION=${_VERSION} make build


FROM alpine
# Import from builder.
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /etc/passwd /etc/passwd
COPY --from=builder /etc/group /etc/group

WORKDIR /app
COPY --from=builder /workspace/out /app/out
COPY ./static /app/static

# Use an unprivileged user.
USER appuser:appuser

ENTRYPOINT ["/app/out"]
