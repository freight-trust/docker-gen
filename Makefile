.SILENT :
.PHONY : docker-gen dist dist-clean release check-gofmt test

TAG:=$(shell git describe --tags)
LDFLAGS:=-X main.buildVersion=$(TAG)
# https://stackoverflow.com/a/58185179
LDFLAGS_EXTRA=-linkmode external -w -extldflags "-static"

all: docker-gen

docker-gen:
	echo "Building docker-gen"
	go build -ldflags "$(LDFLAGS) $(LDFLAGS_EXTRA)" ./cmd/docker-gen

dist-clean:
	go mod tidy
	rm -rf dist release/
	rm -f docker-gen

dist: dist-clean
	mkdir -p dist/alpine-linux/amd64 && GOOS=linux GOARCH=amd64 go build -ldflags "$(LDFLAGS) ${LDFLAGS_EXTRA}" -a -tags netgo -installsuffix netgo -o dist/alpine-linux/amd64/docker-gen ./cmd/docker-gen
	mkdir -p dist/alpine-linux/arm64 && GOOS=linux GOARCH=arm64 go build -ldflags "$(LDFLAGS)" -a -tags netgo -installsuffix netgo -o dist/alpine-linux/arm64/docker-gen ./cmd/docker-gen
	mkdir -p dist/alpine-linux/armhf && GOOS=linux GOARCH=arm GOARM=6 go build -ldflags "$(LDFLAGS)" -a -tags netgo -installsuffix netgo -o dist/alpine-linux/armhf/docker-gen ./cmd/docker-gen
	mkdir -p dist/linux/amd64 && GOOS=linux GOARCH=amd64 go build -ldflags "$(LDFLAGS) ${LDFLAGS_EXTRA}" -o dist/linux/amd64/docker-gen ./cmd/docker-gen
	mkdir -p dist/linux/arm64 && GOOS=linux GOARCH=arm64 go build -ldflags "$(LDFLAGS)" -o dist/linux/arm64/docker-gen ./cmd/docker-gen
	mkdir -p dist/linux/i386  && GOOS=linux GOARCH=386 go build -ldflags "$(LDFLAGS)" -o dist/linux/i386/docker-gen ./cmd/docker-gen
	mkdir -p dist/linux/armel  && GOOS=linux GOARCH=arm GOARM=5 go build -ldflags "$(LDFLAGS)" -o dist/linux/armel/docker-gen ./cmd/docker-gen
	mkdir -p dist/linux/armhf  && GOOS=linux GOARCH=arm GOARM=6 go build -ldflags "$(LDFLAGS)" -o dist/linux/armhf/docker-gen ./cmd/docker-gen
	mkdir -p dist/darwin/amd64 && GOOS=darwin GOARCH=amd64 go build -ldflags "$(LDFLAGS)" -o dist/darwin/amd64/docker-gen ./cmd/docker-gen
	mkdir -p dist/darwin/i386  && GOOS=darwin GOARCH=386 go build -ldflags "$(LDFLAGS)" -o dist/darwin/i386/docker-gen ./cmd/docker-gen

release: dist
	mkdir -p release
	tar -cvzf release/docker-gen-alpine-linux-amd64-$(TAG).tar.gz -C dist/alpine-linux/amd64 docker-gen
	tar -cvzf release/docker-gen-alpine-linux-arm64-$(TAG).tar.gz -C dist/alpine-linux/arm64 docker-gen
	tar -cvzf release/docker-gen-alpine-linux-armhf-$(TAG).tar.gz -C dist/alpine-linux/armhf docker-gen
	tar -cvzf release/docker-gen-linux-amd64-$(TAG).tar.gz -C dist/linux/amd64 docker-gen
	tar -cvzf release/docker-gen-linux-arm64-$(TAG).tar.gz -C dist/linux/arm64 docker-gen
	tar -cvzf release/docker-gen-linux-i386-$(TAG).tar.gz -C dist/linux/i386 docker-gen
	tar -cvzf release/docker-gen-linux-armel-$(TAG).tar.gz -C dist/linux/armel docker-gen
	tar -cvzf release/docker-gen-linux-armhf-$(TAG).tar.gz -C dist/linux/armhf docker-gen
	tar -cvzf release/docker-gen-darwin-amd64-$(TAG).tar.gz -C dist/darwin/amd64 docker-gen
	tar -cvzf release/docker-gen-darwin-i386-$(TAG).tar.gz -C dist/darwin/i386 docker-gen

get-deps:

check-gofmt:
	if [ -n "$(shell gofmt -l .)" ]; then \
		echo 1>&2 'The following files need to be formatted:'; \
		gofmt -l .; \
		exit 1; \
	fi

test:
	go test ./...

# build docker image from either latest release on github or local directory
# BUILD_ENV: (github | local) default=github
.PHONY: docker-image
docker-image:
	docker build -t docker-gen . --build-arg BUILD_ENV=$${BUILD_ENV:-github}
	docker tag docker-gen docker-gen:$(shell docker run --rm -it docker-gen:latest -version)
