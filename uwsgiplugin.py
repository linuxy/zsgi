import os

NAME = 'zsgi'
GCC_LIST = ['zsgi', 'plugins/zsgi/libzsgi.a']

CFLAGS = []

if os.uname()[0] == 'Darwin':
    CFLAGS.append('-mmacosx-version-min=10.7')
