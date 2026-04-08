import importlib
import os
from pathlib import Path

import ament_index_python
from rosidl_cli.command.generate.api import generate

interfaces_pkgs = ament_index_python.get_resources("rosidl_interfaces")
os.chdir("/")

for pkg_name, pkg_prefix in interfaces_pkgs.items():
    resource_files, rsc_path = ament_index_python.get_resource("rosidl_interfaces", pkg_name)
    resource_files = resource_files.split("\n")

    share_path = ament_index_python.get_package_share_path(pkg_name).relative_to(Path.cwd())

    idls = [
        str(share_path / resource_file)
        for resource_file in resource_files
        if resource_file.endswith(".idl")
    ]
    if not idls:
        continue

    print(f"Generating {pkg_name} interfaces from {idls}...")

    # mypy: stubs overlay the existing package, output_path=/ works as-is
    generate(
        package_name=pkg_name,
        interface_files=idls,
        output_path=Path("/"),
        types=["mypy"],
    )

    # pydantic: needs prefix:relative format and output into {pkg}/pydantic/
    abs_share_path = ament_index_python.get_package_share_path(pkg_name)
    pydantic_idls = [f"{abs_share_path}:{rf}" for rf in resource_files if rf.endswith(".idl")]

    try:
        mod = importlib.import_module(pkg_name)
    except ImportError:
        print(f"  Skipping pydantic for {pkg_name} (not importable)")
        continue

    output_path = Path(mod.__path__[0]) / "pydantic"
    generate(
        package_name=pkg_name,
        interface_files=pydantic_idls,
        output_path=output_path,
        types=["pydantic"],
    )
