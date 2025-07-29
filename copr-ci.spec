# sed will replace these values
%global build_version 0
%global branch 0
%global commit 0

Name: copr-ci
Version: %{build_version}
Release: 1%{?dist}
Summary: Sample spec file for testing LizardByte/copr-ci
License: MIT
URL: https://app.lizardbyte.dev

%description
Sample spec file for testing LizardByte/copr-ci

%prep
# Nothing to prepare

%build
echo '#!/bin/sh' > hello-world.sh
echo 'echo "Hello, World!"' >> hello-world.sh
chmod +x hello-world.sh

%check
# ensure output is correct
./hello-world.sh | grep -q "Hello, World!"

%install
install -D -m 0755 hello-world.sh %{buildroot}%{_bindir}/lizardbyte-hello-world

%files
%{_bindir}/lizardbyte-hello-world

%changelog
