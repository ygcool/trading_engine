
COMMIT = `git rev-parse HEAD`
BUILDTIME = `date +'%Y-%m-%d_%T'`
GOVER = `go env GOVERSION`
utils = "github.com/yzimhao/trading_engine/utils/app"

version ?= "0.0.0"

mainname = "haotrader"
distdir = "./dist"
exedir = "$(distdir)/$(mainname)"



test:
	go test -v ./...
dist:
	mkdir -p $(exedir)
clean:
	rm -rf $(distdir)


define build_haomatch
	@echo "Building for haomatch $1 $2"
	CGO_ENABLED=1 GOOS=$1 GOARCH=$2 CC=$4 go build -ldflags="-s -w -X $(utils).Version=${version} -X $(utils).Commit=$(COMMIT) -X $(utils).Build=$(BUILDTIME) -X $(utils).Goversion=$(GOVER)" -o $(exedir)/haomatch$3 cmd/haomatch/main.go
	upx -9 $(exedir)/haomatch$3
endef

define build_haosettle
	@echo "Building for haosettle $1 $2"
	CGO_ENABLED=1 GOOS=$1 GOARCH=$2 CC=$4 go build -ldflags="-s -w -X $(utils).Version=${version} -X $(utils).Commit=$(COMMIT) -X $(utils).Build=$(BUILDTIME) -X $(utils).Goversion=$(GOVER)" -o $(exedir)/haosettle$3 cmd/haosettle/main.go
	upx -9 $(exedir)/haosettle$3
endef


define build_haoquote
	@echo "Building for haoquote $1 $2"
	CGO_ENABLED=1 GOOS=$1 GOARCH=$2 CC=$4 go build -ldflags="-s -w -X $(utils).Version=${version} -X $(utils).Commit=$(COMMIT) -X $(utils).Build=$(BUILDTIME) -X $(utils).Goversion=$(GOVER)" -o $(exedir)/haoquote$3 cmd/haoquote/main.go
	upx -9 $(exedir)/haoquote$3
endef


define build_haobase
	@echo "Building for haobase $1 $2"
	CGO_ENABLED=1 GOOS=$1 GOARCH=$2 CC=$4 go build -ldflags="-s -w -X $(utils).Version=${version} -X $(utils).Commit=$(COMMIT) -X $(utils).Build=$(BUILDTIME) -X $(utils).Goversion=$(GOVER)" -o $(exedir)/haobase$3 cmd/haobase/main.go
	upx -9 $(exedir)/haobase$3
endef

define build_haoadm
	@echo "Building for haoadm $1 $2"
	CGO_ENABLED=1 GOOS=$1 GOARCH=$2 CC=$4 go build -ldflags="-s -w -X $(utils).Version=${version} -X $(utils).Commit=$(COMMIT) -X $(utils).Build=$(BUILDTIME) -X $(utils).Goversion=$(GOVER)" -o $(exedir)/haoadm$3 cmd/haoadm/main.go
	upx -9 $(exedir)/haoadm$3

	cp -r cmd/haoadm/template $(exedir)/
endef


define build_allinone
	@echo "Building for haotrader $1 $2"
	CGO_ENABLED=1 GOOS=$1 GOARCH=$2 CC=$4 go build -ldflags="-s -w -X $(utils).Version=${version} -X $(utils).Commit=$(COMMIT) -X $(utils).Build=$(BUILDTIME) -X $(utils).Goversion=$(GOVER)" -o $(exedir)/haotrader$3 cmd/allinone.go
	upx -9 $(exedir)/haotrader$3
	cp -r cmd/haoadm/template $(exedir)/
endef





copy_file:

	cp README.md $(exedir)/
	cp -rf cmd/config.toml $(exedir)/config.toml_sample

define zipfile
	# tar
	cd $(distdir) && tar czvf $(mainname).$(version).$1-$2.tar.gz `basename $(exedir)`
	# zip
	cd $(distdir) && zip -r -m $(mainname).$(version).$1-$2.zip `basename $(exedir)` -x "*/\.*"
endef

build_all_linux_amd64: dist copy_file
	$(call build_haobase,linux,amd64,'',x86_64-unknown-linux-gnu-gcc)
	$(call build_haomatch,linux,amd64,'',x86_64-unknown-linux-gnu-gcc)
	$(call build_haoquote,linux,amd64,'',x86_64-unknown-linux-gnu-gcc)
	$(call build_haoadm,linux,amd64,'',x86_64-unknown-linux-gnu-gcc)
	
	$(call zipfile,linux,amd64)
	

build_allinone_linux_amd64: dist copy_file
	$(call build_allinone,linux,amd64,'',x86_64-unknown-linux-gnu-gcc)

	$(call zipfile,linux,amd64)


release: clean
	# @make build_all_linux_amd64
	@make build_allinone_linux_amd64
	



example_upload: clean dist build_allinone_linux_amd64
	mkdir -p $(distdir)/trading_engine_example
	cd example && CGO_ENABLED=1 GOOS=linux GOARCH=amd64 CC=x86_64-unknown-linux-gnu-gcc go build -o ../$(distdir)/trading_engine_example/example example.go
	upx -9 $(distdir)/trading_engine_example/example
	cp -rf example/statics $(distdir)/trading_engine_example/
	cp -rf example/demo.html $(distdir)/trading_engine_example/
	scp -r $(distdir)/trading_engine_example/ demo:~/
	
	

	scp $(distdir)/haotrader.$(version).linux-amd64.tar.gz demo:~/
	ssh demo "tar xzvf haotrader.$(version).linux-amd64.tar.gz"
	ssh demo 'rm -f haotrader.$(version).linux-amd64.tar.gz'
# 一些辅助
	scp stop.sh demo:~/
	



example_start:

	ssh demo 'cd haotrader/ && ./haotrader -d'
	ssh demo 'cd trading_engine_example/ && ./example -d --bot --interval_min=1 --interval_max=10 --limit_size=500 --lots=10'


example_stop:
   	
	ssh demo 'sh -x stop.sh'

example_clean:
	
	ssh demo 'cd haotrader/ && rm -f cache/*.db'
	ssh demo 'cd haotrader/ && rm -f logs/*.log'
	ssh demo 'mysql -h127.0.0.1 -P 23306 -uroot -proot -e "drop database haotrader"'
	ssh demo 'mysql -h127.0.0.1 -P 23306 -uroot -proot -e "create database haotrader"'
	ssh demo 'redis-cli -p 26379 flushall'
	

example_download_logs:

	scp -r demo:~/haotrader/logs ~/Downloads/


example_reload: example_upload example_stop example_start
example_restart: example_upload example_stop example_clean example_start	


clean_localdb:

	mysql -h db_host -proot -e "drop database haotrader"
	mysql -h db_host -proot -e "create database haotrader"
	redis-cli -h db_host -p 6379 flushall
	

local_start:

	go run cmd/haotrader/main.go -d



require:
	brew tap messense/macos-cross-toolchains
	# install x86_64-unknown-linux-gnu toolchain
	brew install x86_64-unknown-linux-gnu
	
	brew install upx
	


tag:
	git tag -a $(version)
	git push --tags

.PHONY: dist clean build release
	