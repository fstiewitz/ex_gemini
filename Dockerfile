FROM elixir:1.11.4-alpine as build-stage
WORKDIR /app
COPY ./ .

ENV MIX_ENV=prod
RUN mix local.hex --force
RUN mix deps.get
RUN mix compile
RUN mix release --overwrite gemini_docker

FROM alpine:3 as production-stage

VOLUME /config

EXPOSE 1965

RUN mkdir /app
RUN apk add --no-cache ncurses
COPY --from=build-stage /app/_build/prod/rel/gemini_docker /app

CMD ["/app/bin/gemini_docker", "start"]
