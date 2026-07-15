mkdir -p build

id=$(jq -r '.KPlugin.Id' metadata.json)
version=$(jq -r '.KPlugin.Version' metadata.json)

tar cfJ "build/$id-$version.tar.xz" contents/ metadata.json
