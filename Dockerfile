FROM swift:5.4-focal as build

SHELL ["/bin/bash", "-c"]

RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get -q update \
    && apt-get -q dist-upgrade -y \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build-app
COPY . .
RUN swift build -c release

WORKDIR /build-packages
COPY ./Resources/ProjectTemplate ./ProjectTemplate
RUN cd ProjectTemplate && swift build -c debug -j 1

WORKDIR /staging
RUN cp "$(swift build --package-path /build-app -c release --show-bin-path)/Run" ./
RUN [ -d /build-app/Public ] && { mv /build-app/Public ./Public && chmod -R a-w ./Public; } || true
RUN [ -d /build-app/Resources ] && { mv /build-app/Resources ./Resources; } || true
RUN shopt -s dotglob && \
    rm -r ./Resources/ProjectTemplate && mv /build-packages/ProjectTemplate ./Resources/. && \
    shopt -u dotglob

FROM swift:5.4-focal

RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true && \
    apt-get -q update && apt-get -q dist-upgrade -y && rm -r /var/lib/apt/lists/*
RUN useradd --user-group --create-home --system --skel /dev/null --home-dir /app vapor

WORKDIR /app
COPY --from=build --chown=vapor:vapor /staging /app

USER vapor:vapor
EXPOSE 8080

ENTRYPOINT ["./Run"]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]
