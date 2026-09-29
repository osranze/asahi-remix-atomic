ARG BASE_IMAGE

FROM scratch AS ctx

COPY ctx /

ARG BASE_IMAGE
FROM ${BASE_IMAGE}

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/run \
    --mount=type=cache,dst=/var/cache \
    --mount=type=tmpfs,dst=/var/log \
    --mount=type=tmpfs,dst=/var/lib \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/desktop/01.base.sh

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/run \
    --mount=type=cache,dst=/var/cache \
    --mount=type=tmpfs,dst=/var/log \
    --mount=type=tmpfs,dst=/var/lib \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/desktop/02.asahi.sh

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/run \
    --mount=type=cache,dst=/var/cache \
    --mount=type=tmpfs,dst=/var/log \
    --mount=type=tmpfs,dst=/var/lib \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/desktop/03.desktop.sh

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/run \
    --mount=type=cache,dst=/var/cache \
    --mount=type=tmpfs,dst=/var/log \
    --mount=type=tmpfs,dst=/var/lib \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/desktop/04.misc.sh

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/run \
    --mount=type=cache,dst=/var/cache \
    --mount=type=tmpfs,dst=/var/log \
    --mount=type=tmpfs,dst=/var/lib \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/desktop/05.initramfs.sh

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/run \
    --mount=type=cache,dst=/var/cache \
    --mount=type=tmpfs,dst=/var/log \
    --mount=type=tmpfs,dst=/var/lib \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/desktop/99.cleanup.sh

RUN bootc container lint --no-truncate

LABEL containers.bootc 1

ENV container=oci
STOPSIGNAL SIGRTMIN+3

CMD ["/sbin/init"]
