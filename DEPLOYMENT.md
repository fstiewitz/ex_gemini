# Gemini Deployment on Docker

Deployment via docker is the recommended method.

## Creating volumes
`ex_gemini` needs a config file, server certificate (+ key) and the data you are hosting.

- Step 1: Create a volume

        docker volume create ex_gemini_config

- Step 2: Prepare config folder

        mkdir docker-config
        cd docker-config
        cp ../config/config.dev.exs config.exs

Now edit `config.exs` and update `:sites` to suit your needs. Copy any files you serve to the config folder. Use absolute paths.

- Step 3: Copy data into volume

My preferred method:

        docker run --rm -v "$PWD":/src -v ex_gemini_config:/dest  alpine /bin/sh -c 'cp -v /src/* /dest/'

## Simple deployment

It is preferred to use `docker-compose` because then you can store certificate and keyfile as secrets. Nevertheless, here is a
simple deployment procedure:

1. Create certificate

The first command may ask for a password, we'll remove it with the second command. Make sure the subject matches your desired hostname(s).

        openssl req -x509 -newkey rsa:4096 -keyout key-pw.pem -out server.pem -days 365 -subj '/CN=my-hostname'
        openssl rsa -in key-pw.pem -out key.pem

2. Create volume (see above) but copy `server.pem` and `key.pem` into the config folder and set `certfile` in `keyfile` in `config.exs` to their absolute final paths (`/config/server.pem` and `/config/key.pem`).

3. Create docker image

In project root:

        docker build . -t ex_gemini

4. Run docker container

        docker run -v ex_gemini_config:/config -p 1965:1965 ex_gemini

## As service with secrets
The recommended approach. Requires a `docker swarm`.

1. Create certificate (same as `Simple Deployment`)

The first command may ask for a password, we'll remove it with the second command. Make sure the subject matches your desired hostname(s).

        openssl req -x509 -newkey rsa:4096 -keyout key-pw.pem -out server.pem -days 365 -subj '/CN=my-hostname'
        openssl rsa -in key-pw.pem -out key.pem

2. Create secrets

The provided `docker-compose` file uses `ex_gemini_cert` and `ex_gemini_key`.

        cat server.pem | docker secret create ex_gemini_cert -
        cat key.pem | docker secret create ex_gemini_key -

3. Create volume (see above) but set `certfile` to `/run/secrets/ex_gemini_cert` and `keyfile` to `/run/secrets/ex_gemini_key`.

4. Deploy container

        docker stack deploy --compose-file docker-compose.yml ex_gemini

This configuration exposes port `1965` (the gemini port) on all swarm nodes.
