# Create docker image from python3.9-slim
FROM python:3.10.0-buster AS builder
ARG VERSION=master
# Create python venv and add it to PATH
SHELL ["/bin/bash", "-c"]
RUN python -m venv /ledfx/venv 

ENV PATH="/ledfx/venv/bin:$PATH"

# Install dependencies and ledfx, remove uneeded packages
#
RUN apt-get update && apt-get install -y --no-install-recommends \
        gcc=4:8.3.0-1 \
        git=1:2.20.1-2+deb10u3 \
        libatlas3-base=3.10.3-8 \
        zlib1g-dev=1:1.2.11.dfsg-1 \
        portaudio19-dev=19.6.0-1+deb10u1 \
        python3-dev=3.7.3-1 \
        \
        # Pillow dependencies for dev branch 
        libfreetype6-dev=2.9.1-3+deb10u2 \
        libfribidi-dev=1.0.5-3.1+deb10u1 \
        libharfbuzz-dev=2.3.1-1 \
        libjpeg-turbo-progs=1:1.5.2-2+deb10u1 \
        libjpeg62-turbo-dev=1:1.5.2-2+deb10u1 \
        liblcms2-dev=2.9-3 \
        libopenjp2-7-dev=2.3.0-2+deb10u2 \
        tcl8.6-dev=8.6.9+dfsg-2 \
        tk8.6-dev=8.6.9-2 \
        libtiff5-dev=4.1.0+git191117-2~deb10u2 \
        \
        # aubio dependencies 
        python3-aubio=0.4.6-2 \
        python-aubio=0.4.6-2 \
        aubio-tools=0.4.6-2 \
        libavcodec-dev=7:4.1.6-1~deb10u1 \
        libavformat-dev=7:4.1.6-1~deb10u1 \
        libavutil-dev=7:4.1.6-1~deb10u1 \
        libswresample-dev=7:4.1.6-1~deb10u1 \
        libavresample-dev=7:4.1.6-1~deb10u1 \
        libsndfile1-dev=1.0.28-6 \
        librubberband-dev=1.8.1-7 \
        libsamplerate0-dev=0.1.9-2 \
        && rm -fr \
        /var/{cache,log}/* \
        /var/lib/apt/lists/*
COPY requirements.txt /tmp/
RUN  pip install  --no-cache-dir -r /tmp/requirements.txt \
&&  pip install -U --no-cache-dir git+https://github.com/LedFx/LedFx@${VERSION} \
        \
        # Clean the test and .pyc files for a smaller final image 
        && find /usr/local/lib/python3.9/ -type d -name tests -depth -exec rm -rf {} \; \
        && find /usr/local/lib/python3.9/ -type d -name test -depth -exec rm -rf {} \; \
        && find /usr/local/lib/python3.9/ -name __pycache__ -depth -exec rm -rf {} \; \
        && find /usr/local/lib/python3.9/ -name "*.pyc" -depth -exec rm -f {} \; \
        && find /ledfx/venv/lib/python3.9/ -type d -name tests -depth -exec rm -rf {} \; \
        && find /ledfx/venv/lib/python3.9/ -type d -name test -depth -exec rm -rf {} \; \
        && find /ledfx/venv/lib/python3.9/ -name __pycache__ -depth -exec rm -rf {} \; \
        && find /ledfx/venv/lib/python3.9/ -name "*.pyc" -depth -exec rm -f {} \; \
        \
        # Remove not needed packages
        && apt-get purge -y \
        gcc \
        git \
        python3-aubio \
        python-aubio \
        aubio-tools \
        libavcodec-dev \
        libavformat-dev \
        libavutil-dev \
        libswresample-dev\
        libavresample-dev \
        libsndfile1-dev \
        librubberband-dev \
        libsamplerate0-dev \
        liblcms2-dev \
        libopenjp2-7-dev \
        tcl8.6-dev \
        tk8.6-dev \
        libtiff5-dev \
        libjpeg62-turbo-dev \
        libharfbuzz-dev \
        libfreetype6-dev \
        libfribidi-dev \
        libjpeg-turbo-progs \
        portaudio19-dev \
        libatlas3-base \
        zlib1g-dev \
        python3-dev \
        && apt-get clean -y \
        && apt-get autoremove -y \
        && rm -fr \
        /var/{cache,log}/* \
        /var/lib/apt/lists/* \
        /root/.cache \
        && find /tmp/ -mindepth 1  -delete 

FROM python:3.10.0-buster AS dist
SHELL ["/bin/bash", "-c"]
# Runtime dependencies
RUN     apt-get update && apt-get install -y --no-install-recommends \
        portaudio19-dev=19.6.0-1+deb10u1 \
        pulseaudio=12.2-4+deb10u1 \
        alsa-utils=1.1.8-2 \
        libavformat58=7:4.1.6-1~deb10u1 \
        avahi-daemon=0.7-4+deb10u1 \
        libavahi-client3=0.7-4+deb10u1 \
        libnss-mdns=0.14.1-1 \
        \
        # https://gnanesh.me/avahi-docker-non-root.html
        # Installing avahi-daemon to enable auto discovery on linux host if network_mode: host is pass to docker container                    
        # Allow hostnames with more labels to be resolved so that we can resolve node1.mycluster.local.
        # https://github.com/lathiat/nss-mdns#etcmdnsallow
        && echo '*' > /etc/mdns.allow \
        # Configure NSSwitch to use the mdns4 plugin so mdns.allow is respected
        && sed -i "s/hosts:.*/hosts:          files mdns4 dns/g" /etc/nsswitch.conf \
        && printf "[server]\nenable-dbus=no\n" >> /etc/avahi/avahi-daemon.conf \
        && chmod 777 /etc/avahi/avahi-daemon.conf \
        && mkdir -p /var/run/avahi-daemon \
        && chown avahi:avahi /var/run/avahi-daemon \
        && chmod 777 /var/run/avahi-daemon \
        \
        # Add user `ledfx` create home folder and add to pulse-access groupe
        && useradd -l --create-home ledfx \
        && adduser ledfx pulse-access \
        \
        # Clean Up
        && apt-get clean -y \
        && apt-get autoremove -y \
        && rm -fr \
        /var/{cache,log}/* \
        /var/lib/apt/lists/* \
        /root/.cache \
        && find /tmp/ -mindepth 1  -delete

COPY --from=builder /ledfx/venv/ /ledfx/venv/
ENV PATH="/ledfx/venv/bin:$PATH"
# Add pulseclinet config
COPY pulse-client.conf /etc/pulse/client.conf
COPY ledfx.sh /usr/local/bin/ledfx.sh
# Set the working directory in the container
WORKDIR /home/ledfx
USER ledfx
# Expose port 8888 for web server
EXPOSE 8888/tcp
ENTRYPOINT [ "/usr/local/bin/ledfx.sh"]
