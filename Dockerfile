# Create docker image from python3.9-slim
FROM python:3.9-bullseye AS builder
ARG VERSION=main
# Create python venv and add it to PATH
SHELL ["/bin/bash", "-c"]
RUN python -m venv /ledfx/venv 

ENV PATH="/ledfx/venv/bin:$PATH"

# Install dependencies and ledfx, remove uneeded packages
#
RUN \
        apt-get update && apt-get install -y --no-install-recommends \
        build-essential=12.9 \
        libavformat58=7:4.3.4-0+deb11u1 \
        libasound2-plugins=1.2.2-2 \
        cython3=0.29.21-3+b1 \
        gcc=4:10.2.1-1 \
        git=1:2.30.2-1 \
        libatlas3-base=3.10.3-10 \
        zlib1g-dev=1:1.2.11.dfsg-2+deb11u2 \
        portaudio19-dev=19.6.0-1.1 \
        python3-dev=3.9.2-3 \
        python3=3.9.2-3 \
        python3-pip=20.3.4-4+deb11u1 \
        nginx=1.18.0-6.1+deb11u3 \
        unzip=6.0-26+deb11u1 \
        \
        # Pillow dependencies for dev branch
        libfreetype6-dev=2.10.4+dfsg-1+deb11u1 \
        libfribidi-dev=1.0.8-2+deb11u1 \
        libharfbuzz-dev=2.7.4-1 \
        libjpeg-turbo-progs=1:2.0.6-4 \
        libjpeg62-turbo-dev=1:2.0.6-4 \
        liblcms2-dev=2.12~rc1-2 \
        libopenjp2-7-dev=2.4.0-3 \
        tcl8.6-dev=8.6.11+dfsg-1 \
        tk8.6-dev=8.6.11-2 \
        libtiff5-dev=4.2.0-1+deb11u1 \
        \
        # aubio dependencies
        python3-aubio=0.4.9-4+b4 \
        aubio-tools=0.4.9-4+b4 \
        python3-numpy=1:1.19.5-1 \
        libavcodec58=7:4.3.4-0+deb11u1 \
        libchromaprint1=1.5.0-2 \
        libavresample4=7:4.3.4-0+deb11u1 \
        libavutil56=7:4.3.4-0+deb11u1 \
        libavcodec-dev=7:4.3.4-0+deb11u1 \
        libavformat-dev=7:4.3.4-0+deb11u1 \
        libavutil-dev=7:4.3.4-0+deb11u1 \
        libswresample-dev=7:4.3.4-0+deb11u1 \
        libswresample3=7:4.3.4-0+deb11u1 \
        libavresample-dev=7:4.3.4-0+deb11u1 \
        libsndfile1-dev=1.0.31-2 \
        librubberband-dev=1.9.0-1 \
        libsamplerate0-dev=0.2.1+ds0-1 \
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
        build-essential \
        cython3 \
        gcc \
        git \
        libatlas3-base \
        zlib1g-dev \
        python3-dev \
        \
        # Pillow dependencies for dev branch 
        libfreetype6-dev \
        libfribidi-dev \
        libharfbuzz-dev \
        libjpeg-turbo-progs \
        libjpeg62-turbo-dev \
        liblcms2-dev \
        libopenjp2-7-dev \
        tcl8.6-dev \
        tk8.6-dev \
        libtiff5-dev \
        \
        # aubio dependencies 
        libavcodec58 \
        libchromaprint1 \
        libavresample4 \
        libavutil56 \
        libavcodec-dev \
        libavformat-dev \
        libavutil-dev \
        libswresample-dev \
        libswresample3 \
        libavresample-dev \
        libsndfile1-dev \
        librubberband-dev \
        libsamplerate0-dev \
        unzip \
        \
        && apt-get clean -y \
        && apt-get autoremove -y \
        && rm -fr \
        /var/{cache,log}/* \
        /var/lib/apt/lists/* \
        /root/.cache \
        && find /tmp/ -mindepth 1  -delete 

FROM python:3.9-slim AS dist
SHELL ["/bin/bash", "-c"]
# Runtime dependencies
RUN     apt-get update && apt-get install -y --no-install-recommends \
        libasound2-plugins=1.2.2-2 \
        pulseaudio \
        avahi-daemon=0.8-5+deb11u1 \
        libavahi-client3=0.8-5+deb11u1 \
        libnss-mdns=0.14.1-2 \
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
