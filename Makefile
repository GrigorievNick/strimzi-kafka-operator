TOPDIR=$(dir $(lastword $(MAKEFILE_LIST)))

include ./Makefile.os

GITHUB_VERSION ?= master
RELEASE_VERSION ?= latest
CHART_PATH ?= ./helm-charts/strimzi-kafka-operator/
CHART_SEMANTIC_RELEASE_VERSION ?= $(shell cat ./release.version | tr A-Z a-z)

ifneq ($(RELEASE_VERSION),latest)
  GITHUB_VERSION = $(RELEASE_VERSION)
endif

SUBDIRS=kafka-agent crd-annotations test crd-generator api mockkube certificate-manager operator-common cluster-operator topic-operator user-operator kafka-init test-client docker-images helm-charts install examples metrics
DOCKER_TARGETS=docker_build docker_push docker_tag

all: $(SUBDIRS)
clean: $(SUBDIRS) docu_clean
$(DOCKER_TARGETS): $(SUBDIRS)
release: release_prepare release_version release_helm_version release_maven $(SUBDIRS) release_docu release_single_file release_pkg release_helm_repo docu_clean

next_version:
	echo $(shell echo $(NEXT_VERSION) | tr a-z A-Z) > release.version
	mvn versions:set -DnewVersion=$(shell echo $(NEXT_VERSION) | tr a-z A-Z)
	mvn versions:commit
	# Update OLM
	$(SED) -i 's/currentCSV: strimzi-cluster-operator.v.*\+/currentCSV: strimzi-cluster-operator.v$(NEXT_VERSION)/g' ./olm/strimzi-kafka-operator.package.yaml
	$(SED) -i 's/name: strimzi-cluster-operator.v.*/name: strimzi-cluster-operator.v$(NEXT_VERSION)/g' ./olm/strimzi-cluster-operator.clusterserviceversion.yaml
	$(SED) -i 's/version: [0-9]\+\.[0-9]\+\.[0-9]\+[a-zA-Z0-9_-]*.*/version: $(NEXT_VERSION)/g' ./olm/strimzi-cluster-operator.clusterserviceversion.yaml

release_prepare:
	echo $(shell echo $(RELEASE_VERSION) | tr a-z A-Z) > release.version
	rm -rf ./strimzi-$(RELEASE_VERSION)
	rm -f ./strimzi-$(RELEASE_VERSION).tar.gz
	mkdir ./strimzi-$(RELEASE_VERSION)

release_version:
	# TODO: This would be replaced ideally once Helm Chart templating is used for cluster and topic operator examples
	echo "Changing Docker image tags in install to :$(RELEASE_VERSION)"
	$(FIND) ./install -name '*.yaml' -type f -exec $(SED) -i '/image: "\?strimzi\/[a-zA-Z0-9_.-]\+:[a-zA-Z0-9_.-]\+"\?/s/:[a-zA-Z0-9_.-]\+/:$(RELEASE_VERSION)/g' {} \;
	$(FIND) ./install -name '*.yaml' -type f -exec $(SED) -i '/value: "\?strimzi\/operator:[a-zA-Z0-9_.-]\+"\?/s/strimzi\/operator:[a-zA-Z0-9_.-]\+/strimzi\/operator:$(RELEASE_VERSION)/g' {} \;
	$(FIND) ./install -name '*.yaml' -type f -exec $(SED) -i '/value: "\?strimzi\/kafka-bridge:[a-zA-Z0-9_.-]\+"\?/s/strimzi\/kafka-bridge:[a-zA-Z0-9_.-]\+/strimzi\/kafka-bridge:$(RELEASE_VERSION)/g' {} \;
	$(FIND) ./install -name '*.yaml' -type f -exec $(SED) -i '/value: "\?strimzi\/kafka:[a-zA-Z0-9_.-]\+"\?/s/strimzi\/kafka:[a-zA-Z0-9_.-]\+-kafka-\([0-9.]\+\)/strimzi\/kafka:$(RELEASE_VERSION)-kafka-\1/g' {} \;
	$(FIND) ./install -name '*.yaml' -type f -exec $(SED) -i '/[0-9.]\+=strimzi\/kafka[a-zA-Z0-9_.-]\?\+:[a-zA-Z0-9_.-]\+-kafka-[0-9.]\+"\?/s/:[a-zA-Z0-9_.-]\+-kafka-\([0-9.]\+\)/:$(RELEASE_VERSION)-kafka-\1/g' {} \;
	echo "Changing Docker image tags in olm to :$(RELEASE_VERSION)"
	$(FIND) ./olm -name '*.yaml' -type f -exec $(SED) -i '/containerImage: "\?docker.io\/strimzi\/operator:[a-zA-Z0-9_.-]\+"\?/s/strimzi\/operator:[a-zA-Z0-9_.-]\+/strimzi\/operator:$(RELEASE_VERSION)/g' {} \;
	$(FIND) ./olm -name '*.yaml' -type f -exec $(SED) -i '/image: "\?strimzi\/[a-zA-Z0-9_.-]\+:[a-zA-Z0-9_.-]\+"\?/s/:[a-zA-Z0-9_.-]\+/:$(RELEASE_VERSION)/g' {} \;
	$(FIND) ./olm -name '*.yaml' -type f -exec $(SED) -i '/value: "\?strimzi\/operator:[a-zA-Z0-9_.-]\+"\?/s/strimzi\/operator:[a-zA-Z0-9_.-]\+/strimzi\/operator:$(RELEASE_VERSION)/g' {} \;
	$(FIND) ./olm -name '*.yaml' -type f -exec $(SED) -i '/value: "\?strimzi\/kafka-bridge:[a-zA-Z0-9_.-]\+"\?/s/strimzi\/kafka-bridge:[a-zA-Z0-9_.-]\+/strimzi\/kafka-bridge:$(RELEASE_VERSION)/g' {} \;
	$(FIND) ./olm -name '*.yaml' -type f -exec $(SED) -i '/value: "\?strimzi\/kafka:[a-zA-Z0-9_.-]\+"\?/s/strimzi\/kafka:[a-zA-Z0-9_.-]\+-kafka-\([0-9.]\+\)/strimzi\/kafka:$(RELEASE_VERSION)-kafka-\1/g' {} \;
	$(FIND) ./olm -name '*.yaml' -type f -exec $(SED) -i '/[0-9.]\+=strimzi\/kafka[a-zA-Z0-9_.-]\?\+:[a-zA-Z0-9_.-]\+-kafka-[0-9.]\+"\?/s/:[a-zA-Z0-9_.-]\+-kafka-\([0-9.]\+\)/:$(RELEASE_VERSION)-kafka-\1/g' {} \;
	$(SED) -i 's/currentCSV: strimzi-cluster-operator.v.*\+/currentCSV: strimzi-cluster-operator.v$(RELEASE_VERSION)/g' ./olm/strimzi-kafka-operator.package.yaml
	$(SED) -i 's/name: strimzi-cluster-operator.v.*/name: strimzi-cluster-operator.v$(RELEASE_VERSION)/g' ./olm/strimzi-cluster-operator.clusterserviceversion.yaml
	$(SED) -i 's/version: [0-9]\+\.[0-9]\+\.[0-9]\+[a-zA-Z0-9_-]*.*/version: $(RELEASE_VERSION)/g' ./olm/strimzi-cluster-operator.clusterserviceversion.yaml

release_maven:
	echo "Update pom versions to $(RELEASE_VERSION)"
	mvn versions:set -DnewVersion=$(shell echo $(RELEASE_VERSION) | tr a-z A-Z)
	mvn versions:commit

release_pkg: helm_pkg	
	tar -z -cf ./strimzi-$(RELEASE_VERSION).tar.gz strimzi-$(RELEASE_VERSION)/
	zip -r ./strimzi-$(RELEASE_VERSION).zip strimzi-$(RELEASE_VERSION)/
	rm -rf ./strimzi-$(RELEASE_VERSION)

release_helm_version:
	echo "Updating default image tags in Helm Chart to $(RELEASE_VERSION)"
	# Update default image tag in chart values.yaml to RELEASE_VERSION
	$(SED) -i 's/\(tag: \).*/\1$(RELEASE_VERSION)/g' $(CHART_PATH)values.yaml
	# Update default image tagPrefix in chart values.yaml to RELEASE_VERSION
	$(SED) -i 's/\(tagPrefix: \).*/\1$(RELEASE_VERSION)/g' $(CHART_PATH)values.yaml
	# Update default image tag in chart README.md config grid with RELEASE_VERSION
	$(SED) -i 's/\(image\.tag[^\n]*| \)`.*`/\1`$(RELEASE_VERSION)`/g' $(CHART_PATH)README.md
	# Update default image tag in chart README.md config grid with RELEASE_VERSION
	$(SED) -i 's/\(image\.tagPrefix[^\n]*| \)`.*`/\1`$(RELEASE_VERSION)`/g' $(CHART_PATH)README.md

release_helm_repo:
	echo "Updating Helm Repository index.yaml"
	helm repo index ./ --url https://github.com/strimzi/strimzi-kafka-operator/releases/download/$(RELEASE_VERSION)/ --merge ./helm-charts/index.yaml
	mv ./index.yaml ./helm-charts/index.yaml

release_single_file:
	$(FIND) ./strimzi-$(RELEASE_VERSION)/install/cluster-operator/ -type f -exec cat {} \; -exec printf "\n---\n" \; > strimzi-cluster-operator-$(RELEASE_VERSION).yaml
	$(FIND) ./strimzi-$(RELEASE_VERSION)/install/topic-operator/ -type f -exec cat {} \; -exec printf "\n---\n" \; > strimzi-topic-operator-$(RELEASE_VERSION).yaml
	$(FIND) ./strimzi-$(RELEASE_VERSION)/install/user-operator/ -type f -exec cat {} \; -exec printf "\n---\n" \; > strimzi-user-operator-$(RELEASE_VERSION).yaml

helm_pkg:
	# Copying unarchived Helm Chart to release directory
	mkdir -p strimzi-$(RELEASE_VERSION)/charts/
	$(CP) -r $(CHART_PATH) strimzi-$(RELEASE_VERSION)/charts/$(CHART_NAME)
	# Packaging helm chart with semantic version: $(CHART_SEMANTIC_RELEASE_VERSION)
	helm package --version $(CHART_SEMANTIC_RELEASE_VERSION) --app-version $(CHART_SEMANTIC_RELEASE_VERSION) --destination ./ $(CHART_PATH)
	mv strimzi-kafka-operator-$(CHART_SEMANTIC_RELEASE_VERSION).tgz strimzi-kafka-operator-helm-chart-$(CHART_SEMANTIC_RELEASE_VERSION).tgz
	rm -rf strimzi-$(RELEASE_VERSION)/charts/

.PHONY: docu_versions
docu_versions: documentation/*.sh kafka-versions
	documentation/snip-kafka-versions.sh kafka-versions > documentation/book/snip-kafka-versions.adoc
	documentation/version-dependent-attrs.sh kafka-versions > documentation/book/common/version-dependent-attrs.adoc
	documentation/snip-images.sh kafka-versions > documentation/book/snip-images.adoc

generated_docs := documentation/book/snip-kafka-versions.adoc \
  documentation/book/common/version-dependent-attrs.adoc \
  documentation/book/snip-images.adoc

documentation/book/snip-kafka-versions.adoc: documentation/snip-kafka-versions.sh kafka-versions
	documentation/snip-kafka-versions.sh kafka-versions > documentation/book/snip-kafka-versions.adoc

documentation/book/common/version-dependent-attrs.adoc: documentation/version-dependent-attrs.sh kafka-versions
	documentation/version-dependent-attrs.sh kafka-versions > documentation/book/common/version-dependent-attrs.adoc

documentation/book/snip-images.adoc: documentation/snip-images.sh kafka-versions
	documentation/snip-images.sh kafka-versions > documentation/book/snip-images.adoc

.docu_check: $(generated_docs)
	./.travis/check_docs.sh
	touch .docu_check

doc_src := $(shell find documentation/book documentation/common -type f)

# $(call asciidoctor,platform,adoc_file,output_file,extra_options)
define asciidoctor
  mkdir -p $$(dirname "$3")
  $(CP) -vrL documentation/book/images $$(dirname "$3")/images
  asciidoctor -v --failure-level ERROR -t -dbook \
  -a "platform=$1" \
  -a ProductVersion=$(RELEASE_VERSION) \
  -a GithubVersion=$(GITHUB_VERSION) \
  $4 "$2" -o "$3"
  @ if grep -Er --include='*.html' '{cmdcli}' $@; then \
    echo "ERROR: Found non-substituted attribute '{cmdcli}' in doc (see above)" ; \
    echo '       Maybe subs="attributes+" is what you need?' ; \
    touch $< ; \
    false ; \
  fi
endef

documentation/html/index.html: $(doc_src)
# Combined doc
	#./.travis/check_docs.sh
	$(call asciidoctor,combined,documentation/book/master.adoc,$@)

documentation/htmlnoheader/index.html: $(doc_src)
# Combined doc
	#./.travis/check_docs.sh
	$(call asciidoctor,combined,documentation/book/master.adoc,$@,-s)

documentation/kubernetes/index.html: $(doc_src)
# Kubernetes-specific doc
	#./.travis/check_docs.sh
	$(call asciidoctor,kubernetes,documentation/book/master.adoc,$@)
# Check rendered kubernetes doc for Openshift-isms:
# Avoid use of oc in the kube doc
	@ if grep -Er --include='*.html' '(^|[^a-zA-Z0-9])oc[^a-zA-Z0-9]' $@; then \
	  echo "ERROR: Found 'oc' in kubernetes doc (see above)" ; \
	  echo "       Maybe '{cmdcli}' is what you need?" ; \
	  echo "       Or 'ifdef::OpenShift[]'/'endif::[]' perhaps?" ; \
	  touch $< ; \
	  false ; \
	fi
# Prevent openshift in the kube doc too, except for api groups mentioned in the ClusterRoles
#	 TODO This doesn't quite work because:
#	 1) Currently some metrics examples are in a directory with openshift in the name
#	 2) The generated API docs talk about OpenShift things
#	grep -wri --include='*.html' 'OpenShift' documentation/kubernetes/ | \
#	  grep -Ev '(apps|build|image|route)\.openshift.io' \
#	  && echo -e "ERROR: Found 'OpenShift' in kubernetes doc (see above).\n" \
#	             "      Either use '{cmdcli}' or enclose between 'ifdef::OpenShift[]' and 'endif::[]'." \
#	  && touch documentation/book/master.adoc
#	  || echo "No 'OpenShift' in kubernetes doc (good)"

documentation/openshift/index.html: $(doc_src)
# OpenShift-specific doc
	#./.travis/check_docs.sh
	$(call asciidoctor,openshift,documentation/book/master.adoc,$@)
# Check rendered openshift doc for Kubernetes-isms:
# mention of Kubernetes is OK, but there should be no need for kubectl commands
# but we allow kubectl in urls
	@ if grep -Er --include='*.html' '(^|[^a-zA-Z0-9])kubectl[^a-zA-Z0-9]' $@ |\
	  grep -Ev 'https?://[:/.a-zA-Z0-9-]*kubectl'; then \
	  echo "ERROR: Found 'kubectl' in openshift doc (see above)." ;\
	  echo "       Either use '{cmdcli}' or enclose between 'ifdef::Kubernetes[]' and 'endif::[]'." ;\
	  touch $< ;\
	  false; \
	fi

contributing_src:=$(shell find documentation/contributing)
documentation/html/contributing.html: .docu_check $(contributing_src)
# Contributing guide
	asciidoctor -v --failure-level WARN -t -dbook \
	-a ProductVersion=$(RELEASE_VERSION) \
	-a GithubVersion=$(GITHUB_VERSION) \
	documentation/contributing/master.adoc -o $@

documentation/htmlnoheader/contributing.html: .docu_check $(contributing_src)
	asciidoctor -v --failure-level WARN -t -dbook \
	-a ProductVersion=$(RELEASE_VERSION) \
	-a GithubVersion=$(GITHUB_VERSION) \
	-s \
	documentation/contributing/master.adoc -o $@

.PHONY: docu_html
docu_html: documentation/html/index.html documentation/htmlnoheader/index.html \
  documentation/kubernetes/index.html documentation/openshift/index.html \
  documentation/html/contributing.html documentation/htmlnoheader/contributing.html

findbugs: $(SUBDIRS)

docu_pushtowebsite: docu_html
	./.travis/docu-push-to-website.sh

pushtonexus:
	./.travis/push-to-nexus.sh

.PHONY: release_docu
release_docu: docu_html
	mkdir -p strimzi-$(RELEASE_VERSION)/docs
	$(CP) -rv documentation/html/index.html strimzi-$(RELEASE_VERSION)/docs/
	$(CP) -rv documentation/html/images/ strimzi-$(RELEASE_VERSION)/docs/images/

.PHONY: docu_clean
docu_clean: docu_htmlclean

.PHONY: docu_htmlclean
docu_htmlclean:
	rm -rf .docu_check documentation/html documentation/htmlnoheader documentation/kubernetes documentation/openshift

systemtests:
	./systemtest/scripts/run_tests.sh $(SYSTEMTEST_ARGS)

helm_install: helm-charts

crd_install: install

$(SUBDIRS):
	$(MAKE) -C $@ $(MAKECMDGOALS)

.PHONY: all $(SUBDIRS) $(DOCKER_TARGETS) systemtests findbugs
