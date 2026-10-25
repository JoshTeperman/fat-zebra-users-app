# syntax=docker/dockerfile:1
# check=error=true

# Runs the API locally in development mode. Start it with compose.yaml:
#   docker compose up --build
# This image isn't built for production.

# Keep RUBY_VERSION in sync with .ruby-version and mise.toml.
ARG RUBY_VERSION=4.0.8
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

WORKDIR /rails

# jemalloc reduces Ruby's memory use and latency.
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y libjemalloc2 && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# All gem groups are installed: the development environment loads the development
# group at boot, and the gems in it are shared with test (so the specs can run here too).
ENV RAILS_ENV="development" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so"

# Build stage: compilers stay out of the final image.
FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    # -j 1 disables parallel compilation to avoid a QEMU bug: https://github.com/rails/bootsnap/issues/495
    bundle exec bootsnap precompile -j 1 --gemfile

COPY . .

# Precompile bootsnap's cache for faster boot.
RUN bundle exec bootsnap precompile -j 1 app/ lib/

# Final stage: runs as a non-root user that owns only the app and its gems.
FROM base

RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash
USER 1000:1000

COPY --chown=rails:rails --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --chown=rails:rails --from=build /rails /rails

EXPOSE 3000
CMD ["./bin/rails", "server", "-b", "0.0.0.0", "-p", "3000"]
