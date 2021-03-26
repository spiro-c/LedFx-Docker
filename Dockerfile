# Create docker image from python3.9-slim
FROM python:3.9-slim
COPY requirements.txt /
# Create python venv and add it to PATH
RUN python -m venv /ledfx/venv 

ENV PATH="/ledfx/venv/bin:$PATH"

# Install dependencies and ledfx, remove uneeded packages
#
RUN apt-get update && apt-get install -y --no-install-recommends \
        gcc=4:8.3.0-1 \
        # alsa-utils \
        libatlas3-base=3.10.3-8 \
        portaudio19-dev=19.6.0-1 \
        # pulseaudio \
        python3-dev=3.7.3-1 \
        && pip install --no-cache-dir --requirement requirements.txt \
        && apt-get purge -y gcc python3-dev && apt-get clean -y && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*
 

# Add user `ledfx` and create home folder
RUN useradd -l --create-home ledfx
# Set the working directory in the container
WORKDIR /home/ledfx
USER ledfx

# Expose port 8888 for web server and 5353 for mDNS discovery
EXPOSE 8888/tcp
EXPOSE 5353/udp
ENTRYPOINT [ "ledfx"]
