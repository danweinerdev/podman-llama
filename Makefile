all: build-rocm build-vulkan
build-rocm:
	podman build --squash-all --build-arg LLAMA_TAG=master -t llama-strix-halo:rocm -f Containerfile.rocm .
build-vulkan:
	podman build --squash-all --build-arg LLAMA_TAG=master -t llama-strix-halo:vulkan -f Containerfile.vulkan .
