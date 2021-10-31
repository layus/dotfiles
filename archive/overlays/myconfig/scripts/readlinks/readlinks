#!/usr/bin/python3

import sys, os
from os.path import *
import distutils.spawn

import argparse

parser = argparse.ArgumentParser(description='Recursively follow symlinks.')
parser.add_argument('target', metavar='path', type=str,
                    help='An executable or path to follow.')
parser.add_argument('--verbose', '-v', action='count', default=0)
args = parser.parse_args()

verbosity = args.verbose
path = args.target

if exists(path):
    path = abspath(path)
else:
    path = distutils.spawn.find_executable(path)
    if not path:
        print("Error: '{}' is not a valid path nor a known executable.".format(sys.argv[1]))
        sys.exit(1);

def allparts(path):
    allparts = []
    while True:
        dirname, filename = split(path)
        if dirname == path: break

        allparts.append(filename)
        if filename == path: break

        path = dirname
    return list(reversed(allparts))

print(path)


parts = allparts(path)
path = '/';

while parts or islink(path):
    if verbosity >= 2: print('Examining', path)
    if not islink(path):
        path = join(path, parts.pop(0))
    else:
        target = os.readlink(path)
        if not isabs(target):
            target = normpath(join(path, '..', target))
        if verbosity >= 1: print(path, '->', target)
        path = join(target, *parts)
        print(path)
        # reset.
        parts = allparts(path)
        path = '/';

