import ament_index_python
from rosidl_cli.command.generate.api import generate
from pathlib import Path
import os

interfaces_pkgs = ament_index_python.get_resources('rosidl_interfaces')
# needs to be run from / for the file paths to be correct
os.chdir("/")

for pkg_name, pkg_prefix in interfaces_pkgs.items():
    resource_files, rsc_path = ament_index_python.get_resource('rosidl_interfaces', pkg_name)
    resource_files = resource_files.split('\n')

    share_path = ament_index_python.get_package_share_path(pkg_name).relative_to(Path.cwd())

    idls = [str(share_path / resource_file) for resource_file in resource_files if resource_file.endswith('.idl')]
    print(f'Generating {pkg_name} interfaces from {idls}...')

    generate(
        package_name=pkg_name,
        interface_files=idls,
        output_path=Path('/'),
        types=['mypy', 'pydantic']
    )
