Name:           t-digest
Version:        0.1.0
Release:        1%{?dist}
Summary:        Dunning t-digest implementations in multiple languages

License:        MIT
URL:            https://github.com/NadiaYvette/t-digest
Source0:        %{name}-%{version}.tar.gz

BuildArch:      noarch

%description
The t-digest is a data structure for accurate on-line accumulation of
rank-based statistics such as quantiles and trimmed means. This project
provides implementations of the Dunning t-digest algorithm in eight
programming languages: Ruby, Haskell, Common Lisp, Scheme, SML, Ada,
Prolog, and Mercury.

%package        doc
Summary:        Documentation for %{name}

%description    doc
Documentation files for the t-digest multi-language implementations.

%package        ruby
Summary:        Ruby implementation of the t-digest algorithm
Requires:       ruby

%description    ruby
Ruby implementation of the Dunning t-digest data structure for accurate
on-line accumulation of rank-based statistics.

%package        haskell
Summary:        Haskell implementation of the t-digest algorithm
Requires:       ghc

%description    haskell
Haskell implementation of the Dunning t-digest data structure for accurate
on-line accumulation of rank-based statistics.

%package        common-lisp
Summary:        Common Lisp implementation of the t-digest algorithm
Requires:       sbcl

%description    common-lisp
Common Lisp implementation of the Dunning t-digest data structure for accurate
on-line accumulation of rank-based statistics.

%package        scheme
Summary:        Scheme implementation of the t-digest algorithm

%description    scheme
Scheme implementation of the Dunning t-digest data structure for accurate
on-line accumulation of rank-based statistics.

%package        sml
Summary:        Standard ML implementation of the t-digest algorithm
Requires:       mlton

%description    sml
Standard ML implementation of the Dunning t-digest data structure for accurate
on-line accumulation of rank-based statistics.

%package        ada
Summary:        Ada implementation of the t-digest algorithm
Requires:       gcc-gnat

%description    ada
Ada implementation of the Dunning t-digest data structure for accurate
on-line accumulation of rank-based statistics.

%package        prolog
Summary:        Prolog implementation of the t-digest algorithm
Requires:       swipl

%description    prolog
Prolog implementation of the Dunning t-digest data structure for accurate
on-line accumulation of rank-based statistics.

%package        mercury
Summary:        Mercury implementation of the t-digest algorithm
Requires:       mercury

%description    mercury
Mercury implementation of the Dunning t-digest data structure for accurate
on-line accumulation of rank-based statistics.

%prep
%autosetup

%build
# Pure source distribution; no compilation during packaging

%install
# Documentation
mkdir -p %{buildroot}%{_docdir}/%{name}
if [ -f LICENSE ]; then
    install -m 644 LICENSE %{buildroot}%{_docdir}/%{name}/
fi
if [ -f README.md ]; then
    install -m 644 README.md %{buildroot}%{_docdir}/%{name}/
fi

# Ruby
mkdir -p %{buildroot}%{_datadir}/%{name}/ruby
install -m 644 ruby/tdigest.rb %{buildroot}%{_datadir}/%{name}/ruby/

# Haskell
mkdir -p %{buildroot}%{_datadir}/%{name}/haskell
install -m 644 haskell/TDigest.hs %{buildroot}%{_datadir}/%{name}/haskell/
install -m 644 haskell/Main.hs %{buildroot}%{_datadir}/%{name}/haskell/

# Common Lisp
mkdir -p %{buildroot}%{_datadir}/%{name}/common-lisp
install -m 644 common-lisp/tdigest.lisp %{buildroot}%{_datadir}/%{name}/common-lisp/
install -m 644 common-lisp/demo.lisp %{buildroot}%{_datadir}/%{name}/common-lisp/

# Scheme
mkdir -p %{buildroot}%{_datadir}/%{name}/scheme
install -m 644 scheme/tdigest.scm %{buildroot}%{_datadir}/%{name}/scheme/
install -m 644 scheme/demo.scm %{buildroot}%{_datadir}/%{name}/scheme/

# SML
mkdir -p %{buildroot}%{_datadir}/%{name}/sml
install -m 644 sml/tdigest.sml %{buildroot}%{_datadir}/%{name}/sml/
install -m 644 sml/demo.sml %{buildroot}%{_datadir}/%{name}/sml/
install -m 644 sml/demo.mlb %{buildroot}%{_datadir}/%{name}/sml/

# Ada
mkdir -p %{buildroot}%{_datadir}/%{name}/ada
install -m 644 ada/tdigest.ads %{buildroot}%{_datadir}/%{name}/ada/
install -m 644 ada/tdigest.adb %{buildroot}%{_datadir}/%{name}/ada/
install -m 644 ada/demo.adb %{buildroot}%{_datadir}/%{name}/ada/

# Prolog
mkdir -p %{buildroot}%{_datadir}/%{name}/prolog
install -m 644 prolog/tdigest.pl %{buildroot}%{_datadir}/%{name}/prolog/
install -m 644 prolog/demo.pl %{buildroot}%{_datadir}/%{name}/prolog/

# Mercury
mkdir -p %{buildroot}%{_datadir}/%{name}/mercury
install -m 644 mercury/tdigest.m %{buildroot}%{_datadir}/%{name}/mercury/
install -m 644 mercury/demo.m %{buildroot}%{_datadir}/%{name}/mercury/

%files doc
%{_docdir}/%{name}/

%files ruby
%{_datadir}/%{name}/ruby/

%files haskell
%{_datadir}/%{name}/haskell/

%files common-lisp
%{_datadir}/%{name}/common-lisp/

%files scheme
%{_datadir}/%{name}/scheme/

%files sml
%{_datadir}/%{name}/sml/

%files ada
%{_datadir}/%{name}/ada/

%files prolog
%{_datadir}/%{name}/prolog/

%files mercury
%{_datadir}/%{name}/mercury/

%changelog
* Thu Mar 05 2026 Nadia Yvette Chambers <nadia.yvette.chambers@gmail.com> - 0.1.0-1
- Initial RPM package
- Implementations in Ruby, Haskell, Common Lisp, Scheme, SML, Ada, Prolog, Mercury
