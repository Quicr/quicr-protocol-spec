
# install xml2rfc with "pip install xml2rfc"
# install mmark from https://github.com/mmarkdown/mmark 
# install pandoc from https://pandoc.org/installing.html
# install lib/rr.war from https://bottlecaps.de/rr/ui or https://github.com/GuntherRademacher/rr

.PHONE: all clean lint format

all: gen/draft-jennings-moq-proto.txt

html: gen/draft-jennings-moq-proto.html

clean:
	rm -rf gen/*

lint: gen/draft-jennings-moq-proto.xml
	rfclint gen/draft-jennings-moq-proto.xml

gen/draft-jennings-moq-proto.xml: abstract.md contributors.md introduction.md manifest.md naming.md protocol.md relay.md rfc.md title.md
	mkdir -p gen
	mmark  rfc.md > gen/draft-jennings-moq-proto.xml

gen/draft-jennings-moq-proto.txt: gen/draft-jennings-moq-proto.xml
	xml2rfc --text --v3 gen/draft-jennings-moq-proto.xml

gen/draft-jennings-moq-proto.pdf: gen/draft-jennings-moq-proto.xml
	xml2rfc --pdf --v3 gen/draft-jennings-moq-proto.xml

gen/draft-jennings-moq-proto.html: gen/draft-jennings-moq-proto.xml
	xml2rfc --html --v3 gen/draft-jennings-moq-proto.xml

gen/doc-jennings-moq-proto.pdf: title.md abstract.md introduction.md naming.md protocol.md manifest.md relay.md contributors.md
	mkdir -p gen 
	pandoc -s title.md abstract.md introduction.md naming.md protocol.md manifest.md relay.md contributors.md -o gen/doc-jennings-moq-proto.pdf

