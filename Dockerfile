ARG PG_MAJOR=17
FROM postgres:$PG_MAJOR
ARG PG_MAJOR

COPY . /tmp/vasco

RUN apt-get update && \
		apt-mark hold locales && \
		apt-get install -y --no-install-recommends libpoppler-glib-dev pkg-config wget build-essential postgresql-server-dev-$PG_MAJOR && \
		cd /tmp/vasco && \
		make clean && \
		make install && \
		mkdir /usr/share/doc/vasco && \
		cp LICENSE README.md /usr/share/doc/vasco && \
		rm -r /tmp/vasco && \
		apt-get remove -y pkg-config wget build-essential postgresql-server-dev-$PG_MAJOR && \
		apt-get autoremove -y && \
		apt-mark unhold locales && \
		rm -rf /var/lib/apt/lists/*