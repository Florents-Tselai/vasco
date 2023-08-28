EXTENSION = vasco
EXTVERSION = 0.2.0

PG_CONFIG ?= pg_config

# Do not hardcode them here, but pick them up from the .control file
EXT_CTRL_FILE = $(EXTENSION).control
PGFILEDESC = $(shell cat $(EXT_CTRL_FILE) | grep 'comment' | sed "s/^.*'\(.*\)'$\/\1/g")
EXT_REQUIRES = $(shell cat $(EXT_CTRL_FILE) | grep 'requires' | sed "s/^.*'\(.*\)'$\/\1/g")
PGVERSION = $(shell $(PG_CONFIG) --version | sed "s/PostgreSQL //g")
LICENSE = LICENSE

MODULE_big = $(EXTENSION)

OBJS = \
	src/mine.o \
	src/vasco.o

EXT_SQL_FILE = sql/$(EXTENSION)--$(EXTVERSION).sql

# Order of .sql files matters!
SQL_FILES = sql/preamble.sql \
			sql/schemas.sql \
			sql/vasco.sql \
			sql/explore.sql

ifdef WITH_PGVECTOR
SQL_FILES += sql/vasco_pgvector.sql
endif

$(EXT_SQL_FILE): $(SQL_FILES)
	@cat $^ > $@

all: $(EXT_SQL_FILE)

DATA = $(wildcard sql/*--*.sql) #$(EXT_SQL_FILE)

EXTRA_CLEAN += dist $(EXT_SQL_FILE) *.png

.PHONY: dist
dist:
	mkdir -p dist
	git archive --format zip --prefix=$(EXTENSION)-$(EXTVERSION)/ --output dist/$(EXTENSION)-$(EXTVERSION).zip main

ifdef DEBUG
COPT			+= -O0 -Werror -g

ASSEMBLY_FILE = $(MODULE_big).s

$(ASSEMBLY_FILE): $(MODULE_big)
	objdump -d $(MODULE_big).o > $@

EXTRA_CLEAN += $(ASSEMBLY_FILE)
endif

PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

