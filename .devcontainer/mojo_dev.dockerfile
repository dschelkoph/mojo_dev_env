ARG IMAGE=ubuntu
ARG TAG=22.04
FROM ${IMAGE}:${TAG}

SHELL ["/bin/bash", "-c", "-e"]

ARG USER=dev
ARG USER_HOME=/home/${USER}
ARG VIRTUAL_ENV_PATH=${USER_HOME}/.venv/project \
    DEBIAN_FRONTEND=noninteractive \
    PYTHON_VERSION=3.11

ENV TZ=America/New_York \
    PYTHONBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONPATH=/workspace/python \
    VIRTUAL_ENV=${VIRTUAL_ENV_PATH} \
    LD_LIBRARY_PATH=/usr/local/lib \
    MODULAR_HOME=${USER_HOME}/.modular

# add venv bin, pipx bin and mojo directories
ENV PATH=${VIRTUAL_ENV}/bin:${PATH}:/home/dev/.local/bin:${MODULAR_HOME}/pkg/packages.modular.com_mojo/bin

RUN --mount=type=cache,target=/var/cache/apt \
<<EOF
useradd --create-home --shell /bin/bash ${USER}

apt-get update
apt-get install --yes --no-install-recommends\
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg

# Install modular registry: https://developer.modular.com/download
MODULAR_KEYRING=/usr/share/keyrings/modular-installer-archive-keyring.gpg
curl -1sLf 'https://dl.modular.com/bBNWiLZX5igwHXeu/installer/gpg.0E4925737A3895AD.key' |  gpg --dearmor >> ${MODULAR_KEYRING}
curl -1sLf 'https://dl.modular.com/bBNWiLZX5igwHXeu/installer/config.deb.txt?distro=debian&codename=wheezy' > /etc/apt/sources.list.d/modular-installer.list

# Install python registry
DEADSNAKES_KEYRING=/usr/share/keyrings/deadsnakes.gpg
curl -1sLf "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xf23c5a6cf475977595c89f51ba6932366a755776" | gpg --dearmor > ${DEADSNAKES_KEYRING}
cat <<EOF2 > /etc/apt/sources.list.d/deadsnakes.list
deb [signed-by=${DEADSNAKES_KEYRING}] https://ppa.launchpadcontent.net/deadsnakes/ppa/ubuntu jammy main
deb-src [signed-by=${DEADSNAKES_KEYRING}] https://ppa.launchpadcontent.net/deadsnakes/ppa/ubuntu jammy main
EOF2

# Get packages from added registries
apt-get update
apt-get install --yes --no-install-recommends \
    bash-completion \
    git \
    nano \
    sudo \
    build-essential \
    libedit-dev \
    zlib1g-dev \
    modular \
    python${PYTHON_VERSION} \
    python${PYTHON_VERSION}-venv \
    python${PYTHON_VERSION}-dev \
    python${PYTHON_VERSION}-distutils

echo "${USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USER}
mkdir --parents /home/dev/.cache/pip
chown -R ${USER}:${USER} /home/dev/.cache
EOF

USER ${USER}
RUN --mount=type=cache,target=/home/dev/.cache/pip,uid=1000 \
    --mount=type=secret,id=modular_key,required=true,uid=1000 \
<<EOF

# install python tools
curl --fail --location --silent --show-error https://bootstrap.pypa.io/get-pip.py | python${PYTHON_VERSION}  -
python${PYTHON_VERSION}  -m pip install --user pipx
pipx install ruff
pipx install black
pipx install glances
pipx install poetry
pipx install scalene

poetry completions bash >> ${USER_HOME}/.bash_completion
mkdir --parents ${USER_HOME}/.cache/pypoetry

# Install mojo in its own venv to isloate packages that are automatically installed
python${PYTHON_VERSION} -m venv ${USER_HOME}/.venv/mojo
source ${USER_HOME}/.venv/mojo/bin/activate
modular auth $(cat /run/secrets/modular_key)
modular install mojo
deactivate

# create project venv
python${PYTHON_VERSION} -m venv ${USER_HOME}/.venv/project

EOF

CMD ["sleep", "infinity"]