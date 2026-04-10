# @see https://github.com/docker-library/drupal/blob/3c2ac6ffad4db2ec1b201893c5a6c0ff26239360/11.3/php8.4/apache-trixie/Dockerfile

# https://www.drupal.org/docs/system-requirements/php-requirements
FROM php:8.4-apache-trixie

ARG TARGETPLATFORM
RUN echo "I'm building for $TARGETPLATFORM"

ARG DEVOPSY_UID
ARG DEVOPSY_GID

# install the PHP extensions we need
RUN set -eux; \
  \
  if command -v a2enmod; then \
# https://github.com/drupal/drupal/blob/d91d8d0a6d3ffe5f0b6dde8c2fbe81404843edc5/.htaccess (references both mod_expires and mod_rewrite explicitly)
    a2enmod expires rewrite; \
  fi; \
  \
  apt-get update; \
  # These are my custom packages I want on app container
  apt-get install -y --no-install-recommends \
    git \
    telnet \
    iputils-ping \
    traceroute \
    wget \
    unzip \
    mariadb-client \
    nodejs \
    npm \
    tzdata \
    msmtp \
    msmtp-mta \
  ; \
  savedAptMark="$(apt-mark showmanual)"; \
  \
  apt-get install -y --no-install-recommends \
		libfreetype6-dev \
		libjpeg-dev \
		libpng-dev \
		libpq-dev \
		libwebp-dev \
		libzip-dev \
	; \
	\
	docker-php-ext-configure gd \
		--with-freetype \
		--with-jpeg=/usr \
		--with-webp \
	; \
	\
	docker-php-ext-install -j "$(nproc)" \
		gd \
		pdo_mysql \
		pdo_pgsql \
		zip \
	; \
	\
# reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
	apt-mark auto '.*' > /dev/null; \
	apt-mark manual $savedAptMark; \
	ldd "$(php -r 'echo ini_get("extension_dir");')"/*.so \
		| awk '/=>/ { so = $(NF-1); if (index(so, "/usr/local/") == 1) { next }; gsub("^/(usr/)?", "", so); printf "*%s\n", so }' \
		| sort -u \
		| xargs -r dpkg-query -S \
		| cut -d: -f1 \
		| sort -u \
		| xargs -rt apt-mark manual; \
	\
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	rm -rf /var/lib/apt/lists/*

# set recommended PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
RUN { \
		echo 'opcache.memory_consumption=128'; \
		echo 'opcache.interned_strings_buffer=8'; \
		echo 'opcache.max_accelerated_files=4000'; \
		echo 'opcache.revalidate_freq=60'; \
	} > /usr/local/etc/php/conf.d/opcache-recommended.ini

# https://www.drupal.org/node/3298550
# Drupal now recommends sites enable PHP output buffering by default, if PHP is run as a server module
# e.g. with Apache's mod_php
RUN { \
		echo 'output_buffering=true'; \
	} > /usr/local/etc/php/conf.d/docker-php-drupal-recommended.ini

COPY --from=composer:2 /usr/bin/composer /usr/local/bin/

# https://github.com/docker-library/drupal/pull/259
# https://github.com/moby/buildkit/issues/4503
# https://github.com/composer/composer/issues/11839
# https://github.com/composer/composer/issues/11854
# https://github.com/composer/composer/blob/94fe2945456df51e122a492b8d14ac4b54c1d2ce/src/Composer/Console/Application.php#L217-L218
ENV COMPOSER_ALLOW_SUPERUSER 1

ENV APACHE_DOCUMENT_ROOT /var/www/html/web
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf
RUN sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

ENV PATH="$PATH:/var/www/html/vendor/bin"

# RUN groupadd -g $DEVOPSY_GID mercados
# RUN useradd -u $DEVOPSY_UID -g mercados -s /bin/bash -d /home/mercados mercados
# RUN mkdir /home/mercados
# RUN chown mercados:mercados /home/mercados

# vim:set ft=dockerfile:

# create msmtprc ini for sendmail (uncomment and adjust as needed)
# Only for test purposes, for production use a proper mail server and secure the configuration.
#   RUN { \
#     echo 'defaults'; \
#     echo 'auth           off'; \
#     echo 'tls            off'; \
#     echo 'logfile        /tmp/msmtp.log'; \
#     echo ''; \
#     echo 'from user@mydomain.com'; \
#     echo 'account        mailpit'; \
#     echo 'host           mailpit'; \
#     echo 'port           1025'; \
#     echo 'account default : mailpit'; \
#   } > /etc/msmtprc
