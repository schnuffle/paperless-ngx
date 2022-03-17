FROM ghcr.io/schnuffle/build-paperless-base-arm:latest

WORKDIR /usr/src/paperless/src/

# setup docker-specific things
COPY docker/ ./docker/

RUN cd docker \
  && cp imagemagick-policy.xml /etc/ImageMagick-6/policy.xml \
	&& mkdir /var/log/supervisord /var/run/supervisord \
	&& cp supervisord.conf /etc/supervisord.conf \
	&& cp docker-entrypoint.sh /sbin/docker-entrypoint.sh \
	&& cp docker-prepare.sh /sbin/docker-prepare.sh \
	&& chmod 755 /sbin/docker-entrypoint.sh \
	&& chmod +x install_management_commands.sh \
	&& ./install_management_commands.sh \
	&& cd .. \
	&& rm docker -rf

COPY gunicorn.conf.py ../
COPY requirements.txt ../

# copy app
COPY src-ui ./
COPY src ./

# Install supervisor
RUN cd /usr/src/paperless/src/ \ 
  && python3 -m pip install --default-timeout=1000 --upgrade --no-cache-dir supervisor \
  && python3 -m pip install --default-timeout=1000 --no-cache-dir -r ../requirements.txt

# add users, setup scripts
RUN addgroup --gid 1000 paperless \
	&& useradd --uid 1000 --gid paperless --home-dir /usr/src/paperless paperless \
	&& chown -R paperless:paperless ../ \
	&& gosu paperless python3 manage.py collectstatic --clear --no-input \
	&& gosu paperless python3 manage.py compilemessages

VOLUME ["/usr/src/paperless/data", "/usr/src/paperless/media", "/usr/src/paperless/consume", "/usr/src/paperless/export"]
ENTRYPOINT ["/sbin/docker-entrypoint.sh"]
EXPOSE 8000
CMD ["/usr/local/bin/supervisord", "-c", "/etc/supervisord.conf"]

LABEL org.opencontainers.image.source=ghcr.io/schnuffle/paperless-docker
