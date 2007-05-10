#
# potool is a program aiding editing of po files
# Copyright (C) 1999-2002 Zbigniew Chyla
# Copyright (C) 2000-2007 Marcin Owsiany
#
# see LICENSE for licensing info
#

VER = 0.7

DESTDIR = /usr/local
BINDIR = $(DESTDIR)/bin
INSTALL = install
BININSTALL = $(INSTALL) -s
GTAR = tar

GLIB_LIB = $(shell pkg-config --libs glib-2.0)
GLIB_INCLUDE = $(shell pkg-config --cflags glib-2.0)
CFLAGS = $(GLIB_INCLUDE) -g -Wall -O2
LDFLAGS = $(GLIB_LIB)

THINGS  = potool po.tab lex.po
OBJS    = $(addsuffix .o, $(THINGS))
SOURCES = $(addsuffix .c, $(THINGS))

potool: $(OBJS)
	$(CC) $(LDFLAGS) -o $@ $^

$(OBJS): %.o : %.c

po.tab.o lex.po.c lex.po.o: po-gram.h common.h

lex.po.c: po-gram.lex
	flex -Ppo $<
#	flex --debug -Ppo $<

po.tab.c: po-gram.y
	bison -ppo -bpo -d $<

install: potool
	$(BININSTALL) potool $(BINDIR)
	$(INSTALL) scripts/poedit $(BINDIR)
	$(INSTALL) scripts/postats $(BINDIR)
	$(INSTALL) scripts/postats1 $(BINDIR)
	$(INSTALL) scripts/poupdate $(BINDIR)

clean:
	rm -f $(OBJS) *~ lex.po.c po.tab.[ch] potool scripts/*~

dist:
	cd ..; \
	 rm -f potool-$(VER).tar{,.gz} potool-$(VER); \
	 ln -s potool potool-$(VER); \
	 $(GTAR) --exclude='*/CVS' --exclude='*/.cvsignore' --owner=root --group=root -hcf potool-$(VER).tar potool-$(VER) && \
	 gzip -9 potool-$(VER).tar
