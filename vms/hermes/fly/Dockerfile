ARG HERMES_BASE_IMAGE=the1000club-hermes-base:7426c09beee73bdff94d916015bac71384f6bc92
FROM ${HERMES_BASE_IMAGE}

ARG HERMES_GIT_SHA=7426c09beee73bdff94d916015bac71384f6bc92
USER root

RUN test "$(cat /opt/hermes/.hermes_build_sha)" = "$HERMES_GIT_SHA" \
    && /opt/hermes/.venv/bin/python -c 'import boto3'

COPY --chmod=0755 assets/*.py assets/*.sh /opt/hermes-pilot/
COPY assets/trainer /opt/hermes-pilot/trainer
COPY email-plugin /opt/hermes-pilot/email-plugin
COPY --chmod=0755 014-hermes-pilot /etc/cont-init.d/014-hermes-pilot
COPY --chmod=0755 s6/pilot-jobs/run /etc/s6-overlay/s6-rc.d/pilot-jobs/run
COPY --chmod=0644 s6/pilot-jobs/type /etc/s6-overlay/s6-rc.d/pilot-jobs/type
COPY --chmod=0644 s6/pilot-jobs/dependencies.d/base /etc/s6-overlay/s6-rc.d/pilot-jobs/dependencies.d/base
COPY --chmod=0644 s6/user/contents.d/pilot-jobs /etc/s6-overlay/s6-rc.d/user/contents.d/pilot-jobs

LABEL org.opencontainers.image.revision="$HERMES_GIT_SHA"

ENTRYPOINT ["/opt/hermes-pilot/fly-entrypoint.sh"]
CMD []
