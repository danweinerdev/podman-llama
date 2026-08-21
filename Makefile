all: build-rocm build-vulkan
build-rocm:
	podman build --squash-all --build-arg LLAMA_TAG=master -t llama-strix-halo:rocm -f Containerfile.rocm .
build-rocm-r9700:
	podman build --layers -t llama-r9700:rocm -f Containerfile.r9700-rocm .
build-vulkan:
	podman build --squash-all --build-arg LLAMA_TAG=master -t llama-strix-halo:vulkan -f Containerfile.vulkan .
