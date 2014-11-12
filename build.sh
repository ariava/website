#!/bin/bash

jekyll build

cd _mirage
mirage clean
mirage configure --xen
make depend
CAML_LD_LIBRARY_PATH=/home/ava/.opam/4.01.0/lib mirage build
mirage run
