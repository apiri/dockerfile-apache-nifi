NAME = apiri/apache-nifi
VERSION = 0.0.1-incubating

.PHONY: all nifi-$(VERSION)-bin.tar.gz distribution build test tag_latest release

all: build

nifi-$(VERSION)-bin.tar.gz:
	wget -N http://www.gtlib.gatech.edu/pub/apache/incubator/nifi/$(VERSION)/nifi-$(VERSION)-bin.tar.gz
	touch $@

build: nifi-$(VERSION)-bin.tar.gz
	docker build --rm -t $(NAME):$(VERSION) .

tag_latest:
	docker tag -f $(NAME):$(VERSION) $(NAME):latest

release: tag_latest
	@if ! docker images $(NAME) | awk '{ print $$2 }' | grep -q -F $(VERSION); then echo "$(NAME) version $(VERSION) is not yet built. Please run 'make build'"; false; fi
	docker push $(NAME)
	@echo "*** Don't forget to create a tag. git tag rel-$(VERSION) && git push origin rel-$(VERSION)"
