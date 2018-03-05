# Run this in an intermediate container so the Compose cache is not contained in the
# final image.
FROM biigle/app AS intermediate

# Configure the timezone.
ARG TIMEZONE
RUN apk add --no-cache tzdata \
    && cp /usr/share/zoneinfo/${TIMEZONE} /etc/localtime \
    && echo "${TIMEZONE}" > /etc/timezone \
    && apk del tzdata

# Ignore platform reqs because the app image is stripped down to the essentials
# and doens't meet some of the requirements. We do this for the worker, though.
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
    && COMPOSER_SIGNATURE=$(curl -s https://composer.github.io/installer.sig) \
    && php -r "if (hash_file('SHA384', 'composer-setup.php') === '$COMPOSER_SIGNATURE') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;" \
    && php composer-setup.php --version=1.6.2 \
    && rm composer-setup.php

ENV COMPOSER_NO_INTERACTION 1
ENV COMPOSER_ALLOW_SUPERUSER 1

RUN php composer.phar config repositories.projects vcs https://github.com/BiodataMiningGroup/biigle-projects \
    && php composer.phar config repositories.label-trees vcs https://github.com/BiodataMiningGroup/biigle-label-trees \
    && php composer.phar config repositories.volumes vcs https://github.com/BiodataMiningGroup/biigle-volumes \
    && php composer.phar config repositories.annotations vcs https://github.com/BiodataMiningGroup/biigle-annotations \
    && php composer.phar config repositories.largo vcs https://github.com/BiodataMiningGroup/biigle-largo \
    && php composer.phar config repositories.export vcs https://github.com/BiodataMiningGroup/biigle-export \
    && php composer.phar config repositories.geo vcs https://github.com/BiodataMiningGroup/biigle-geo \
    && php composer.phar config repositories.color-sort vcs https://github.com/BiodataMiningGroup/biigle-color-sort \
    && php composer.phar config repositories.laserpoints vcs https://github.com/BiodataMiningGroup/biigle-laserpoints \
    && php composer.phar config repositories.ananas vcs https://github.com/BiodataMiningGroup/biigle-ananas

# Include the Composer cache directory to speed up the build.
COPY cache /root/.composer/cache

ARG GITHUB_OAUTH_TOKEN
ARG PROJECTS_VERSION=">=1.0"
ARG LABEL_TREES_VERSION=">=1.0"
ARG VOLUMES_VERSION=">=1.0"
ARG ANNOTATIONS_VERSION=">=1.0"
ARG LARGO_VERSION=">=1.0"
ARG EXPORT_VERSION=">=1.0"
ARG GEO_VERSION=">=1.0"
ARG COLOR_SORT_VERSION=">=1.0"
ARG LASERPOINTS_VERSION=">=1.0"
ARG ANANAS_VERSION=">=1.0"
RUN COMPOSER_AUTH="{\"github-oauth\":{\"github.com\":\"${GITHUB_OAUTH_TOKEN}\"}}" \
    php composer.phar require \
    biigle/projects:${PROJECTS_VERSION} \
    biigle/label-trees:${LABEL_TREES_VERSION} \
    biigle/volumes:${VOLUMES_VERSION} \
    biigle/annotations:${ANNOTATIONS_VERSION} \
    biigle/largo:${LARGO_VERSION} \
    biigle/export:${EXPORT_VERSION} \
    biigle/geo:${GEO_VERSION} \
    biigle/color-sort:${COLOR_SORT_VERSION} \
    biigle/laserpoints:${LASERPOINTS_VERSION} \
    biigle/ananas:${ANANAS_VERSION} \
    --prefer-dist --update-no-dev --ignore-platform-reqs

RUN sed -i '/Insert Biigle module service providers/i Biigle\\Modules\\Projects\\ProjectsServiceProvider::class,' config/app.php \
    && sed -i '/Insert Biigle module service providers/i Biigle\\Modules\\LabelTrees\\LabelTreesServiceProvider::class,' config/app.php \
    && sed -i '/Insert Biigle module service providers/i Biigle\\Modules\\Volumes\\VolumesServiceProvider::class,' config/app.php \
    && sed -i '/Insert Biigle module service providers/i Biigle\\Modules\\Annotations\\AnnotationsServiceProvider::class,' config/app.php \
    && sed -i '/Insert Biigle module service providers/i Biigle\\Modules\\Largo\\LargoServiceProvider::class,' config/app.php \
    && sed -i '/Insert Biigle module service providers/i Biigle\\Modules\\Export\\ExportServiceProvider::class,' config/app.php \
    && sed -i '/Insert Biigle module service providers/i Biigle\\Modules\\Geo\\GeoServiceProvider::class,' config/app.php \
    && sed -i '/Insert Biigle module service providers/i Biigle\\Modules\\ColorSort\\ColorSortServiceProvider::class,' config/app.php \
    && sed -i '/Insert Biigle module service providers/i Biigle\\Modules\\Laserpoints\\LaserpointsServiceProvider::class,' config/app.php \
    && sed -i '/Insert Biigle module service providers/i Biigle\\Modules\\Ananas\\AnanasServiceProvider::class,' config/app.php

RUN php artisan projects:publish \
    && php artisan label-trees:publish \
    && php artisan volumes:publish \
    && php artisan annotations:publish \
    && php artisan largo:publish \
    && php artisan export:publish \
    && php artisan geo:publish \
    && php artisan color-sort:publish \
    && php artisan laserpoints:publish \
    && php artisan ananas:publish

RUN php composer.phar dump-autoload -o \
    && rm composer.phar

RUN php /var/www/artisan route:cache

COPY .env /var/www/.env
RUN php /var/www/artisan config:cache && rm /var/www/.env

# --- END intermediate ---

FROM biigle/app
MAINTAINER Martin Zurowietz <martin@cebitec.uni-bielefeld.de>

ARG TIMEZONE
COPY --from=intermediate /etc/localtime /etc/localtime
RUN echo "${TIMEZONE}" > /etc/timezone

COPY --from=intermediate /var/www /var/www
