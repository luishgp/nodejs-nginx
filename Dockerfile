ARG NODE_VERSION=lts

FROM node:${NODE_VERSION}-alpine

LABEL Maintainer="Luis Henrique Guimarães <contato@luishgp.com.br>" \
      Description="Lightweight container with Nginx & Nodejs based on Alpine Linux."

RUN apk update && apk add --no-cache \
    curl \
    git \
    supervisor \
    nginx \
    runit \
    openssh \
    zstd-libs \
    openssl \
# Bring in gettext so we can get `envsubst`, then throw
# the rest away. To do this, we need to install `gettext`
# then move `envsubst` out of the way so `gettext` can
# be deleted completely, then move `envsubst` back.
    && apk add --no-cache --virtual .gettext gettext \
    && mv /usr/bin/envsubst /tmp/ \
    && runDeps="$( \
        scanelf --needed --nobanner /tmp/envsubst \
            | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
            | sort -u \
            | xargs -r apk info --installed \
            | sort -u \
    )" \
    && apk add --no-cache $runDeps \
    && apk del .gettext \
    && mv /tmp/envsubst /usr/local/bin/ \
# Remove alpine cache
    && rm -rf /var/cache/apk/* \
# Remove default server definition
    && rm /etc/nginx/http.d/default.conf

ARG USERNAME=milkup
ARG USER_UID=1001
ARG USER_GID=$USER_UID

# Create system user to run Composer and Artisan Commands
RUN addgroup -g $USER_GID $USERNAME \
    && adduser -u $USER_UID -G $USERNAME -s /bin/bash -h /home/$USERNAME -D $USERNAME \
    && chown -R $USERNAME:$USERNAME /home/$USERNAME

# Add configuration files
COPY --chown=$USERNAME rootfs/ /

# Make sure files/folders needed by the processes are accessable when they run under the nobody user
RUN chown -R $USERNAME:$USERNAME /run \
    && chown -R $USERNAME:$USERNAME /usr \
    && chown -R $USERNAME:$USERNAME /var/lib/nginx \
    && chown -R $USERNAME:$USERNAME /var/log/nginx

# Production only dependencies, settings and paramteres

COPY scripts/02-envsubst-settings.sh /docker-entrypoint-init.d/02-envsubst-settings.sh

RUN \
    chown $USERNAME:$USERNAME /docker-entrypoint-init.d/02-envsubst-settings.sh \
    && chmod +x /docker-entrypoint-init.d/02-envsubst-settings.sh

# Add application
WORKDIR /var/www/html

# Switch to use a non-root user from here on
USER $USERNAME

RUN npm i -g pnpm

# Expose the port nginx is reachable on
EXPOSE 8080

# Let runit start nginx and node
CMD [ "/bin/docker-entrypoint.sh" ]

# Configure a healthcheck to validate that everything is up&running
HEALTHCHECK --timeout=5s CMD curl --silent --fail http://127.0.0.1:8080/