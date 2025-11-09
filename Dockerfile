FROM swift:6.2-jammy as build

RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get -q update \
    && apt-get -q dist-upgrade -y \
    && apt-get install -y libsqlite3-dev rsync libdispatch-dev clang \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
COPY ./Package.* ./
RUN swift package edit swift-certificates --revision 1.15.1
RUN swift package resolve
COPY . .
RUN swift build -c release --static-swift-stdlib \
    && (cd Resources/ProjectTemplate && swift build -c debug) \
    && (cd Resources/formatter && swift build --product swift-format -c release)

WORKDIR /staging
RUN cp "$(swift build --package-path /build -c release --show-bin-path)/App" ./ \
    && rsync -a --delete --include=".build" --include="App/" \
       --exclude="artifacts" --exclude="checkouts"  --exclude="plugins" --exclude="repositories" \
       --exclude="ModuleCache" --exclude="index" \
       --exclude="*.build" --exclude="*.bundle" --exclude="*.product" \
       --exclude="*.json" --exclude="*.o" --exclude="*.swiftsourceinfo" \
       --exclude="App" --exclude=".DS_Store" \
       /build/Resources/ ./Resources/

FROM swift:6.2-jammy

RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get -q update \
    && apt-get -q dist-upgrade -y \
    && apt-get -q install -y \
      ca-certificates \
      tzdata \
      libcurl4 \
      libxml2 \
      rsync \
    && rm -r /var/lib/apt/lists/*

RUN useradd --user-group --create-home --system --skel /dev/null --home-dir /app vapor

WORKDIR /app
COPY --from=build --chown=vapor:vapor /staging /app

USER vapor:vapor
EXPOSE 8080

ENTRYPOINT ["./App"]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]
