#!/usr/bin/env python3

"""
Perforated cardboard is the. uhh. the entry point. For a box of Lego.
Sorry
"""

import argparse
import datetime
import enum
import io
import json
import logging
import os
import re
import shutil
import subprocess
import tempfile
import textwrap
import time
import sys


SCRIPTDIR = os.path.dirname(os.path.realpath(__file__))
logging.basicConfig(
    level=logging.INFO,
    format='[%(asctime)s]\t%(levelname)s:\t%(message)s',
    datefmt='%Y-%m-%d %H:%M:%S')
LOGGER = logging.getLogger(__name__)


class ResolvedPath(str):
    """Resolve a path

    Intended to be passed as a type= option to add_argument()
    (which is why it is a class and not a function)
    """
    def __new__(cls, path):
        return str.__new__(cls, os.path.realpath(os.path.normpath(os.path.expanduser(path))))


def idb_excepthook(type, value, tb):
    """Call an interactive debugger in post-mortem mode

    If you do "sys.excepthook = idb_excepthook", then an interactive debugger
    will be spawned at an unhandled exception
    """
    if hasattr(sys, 'ps1') or not sys.stderr.isatty():
        sys.__excepthook__(type, value, tb)
    else:
        import pdb, traceback
        traceback.print_exception(type, value, tb)
        pdb.pm()


def parse_env_file(fileobj):
    """Parse a shell environment file

    A shell environment file is a file containing NAME=VALUE environment variables
    from e.g. the shell's env command.

    Note that this is *extremely* basic and does not support:
    - comments, anywhere
    - any sort of shell escaping or quoting (escapes/quotes are just copied naively)

    fileobj     An opened file object from e.g. "open('file.txt')"
    """
    retdict = {}
    for line in fileobj.readlines():
        line = line.strip()
        if len(line) > 0:
            key, value = line.split('=', 1)
            retdict[key.strip()] = value.strip()
    return retdict


def archive(path, outdir, outfilebase, recipient, compress=True, env=os.environ.copy()):
    """Create an encrypted archive

    path            Path to archive
    outdir          Directory to save the output file in
    outfilebase     Base name to save in the output directory
    recipient       GPG recipient name
    compress        If true, compress with xz
                    (path is always tarred)

    return          Path to the encrypted archive

    The file will be named f"{outfilebase}.{datetimestamp}.{ext}",
    where {ext} is .tar.xz.gpg or .tar.gpg as appropriate.
    """

    if compress:
        filext = "tar.xz.gpg"
        tarcmd = ['tar', '-cvJ']
    else:
        filext = "tar.gpg"
        tarcmd = ['tar', '-cv']
    now = datetime.datetime.now().strftime('%Y-%m-%d-%H-%M-%S')
    outpath = os.path.join(outdir, f"{outfilebase}.{now}.{filext}")
    gpgcmd = ['gpg', '--encrypt', '--recipient', recipient, '--output', outpath]

    tarproc = subprocess.Popen(tarcmd, stdout=subprocess.PIPE, env=env)
    gpgproc = subprocess.Popen(gpgcmd, stdin=tarproc.stdout, stdout=subprocess.PIPE, env=env)
    gpgout, gpgerr = gpgproc.communicate()
    if gpgproc.returncode != 0:
        raise subprocess.CalledProcessError(
            gpgproc.returncode, gpgcmd, output=gpgout, stderr=gpgerr)

    return outpath


def parseargs(*args, **kwargs):
    """Parse command-line arguments.
    """
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--debug", "-d", action='store_true',
        help=(
            "Include debugging output and start the debugger on unhandled exceptions "
            "(implies --verbose)"))
    parser.add_argument(
        "--verbose", "-v", action="store_true", help="Include debugging output")
    parser.add_argument(
        '--path', default=ResolvedPath("/srv/backuproot"), type=ResolvedPath,
        help='The path to back up')
    parser.add_argument(
        '--basename', nargs=1, help='Base name of encrypted archive')
    parser.add_argument(
        '--recipient', nargs=1, help="The GPG recipient to encrypt to")
    parser.add_argument(
        '--no-compress', dest='compress', action='store_false',
        help="Do not compress before encryptingb")
    parser.add_argument(
        '--additional-env-file', help=(
            'The path to an additional file containing environment variables. '
            'The variables should be in KEY=VALUE format.'
            'Intended for use with Docker secrets in a Docker Swarm.'))

    parsed = parser.parse_args()

    raise Exception("Figure out logging")

    return parsed


def main(*args, **kwargs):
    """Entrypoint for this script.
    """
    parsed = parseargs(args, kwargs)

    if parsed.verbose or parsed.debug:
        LOGGER.setLevel(logging.DEBUG)
    if parsed.debug:
        sys.excepthook = idb_excepthook

    LOGGER.debug(f"Started with arguments: {vars(parsed)}")

    # def archive(path, outdir, outfilebase, recipient, compress=True):
    env = os.environ.copy()
    if parsed.additional_env_file is not None:
        LOGGER.debug(f"Adding environment variables from {parsed.additional_env_file}...")
        with open(parsed.additional_env_file) as ef:
            env.update(parse_env_file(ef))

    archived = archive(
        parsed.path, '/tmp', parsed.basename, parsed.recipient,
        compress=parsed.compress, env=env)


if __name__ == '__main__':
    sys.exit(main(*sys.argv))
