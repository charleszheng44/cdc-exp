.PHONY: clean

clean:
	kind delete cluster -n cdc-test
	-rm Dockerfile

build-debug-image: build_debug_img.sh
	./build_debug_img.sh

deploy: deploy.sh
	./deploy.sh
