#!/bin/bash

docker stop chromadb
docker pull chromadb/chroma
docker run --rm -d -p 8000:8000 --name chromadb chromadb/chroma