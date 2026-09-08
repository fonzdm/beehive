ARG UPSTREAM_IMAGE=beehive/ditto-relay:upstream
FROM ${UPSTREAM_IMAGE}
LABEL org.opencontainers.image.source="https://github.com/fonzdm/beehive"
LABEL org.opencontainers.image.description="Pinned Ditto Relay with persistent server identity bootstrap"
COPY --chown=1000:1000 bootstrap.ts /app/bootstrap.ts
CMD ["bun", "/app/bootstrap.ts"]
