# Makefile for cleanchrome
# $Id: Makefile 1205 2012-04-03 00:01:20Z ranga $

PGM_NAME = cleanchrome
PGM_REL  = 0.1.5
WORKDIR = work
FILES = cleanchrome.pl cleanchrome.1 Makefile README.txt LICENSE.txt

all:
	@echo Nothing to do

tgz:
	/bin/rm -rf $(WORKDIR)
	mkdir -p $(WORKDIR)/$(PGM_NAME)-$(PGM_REL)	
	cp $(FILES) $(WORKDIR)/$(PGM_NAME)-$(PGM_REL)
	cd $(WORKDIR) && \
        tar -cvf ../$(PGM_NAME)-$(PGM_REL).tar $(PGM_NAME)-$(PGM_REL)
	gzip $(PGM_NAME)-$(PGM_REL).tar
	mv $(PGM_NAME)-$(PGM_REL).tar.gz $(PGM_NAME)-$(PGM_REL).tgz

install:
	@echo "Please do the following:"
	@echo
	@echo "mkdir -p ~/bin ~/man/man1"
	@echo "cp $(PGM_NAME).pl ~/bin"
	@echo "cp $(PGM_NAME).1 ~/man/man1"
	@echo
	@echo "Add ~/bin to PATH and ~/man to MANPATH"

clean:
	/bin/rm -rf *~ .*~ .DS_Store $(WORKDIR) $(PGM_NAME)*.tgz \
                $(PGM_NAME).1.txt $(PGM_NAME)*.asc

man2txt: $(PGM_NAME).1.txt

$(PGM_NAME).1.txt:
	nroff -Tascii -man $(PGM_NAME).1 | col -b -x > $(PGM_NAME).1.txt

