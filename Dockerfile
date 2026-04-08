ARG BASE_IMAGE

FROM ${BASE_IMAGE}

ARG ROS_DISTRO
ARG BASE_USER
ARG GPU

LABEL org.opencontainers.image.source=https://github.com/Greenroom-Robotics/ros_builder
LABEL description="Base ROS Builder image used for various Greenroom projects"
SHELL ["/bin/bash", "-c"]

ENV ROS_DISTRO="${ROS_DISTRO}"
ENV ROS_PYTHON_VERSION=3
ENV RMW_IMPLEMENTATION=rmw_fastrtps_cpp

# setup timezone, debconf, upgrade packages and install basic tools
RUN echo 'Etc/UTC' > /etc/timezone && \
    ln -sf /usr/share/zoneinfo/Etc/UTC /etc/localtime && \
    echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections && \
    echo 'wireshark-common wireshark-common/install-setuid boolean true' | debconf-set-selections && \
    apt-get update && \
    apt-get install -q -y --no-install-recommends tzdata && \
    apt-get upgrade -y && \
    apt-get install -q -y --no-install-recommends \
        less \
        sudo \
        iproute2 \
        dirmngr \
        gnupg2 \
        curl \
        wget \
        git \
        ca-certificates \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# setup ros2 apt sources and install greenroom public packages
RUN ROS_APT_SOURCE_VERSION=$(curl -s https://api.github.com/repos/ros-infrastructure/ros-apt-source/releases/latest | grep -F "tag_name" | awk -F\" '{print $4}') \
  && curl -L -o /tmp/ros2-apt-source.deb "https://github.com/ros-infrastructure/ros-apt-source/releases/download/${ROS_APT_SOURCE_VERSION}/ros2-apt-source_${ROS_APT_SOURCE_VERSION}.$(. /etc/os-release && echo $VERSION_CODENAME)_all.deb" && \
  apt install /tmp/ros2-apt-source.deb && \
  curl -s https://raw.githubusercontent.com/Greenroom-Robotics/public_packages/main/scripts/setup-apt.sh | bash -s

# setup environment
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Install additional dependencies for deepstream/GPU image
RUN if [ "$GPU" = "true" ]; then \
    cd /opt/nvidia/deepstream/deepstream-8.0/; \
    ./install.sh; \
    # Install missing codecs required by opencv.
    ./user_additional_install.sh; \
    # Delete line that activates venv, so pyds installs globally.
    sed -i '/^source \.\/pyds\/bin\/activate/d' ./user_deepstream_python_apps_install.sh; \
    # Install pyds.
    ./user_deepstream_python_apps_install.sh -v 1.2.2; \
    rm -rf /opt/nvidia/deepstream/deepstream-8.0/sources/deepstream_python_apps; \
fi

# install bootstrap tools, configure system, setup ROS environment, and configure user
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    apt-get update && apt-get install --no-install-recommends -y \
    build-essential \
    gcc-14-base \
    g++-14 \
    gdb \
    cmake \
    sccache \
    debhelper \
    dh-python \
    dpkg-dev \
    fakeroot \
    jq \
    iputils-ping \
    python3-catkin-pkg \
    python3-colcon-common-extensions \
    python3-colcon-mixin \
    python3-flake8 \
    python3-invoke \
    python3-pip \
    python3-pytest-cov \
    python3-pytest-rerunfailures \
    python3-rosdep \
    python3-setuptools \
    python3-vcstool \
    clang-format \
    ros-${ROS_DISTRO}-rmw-fastrtps-cpp \
    ros-${ROS_DISTRO}-rmw-zenoh-cpp \
    ros-${ROS_DISTRO}-ros-base \
    ros-${ROS_DISTRO}-ros-core \
    ros-${ROS_DISTRO}-geographic-msgs \
    ros-${ROS_DISTRO}-example-interfaces \
    bpfcc-tools \
    bpftrace \
    && curl -L https://github.com/rr-debugger/rr/releases/download/5.9.0/rr-5.9.0-Linux-$(uname -m).deb --output rr.deb \
    && dpkg --install rr.deb \
    && rm rr.deb \
    # set gcc version to latest available on ubuntu rel
    && update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-14 14 \
    && update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-14 14 \
    && update-alternatives --install /usr/bin/gcc-ar gcc-ar /usr/bin/gcc-ar-14 14 \
    && update-alternatives --install /usr/bin/gcc-nm gcc-nm /usr/bin/gcc-nm-14 14 \
    && update-alternatives --install /usr/bin/gcc-ranlib gcc-ranlib /usr/bin/gcc-ranlib-14 14 \
    # Remove EXTERNALLY-MANAGED so we don't need to add --break-system-packages to pip
    && sudo rm -f /usr/lib/python3.*/EXTERNALLY-MANAGED \
    # bootstrap rosdep
    && rosdep init \
    && rosdep update --rosdistro $ROS_DISTRO \
    # setup colcon mixin and metadata
    && colcon mixin add default \
      https://raw.githubusercontent.com/colcon/colcon-mixin-repository/master/index.yaml \
    && colcon mixin update \
    && colcon metadata add default \
      https://raw.githubusercontent.com/colcon/colcon-metadata-repository/master/index.yaml \
    && colcon metadata update \
    # install nodejs
    && curl -sL https://deb.nodesource.com/setup_22.x | bash - \
    # install yarn and pyright
    && apt-get install -y nodejs \
    && npm install --global yarn pyright \
    # Install Greenroom's rosdep fork which allows installation from URLs, version pinning and downgrades
    && apt-get remove python3-rosdep -y \
    # Install Greenroom fork of bloom
    && pip install pre-commit lark-parser \
        https://github.com/Greenroom-Robotics/bloom/archive/refs/heads/gr.zip \
        https://github.com/Greenroom-Robotics/rosdep/archive/refs/heads/russwebber/sc-16383/upgrade-to-ros-2-kilted.zip \
    # Move default home dir and update base user to ros.
    && usermod --move-home --home /home/ros --login ros ${BASE_USER} \
    && usermod -a -G audio,video,sudo,plugdev,dialout ros \
    && passwd -d ros \
    && groupmod --new-name ros ${BASE_USER}

WORKDIR /home/ros
ENV PATH="/home/ros/.local/bin:${PATH}"
ENV ROS_OVERLAY=/opt/ros/${ROS_DISTRO}

# Install additional ROS packages, run script generation, and final setup
RUN --mount=type=bind,source=scripts,target=scripts \
    apt-get update && apt-get install -y \
        ros-${ROS_DISTRO}-rosidl-generator-mypy \
        ros-${ROS_DISTRO}-rosidl-generator-pydantic && \
    rm -rf /var/lib/apt/lists/* && \
    source ${ROS_OVERLAY}/setup.sh && python3 scripts/rosidl_generate_inplace.py && \
    # Enable caching of apt packages: https://github.com/moby/buildkit/blob/master/frontend/dockerfile/docs/reference.md#example-cache-apt-packages \
    rm -f /etc/apt/apt.conf.d/docker-clean && \
    echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache && \
    chown ros:ros /home/ros && \
    # Make sure we own the venv directory if it exists (This is where packages are installed on l4t / jetson) \
    if [ -d /opt/venv ]; then chown -R ros:ros /opt/venv; fi

USER ros

# Install poetry as ros user
RUN pip install poetry poetry-plugin-export
