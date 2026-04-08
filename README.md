# ROS Builder

![image](docs/static/ros_builder.png)

This builds a base ROS 2 docker image used for building Greenroom packages.

## Features
* Greenroom's `bloom` [fork](https://github.com/Greenroom-Robotics/bloom/)
* Greenroom's `rosdep` [fork](https://github.com/Greenroom-Robotics/rosdep/)
* All base interfaces generated with `rosidl_generator_mypy` and `rosidl_generator_pydantic`

## Versions

There are 4 different variations of `ros_builder`. See [ghcr](https://github.com/Greenroom-Robotics/ros_builder/pkgs/container/ros_builder). These are

* ` ghcr.io/greenroom-robotics/ros_builder:kilted-latest` **AMD64** & **ARM64**
* ` ghcr.io/greenroom-robotics/ros_builder:kilted-latest-deepstream-8.0` **AMD64** & **ARM64**

## Releasing

### Github Action

*This will be slow to build but fast to upload.*

Trigger the [publish.yml](./.github/workflows/publish.yml) github action

### Local

*This will be fast(er) to build but slow to upload.*

* `yarn version --patch|minor|major`
* `python3 scripts/docker-build.py --version 1.0.0 --arch amd64 --ros_distro kilted`
