EPOCH_TEST_COMMIT	:= 91d6d8466e68f1efff7977b63ad6f48e72245e05

DOCKER		?= $(shell command -v docker 2>/dev/null)
PANDOC		?= $(shell command -v pandoc 2>/dev/null)

OUTPUT_DIRNAME	?= output/
DOC_FILENAME	?= oci-distribution-spec

PANDOC_CONTAINER ?= docker.io/vbatts/pandoc:1.19.1-3.fc27.x86_64
ifeq "$(strip $(PANDOC))" ''
	ifneq "$(strip $(DOCKER))" ''
		PANDOC = $(DOCKER) run \
			-it \
			--rm \
			-v $(shell pwd)/:/input/:ro \
			-v $(shell pwd)/$(OUTPUT_DIRNAME)/:/$(OUTPUT_DIRNAME)/ \
			-u $(shell id -u) \
			--workdir /input \
			$(PANDOC_CONTAINER)
		PANDOC_SRC := /input/
		PANDOC_DST := /
	endif
endif

DOC_FILES	:= spec.md
FIGURE_FILES	:=

test: .gitvalidation

# When this is running in travis, it will only check the travis commit range
.gitvalidation:
	@command -v git-validation >/dev/null 2>/dev/null || (echo "ERROR: git-validation not found. Consider 'make install.tools' target" && false)
ifdef TRAVIS_COMMIT_RANGE
	git-validation -q -run DCO,short-subject,dangling-whitespace
else
	git-validation -v -run DCO,short-subject,dangling-whitespace -range $(EPOCH_TEST_COMMIT)..HEAD
endif

docs: $(OUTPUT_DIRNAME)/$(DOC_FILENAME).pdf $(OUTPUT_DIRNAME)/$(DOC_FILENAME).html

ifeq "$(strip $(PANDOC))" ''
$(OUTPUT_DIRNAME)/$(DOC_FILENAME).pdf: $(DOC_FILES) $(FIGURE_FILES)
	$(error cannot build $@ without either pandoc or docker)
else
$(OUTPUT_DIRNAME)/$(DOC_FILENAME).pdf: $(DOC_FILES) $(FIGURE_FILES)
	mkdir -p $(OUTPUT_DIRNAME)/ && \
	$(PANDOC) -f markdown_github -t latex --latex-engine=xelatex -o $(PANDOC_DST)$@ $(patsubst %,$(PANDOC_SRC)%,$(DOC_FILES))
	ls -sh $(realpath $@)

$(OUTPUT_DIRNAME)/$(DOC_FILENAME).html: header.html $(DOC_FILES) $(FIGURE_FILES)
	mkdir -p $(OUTPUT_DIRNAME)/ && \
	cp -ap img/ $(shell pwd)/$(OUTPUT_DIRNAME)/&& \
	$(PANDOC) -f markdown_github -t html5 -H $(PANDOC_SRC)header.html --standalone -o $(PANDOC_DST)$@ $(patsubst %,$(PANDOC_SRC)%,$(DOC_FILES))
	ls -sh $(realpath $@)
endif

header.html: .tool/genheader.go specs-go/version.go
	go run .tool/genheader.go > $@

install.tools: .install.gitvalidation

.install.gitvalidation:
	go get -u github.com/vbatts/git-validation
