#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0
#
# Copyright (C) Google LLC, 2018
#
# Author: Tom Roeder <tmroeder@google.com>
#
"""A tool for generating compile_commands.json in the Linux kernel."""

import argparse
import json
import logging
import os
import re
import shlex
import subprocess
import sys

_DEFAULT_OUTPUT = 'compile_commands.json'
_DEFAULT_LOG_LEVEL = 'WARNING'

_FILENAME_PATTERN = r'^\..*\.cmd$'
_LINE_PATTERN = r'^cmd_[^ ]*\.o := (.* )([^ ]*\.(?:c|cc|cpp|cxx|s|S)) *(;|$)'
_VALID_LOG_LEVELS = ['DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL']
_SOURCE_EXTS = ('.c', '.cc', '.cpp', '.cxx', '.s', '.S')
# The tools/ directory adopts a different build system, and produces .cmd
# files in a different format. Do not support it.
_EXCLUDE_DIRS = ['.git', 'Documentation', 'include', 'tools']


def parse_arguments():
    """Sets up and parses command-line arguments.

    Returns:
        log_level: A logging level to filter log output.
        directory: The work directory where the objects were built.
        ar: Command used for parsing .a archives.
        output: Where to write the compile-commands JSON file.
        paths: The list of files/directories to handle to find .cmd files.
    """
    usage = 'Creates a compile_commands.json database from kernel .cmd files'
    parser = argparse.ArgumentParser(description=usage)

    directory_help = ('specify the output directory used for the kernel build '
                      '(defaults to the working directory)')
    parser.add_argument('-d', '--directory', type=str, default='.',
                        help=directory_help)

    output_help = ('path to the output command database (defaults to ' +
                   _DEFAULT_OUTPUT + ')')
    parser.add_argument('-o', '--output', type=str, default=_DEFAULT_OUTPUT,
                        help=output_help)

    log_level_help = ('the level of log messages to produce (defaults to ' +
                      _DEFAULT_LOG_LEVEL + ')')
    parser.add_argument('--log_level', choices=_VALID_LOG_LEVELS,
                        default=_DEFAULT_LOG_LEVEL, help=log_level_help)

    ar_help = 'command used for parsing .a archives'
    parser.add_argument('-a', '--ar', type=str, default='llvm-ar', help=ar_help)

    paths_help = ('directories to search or files to parse '
                  '(files should be *.o, *.a, modules.order, .cc_cmd, or *.dep). '
                  'If nothing is specified, the current directory is searched')
    parser.add_argument('paths', type=str, nargs='*', help=paths_help)

    args = parser.parse_args()

    return (args.log_level,
            os.path.abspath(args.directory),
            args.output,
            args.ar,
            args.paths if len(args.paths) > 0 else [args.directory])


def unescape_make_value(value):
    return value.replace(r'\#', '#').replace('$(pound)', '#')


def _prune_excluded_subdirs(dirnames):
    dirnames[:] = [dirname for dirname in dirnames if dirname not in _EXCLUDE_DIRS]


def cmdfiles_in_dir(directory):
    """Generate the iterator of .cmd files found under the directory.

    Walk under the given directory, and yield every .cmd file found.

    Args:
        directory: The directory to search for .cmd files.

    Yields:
        The path to a .cmd file.
    """

    filename_matcher = re.compile(_FILENAME_PATTERN)

    for dirpath, dirnames, filenames in os.walk(directory, topdown=True):
        _prune_excluded_subdirs(dirnames)

        for filename in filenames:
            if filename_matcher.match(filename):
                yield os.path.join(dirpath, filename)


def depdirs_in_dir(directory):
    """Generate the iterator of directories containing .cc_cmd and *.dep."""
    for dirpath, dirnames, filenames in os.walk(directory, topdown=True):
        _prune_excluded_subdirs(dirnames)
        has_cc_cmd = '.cc_cmd' in filenames
        has_dep = any(filename.endswith('.dep') for filename in filenames)
        if has_cc_cmd and has_dep:
            yield dirpath


def to_cmdfile(path):
    """Return the path of .cmd file used for the given build artifact

    Args:
        Path: file path

    Returns:
        The path to .cmd file
    """
    directory, base = os.path.split(path)
    return os.path.join(directory, '.' + base + '.cmd')


def cmdfiles_for_o(obj):
    """Generate the iterator of .cmd files associated with the object

    Yield the .cmd file used to build the given object

    Args:
        obj: The object path

    Yields:
        The path to .cmd file
    """
    yield to_cmdfile(obj)


def cmdfiles_for_a(archive, ar):
    """Generate the iterator of .cmd files associated with the archive.

    Parse the given archive, and yield every .cmd file used to build it.

    Args:
        archive: The archive to parse

    Yields:
        The path to every .cmd file found
    """
    for obj in subprocess.check_output([ar, '-t', archive]).decode().split():
        yield to_cmdfile(obj)


def cmdfiles_for_modorder(modorder):
    """Generate the iterator of .cmd files associated with the modules.order.

    Parse the given modules.order, and yield every .cmd file used to build the
    contained modules.

    Args:
        modorder: The modules.order file to parse

    Yields:
        The path to every .cmd file found
    """
    with open(modorder, 'rt') as module_order_file:
        for line in module_order_file:
            ko = line.rstrip()
            base, ext = os.path.splitext(ko)
            if ext != '.ko':
                sys.exit('{}: module path must end with .ko'.format(ko))
            mod = base + '.mod'
            # The first line of *.mod lists the objects that compose the module.
            with open(mod, 'rt') as module_file:
                for obj in module_file.readline().split():
                    yield to_cmdfile(obj)


def process_line(root_directory, command_prefix, file_path):
    """Extracts information from a .cmd line and creates an entry from it.

    Args:
        root_directory: The directory that was searched for .cmd files. Usually
            used directly in the "directory" entry in compile_commands.json.
        command_prefix: The extracted command line, up to the last element.
        file_path: The source file from the end of the extracted command.
            Usually relative to root_directory, but sometimes absolute.

    Returns:
        An entry to append to compile_commands.

    Raises:
        ValueError: Could not find the extracted file based on file_path and
            root_directory.
    """
    # The .cmd files are intended to be included directly by Make, so they
    # escape the pound sign '#', either as '\#' or '$(pound)' (depending on the
    # kernel version). The compile_commands.json file is not interpreted by
    # Make, so this code replaces the escaped version with '#'.
    prefix = unescape_make_value(command_prefix)

    # Use os.path.abspath() to normalize the path resolving '.' and '..'.
    abs_path = os.path.abspath(os.path.join(root_directory, file_path))
    if not os.path.exists(abs_path):
        raise ValueError('File %s not found' % abs_path)
    return {
        'directory': root_directory,
        'file': abs_path,
        'command': prefix + file_path,
    }


def parse_dep_targets(dep_content):
    """Extract (target, source) pairs from *.dep file content."""
    compact = dep_content.replace('\\\n', ' ')
    lines = [line.strip() for line in compact.splitlines() if line.strip()]
    parsed = []
    for line in lines:
        if ':' not in line:
            continue
        target, deps = line.split(':', 1)
        target = target.strip()
        source = None
        for token in deps.split():
            if token.endswith(_SOURCE_EXTS):
                source = token
                break
        if source:
            parsed.append((target, source))
    return parsed


def _command_has_output(tokens):
    if '-o' in tokens:
        return True
    for token in tokens:
        if token.startswith('-o') and token != '-o':
            return True
    return False


def _dep_command_driver():
    """Resolve compiler driver for .cc_cmd fallback entries."""
    cc = os.environ.get('CC')
    if cc:
        return cc

    cross_compile = os.environ.get('CC')
    if cross_compile:
        return cross_compile + 'gcc'

    return 'gcc'


def build_dep_command(cc_cmd, source_path, output_path):
    """Build a full compile command from .cc_cmd and a *.dep pair."""
    try:
        tokens = shlex.split(cc_cmd)
    except ValueError:
        tokens = cc_cmd.split()

    has_driver = bool(tokens) and not tokens[0].startswith('-')
    has_compile_only = '-c' in tokens
    has_output = _command_has_output(tokens)
    has_source = any((not token.startswith('-')) and token.endswith(_SOURCE_EXTS)
                     for token in tokens)

    command = cc_cmd.strip()
    if not has_driver:
        command = _dep_command_driver() + ' ' + command
    if not has_compile_only:
        command += ' -c'
    if not has_source:
        command += ' ' + shlex.quote(source_path)
    if not has_output:
        command += ' -o ' + shlex.quote(output_path)
    return command


def process_dep_dir(root_directory, dep_dir):
    """Generate compile_commands entries from .cc_cmd and *.dep in dep_dir."""
    cc_cmd_path = os.path.join(dep_dir, '.cc_cmd')
    if not os.path.isfile(cc_cmd_path):
        return []

    dep_files = sorted(
        os.path.join(dep_dir, filename)
        for filename in os.listdir(dep_dir)
        if filename.endswith('.dep') and os.path.isfile(os.path.join(dep_dir, filename))
    )
    if not dep_files:
        return []

    with open(cc_cmd_path, 'rt') as cc_cmd_file:
        cc_cmd = unescape_make_value(cc_cmd_file.read().strip())
    if not cc_cmd:
        logging.info('Skip %s: .cc_cmd is empty', dep_dir)
        return []

    entries = []
    for dep_path in dep_files:
        with open(dep_path, 'rt') as dep_file:
            targets = parse_dep_targets(dep_file.read())
        if not targets:
            logging.info('No target/source pair found in %s', dep_path)
            continue
        for target, source in targets:
            source_abs = os.path.abspath(os.path.join(dep_dir, source))
            if not os.path.exists(source_abs):
                logging.info('Could not add line from %s: file %s not found',
                             dep_path, source_abs)
                continue
            output_abs = os.path.abspath(os.path.join(dep_dir, target))
            # for cc_cmd + dep, directory shuold be dep_dir.
            entries.append({
                'command': build_dep_command(cc_cmd, source_abs, output_abs),
                'directory': dep_dir,
                'file': source_abs,
            })
    return entries


def main():
    """Walks through the directory and finds and parses .cmd files."""
    log_level, directory, output, ar, paths = parse_arguments()

    level = getattr(logging, log_level)
    logging.basicConfig(format='%(levelname)s: %(message)s', level=level)

    line_matcher = re.compile(_LINE_PATTERN)

    compile_commands = []
    directory = os.path.realpath(directory)

    for path in paths:
        path = os.path.abspath(path)

        # If 'path' is a directory, handle all .cmd files under it.
        # Otherwise, handle .cmd files associated with the file.
        # Most of built-in objects are linked via archives (built-in.a or lib.a)
        # but some objects are linked to vmlinux directly.
        # Modules are listed in modules.order.
        if os.path.isdir(path):
            cmdfiles = cmdfiles_in_dir(path)
            depdirs = depdirs_in_dir(path)
        elif path.endswith('.o'):
            cmdfiles = cmdfiles_for_o(path)
            depdirs = []
        elif path.endswith('.a'):
            cmdfiles = cmdfiles_for_a(path, ar)
            depdirs = []
        elif path.endswith('modules.order'):
            cmdfiles = cmdfiles_for_modorder(path)
            depdirs = []
        elif path.endswith('.dep') or os.path.basename(path) == '.cc_cmd':
            cmdfiles = []
            depdirs = [os.path.dirname(path)]
        else:
            sys.exit('{}: unknown file type'.format(path))

        for cmdfile in cmdfiles:
            try:
                with open(cmdfile, 'rt') as cmdfile_obj:
                    result = line_matcher.match(cmdfile_obj.readline())
            except OSError as err:
                logging.info('Could not read %s: %s', cmdfile, err)
                continue

            if result:
                try:
                    entry = process_line(directory, result.group(1), result.group(2))
                    compile_commands.append(entry)
                except ValueError as err:
                    logging.info('Could not add line from %s: %s', cmdfile, err)

        for dep_dir in depdirs:
            dep_dir = os.path.abspath(dep_dir)
            for entry in process_dep_dir(directory, dep_dir):
                compile_commands.append(entry)

    compile_commands.sort(key=lambda item: (item['file'], item['command']))

    with open(output, 'wt') as output_file:
        json.dump(compile_commands, output_file, indent=2, sort_keys=True)


if __name__ == '__main__':
    main()
