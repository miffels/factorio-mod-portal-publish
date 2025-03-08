#!/bin/bash

pushd $INPUT_PATH

echo "Publishing mod in '$INPUT_PATH'"

VERSION=$(jq -r '.version' info.json)
# Make sure the info.json is parseable and has the expected version number

# Pull the mod name from info.json
NAME=$(jq -r '.name' info.json)

FILE=${NAME}_${VERSION}.zip

# Create the zip
git config --global --add safe.directory /github/workspace
git archive --prefix "${NAME}_$VERSION/" -o "${NAME}_$VERSION.zip" HEAD
FILESIZE=$(stat --printf="%s" "${FILE}")
echo "File zipped, ${FILESIZE} bytes"
unzip -v "${FILE}"

# Query the mod info, verify the version number we're trying to push doesn't already exist
curl -s "https://mods.factorio.com/api/mods/${NAME}/full" | jq -e ".releases[] | select(.version == \"${VERSION}\")"
# store the return code before running anything else
STATUS_CODE=$?

if [[ $STATUS_CODE -ne 4 ]]; then
    echo "Release already exists, skipping"
    exit 0
fi
echo "Release doesn't exist for ${VERSION}, uploading"

AUTH_HEADER="Authorization: Bearer ${INPUT_MOD_API_KEY}"

# https://wiki.factorio.com/Mod_publish_API

INIT_PUBLISH_RESULT=$(curl -s --data "{\"mod\":\"${NAME}\"}" -H "Content-Type: application/json" "https://mods.factorio.com/api/v2/mods/init_publish" -H "${AUTH_HEADER}" -X POST)

PUBLISH_URL=$(echo "${INIT_PUBLISH_RESULT}" | jq -r '@uri "\(.upload_url)"')
PUBLISH_ERROR=$(echo "${INIT_PUBLISH_RESULT}" | jq -r '@uri "\(.error)"')
PUBLISH_MESSAGE=$(echo "${INIT_PUBLISH_RESULT}" | jq -r '@uri "\(.message)"')

if [[ "${PUBLISH_ERROR}" != "null" ]]; then
    echo "Init upload failed:"
    echo "${PUBLISH_ERROR}"
    echo "${PUBLISH_MESSAGE}"
    exit 1
fi

FINISH_PUBLISH_RESULT=$(curl -s -X POST -F "file=@${FILE};type=application/x-zip-compressed" -o /dev/null "${PUBLISH_URL}")

PUBLISHED_URL=$(echo "${FINISH_PUBLISH_RESULT}" | jq -r '@uri "\(.url)"')
PUBLISH_ERROR=$(echo "${FINISH_PUBLISH_RESULT}" | jq -r '@uri "\(.error)"')
PUBLISH_MESSAGE=$(echo "${FINISH_PUBLISH_RESULT}" | jq -r '@uri "\(.message)"')

if [[ "${PUBLISH_ERROR}" != "null" ]]; then
    echo "Init upload failed:"
    echo "${PUBLISH_ERROR}"
    echo "${PUBLISH_MESSAGE}"
    exit 1
fi

popd

echo "Mod published under ${PUBLISHED_URL}"
