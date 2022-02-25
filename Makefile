
# install xml2rfc with "pip install xml2rfc"
# install mmark from https://github.com/mmarkdown/mmark 
# install pandoc from https://pandoc.org/installing.html
# install lib/rr.war from https://bottlecaps.de/rr/ui or https://github.com/GuntherRademacher/rr

.PHONE: all clean lint format

all: gen/draft-jennings-moq-architecture.txt

clean:
	rm -rf gen/*

lint: gen/draft-jennings-moq-architecture.xml
	rfclint gen/draft-jennings-moq-architecture.xml

format:
	mkdir -p gen
	mmark  moq-arch.md >  gen/moq-arch.md
	echo updated MD is in  gen/moq-arch.md

gen/draft-jennings-moq-architecture.xml: rfc.md abstract.md  moq-arch.md contributors.md
	mkdir -p gen
	mmark  rfc.md > gen/draft-jennings-moq-architecture.xml

gen/draft-jennings-moq-architecture.txt: gen/draft-jennings-moq-architecture.xml
	xml2rfc --text --v3 gen/draft-jennings-moq-architecture.xml

gen/draft-jennings-moq-architecture.pdf: gen/draft-jennings-moq-architecture.xml
	xml2rfc --pdf --v3 gen/draft-jennings-moq-architecture.xml

gen/draft-jennings-moq-architecture.html: gen/draft-jennings-moq-architecture.xml
	xml2rfc --html --v3 gen/draft-jennings-moq-architecture.xml

gen/doc-jennings-moq-architecture.pdf: abstract.md  moq-arch.md contributors.md 
	mkdir -p gen 
	pandoc -s title.md abstract.md  moq-arch.md contributors.md -o gen/doc-jennings-moq-architecture.pdf

