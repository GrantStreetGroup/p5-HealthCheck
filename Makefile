PERL_CARTON_PERL5LIB := ./lib:$(PERL5LIB):$(PERL_CARTON_PERL5LIB)
export PERL_CARTON_PERL5LIB

CPANFILE := $(wildcard cpanfile cpanfile.prerelease/*)

# Not sure how to use the .perl-version target before we have it
CPANFILE_SNAPSHOT := $(shell \
  PLENV_VERSION=$$( plenv which carton 2>&1 | grep '^  5' | tail -1 ); \
  [ -n "$$PLENV_VERSION" ] && plenv local $$PLENV_VERSION; \
  carton exec perl -MFile::Spec -E \
	'($$_) = grep { -e } map{ "$$_/../../cpanfile.snapshot" } \
		grep { m(/lib/perl5$$) } @INC; \
		say File::Spec->abs2rel($$_) if $$_' )

ifndef CPANFILE_SNAPSHOT
	CPANFILE_SNAPSHOT := .MAKE
endif

.PHONY : test

test : $(CPANFILE_SNAPSHOT)
	@nice carton exec prove -lfr t

# This target requires that you add 'requires "Devel::Cover";'
# to the cpanfile and then run "carton" to install it.
testcoverage : $(CPANFILE_SNAPSHOT)
	carton exec -- cover -test -ignore . -select ^lib

$(CPANFILE_SNAPSHOT): .perl-version $(CPANFILE)
	carton install

.perl-version:
	plenv local $$( plenv whence carton | grep '^5' | tail -1 )

clean:
	rm -rf cover_db
