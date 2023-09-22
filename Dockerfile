###########################################
# ---- UBI python with conda ----
###########################################
FROM registry.access.redhat.com/ubi8/ubi-minimal:8.8-860 as python
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8
USER root

# Install miniconda
ARG CONDA_VERSION="4.12.0"
ARG CONDA_MD5="9986028a26f489f99af4398eac966d36"
ARG CONDA_DIR="/opt/conda"
RUN microdnf update -y && microdnf install -y wget
RUN echo "**** get Miniconda ****" && \
    mkdir -p "$CONDA_DIR" && \
    wget "http://repo.continuum.io/miniconda/Miniconda3-py38_${CONDA_VERSION}-Linux-x86_64.sh" -O miniconda.sh && \
    echo "$CONDA_MD5  miniconda.sh" | md5sum -c && \
    echo "**** install Miniconda ****" && \
    bash miniconda.sh -f -b -p "$CONDA_DIR"  

# Install the package as normal:
ENV PATH="${PATH}:/opt/conda/bin"
RUN conda create -y -n conda_python python==3.10 

# Install conda-pack:
RUN conda install -y -c conda-forge conda-pack

# Use conda-pack to create a standalone enviornment
# in /venv:
# c.f. https://pythonspeed.com/articles/conda-docker-image-size/
RUN microdnf update -y && microdnf install -y tar
RUN conda-pack -n conda_python -o /tmp/env.tar && \
  mkdir -p /venv && cd /venv && tar xf /tmp/env.tar && \
  rm /tmp/env.tar

# We've put venv in same path it'll be in final image,
# so now fix up paths:
RUN /venv/bin/conda-unpack

###########################################
# ---- UBI python (standalone)  ----
###########################################
FROM registry.access.redhat.com/ubi8/ubi-minimal:8.8-860 as ubi_python
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8
USER root

# Copy /venv from the previous stage:
COPY --from=python /venv /venv

###########################################
# ---- base  ----
###########################################
FROM ubi_python AS base
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8
ENV PATH="/venv/bin:${PATH}"


# get some standard packages
RUN microdnf update -y && microdnf install -y \
  #which \
  gcc \
  gcc-c++ \
  #git \
  wget \
  libsndfile \
  #freetype-devel \
  openssh-clients \
  #bc \
  tar \
  make \
  xz

###########################################
# ---- Install dependencies ----
###########################################
FROM base AS with_dependencies
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8
ENV PATH="/venv/bin:${PATH}"

# get sox
RUN wget https://sourceforge.net/projects/sox/files/sox/14.4.2/sox-14.4.2.tar.gz \
  && tar -xzvf sox-14.4.2.tar.gz \
  && cd sox-14.4.2 \
  && ./configure --prefix /venv \
  && make \
  && make install \
  && cd .. \
  && rm sox-14.4.2.tar.gz \
  && rm -r sox-14.4.2 

# get ffmpeg
RUN wget https://www.johnvansickle.com/ffmpeg/old-releases/ffmpeg-4.3.2-amd64-static.tar.xz \
  && unxz ffmpeg-4.3.2-amd64-static.tar.xz \
  && tar xvf ffmpeg-4.3.2-amd64-static.tar \
  && mv ffmpeg-4.3.2-amd64-static/ffmpeg /venv/bin/ \
  && rm -r ffmpeg-4.3.2-amd64-static*

## May need this for GPU
#ENV PATH /usr/local/nvidia/bin:/usr/local/cuda/bin:${PATH}

# Upgrade pip
RUN pip install -U pip

###########################################
# ---- Install SDK ----
###########################################
FROM with_dependencies AS release
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8
ENV PATH="/venv/bin:${PATH}"

# Install requirements.txt
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

# Install repo
COPY pyproject.toml .
COPY src src
COPY MANIFEST.in .
#COPY setup.* .
RUN pip install .

# Export pip package dependencies
RUN pip list --format=freeze | sed '/d' | \
    openssl enc -in - -aes-256-cbc -pbkdf2 -out /requirements.deploy.bin -pass pass:SomePassword   

# Remove the source codes
#RUN rm -rf /app
###########################################
