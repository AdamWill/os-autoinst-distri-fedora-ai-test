#!/usr/bin/bash

# Copyright Red Hat
#
# This file is part of os-autoinst-distri-fedora.
#
# os-autoinst-distri-fedora is free software; you can redistribute it
# and/or modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation, either version 2 of
# the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# Author: Adam Williamson <awilliam@redhat.com>

# This is a helper script to update the tarball of the openqa_testdata
# repository that lives in data/ and is downloaded by the tests.

WORK_DIR=$(mktemp -d)
pushd ${WORK_DIR}
git clone https://pagure.io/fedora-qa/openqa_testdata.git
tar --exclude='.git' -czvf testdata.tar.gz openqa_testdata
popd
here=$(dirname ${0})
mv ${WORK_DIR}/testdata.tar.gz ${here}/data
rm -rf ${WORK_DIR}
