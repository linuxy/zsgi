#!/bin/bash

zig build-lib zsgi.zig -fcompiler-rt -lc
zig build-lib example.zig -fcompiler-rt -lc -dynamic
cd ../../ && make && cd plugins/zsgi
