#!/bin/bash

# Loop through arguments (shift removes processed argument)
for arg in "$@"; do
  # Handle arguments with a switch case
  case $arg in
    nvidia-smi)
      echo "Checking nvidia-smi"
      nvidia-smi -L
    ;;
    build_mar)
      echo "Building mar..."
      time torch-model-archiver --model-name ${MAR_FILE_NAME} --version 1.0 --handler stable_diffusion_handler.py -r requirements.txt --export-path ${MAR_STORE_PATH}
    ;;
    serve)
      # Handle invalid arguments
      echo "starting the server"
      # start the server
      torchserve --start --ts-config config.properties --models "stable_diffusion=${MAR_FILE_NAME}.mar" --model-store ${MAR_STORE_PATH} --foreground
    ;;
    *)
      # Handle invalid arguments
      echo "Error: Invalid argument '$arg'"
      exit 1
    ;;
  esac
  # Shift arguments after processing the current one
  shift
done

echo "done..."
# Script exits here
exit 0
