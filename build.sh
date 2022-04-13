#!/bin/bash

zig build-lib zsgi.zig -fcompiler-rt -lc
zig build-lib example.zig -fcompiler-rt -lc -dynamic
cp default.ini ../../buildconf
cd ../../ && make && cd plugins/zsgi
