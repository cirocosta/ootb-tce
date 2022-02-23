#!/usr/bin/env bash
# Copyright 2022 VMware
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


set -o errexit
set -o nounset

readonly root=$(cd $(dirname $0)/.. && pwd)

readonly BUNDLE=${BUNDLE:?imgpkg bundle image name must be provided}
readonly RELEASE_VERSION=${RELEASE_VERSION:-0.0.0}
readonly SCRATCH=${SCRATCH:-$(mktemp -d)}
readonly RELEASE_DIR=${RELEASE_DIR:-$root/release}


main() {
        cd $root

        show_vars
        create_imgpkg_bundle
	create_carvel_packaging_objects
        populate_release_dir
}

show_vars() {
        echo "
        BUNDLE                  $BUNDLE
        RELEASE_DIR             $RELEASE_DIR
        RELEASE_VERSION         $RELEASE_VERSION
        SCRATCH                 $SCRATCH
        "
}

create_imgpkg_bundle() {
        mkdir -p $SCRATCH/bundle/{.imgpkg,config}

        cp -r ./src/ootb-supply-chains/* $SCRATCH/bundle/
	kbld \
                -f ./src/ootb-supply-chains/config \
		--imgpkg-lock-output $SCRATCH/bundle/.imgpkg/images.yml \
		> /dev/null

	imgpkg push -f $SCRATCH/bundle \
		--bundle $BUNDLE \
		--lock-output $SCRATCH/bundle.lock.yaml

	imgpkg copy \
		--bundle $(_image_from_lockfile $SCRATCH/bundle.lock.yaml) \
		--to-tar $SCRATCH/bundle.tar
}

create_carvel_packaging_objects() {
        mkdir -p $SCRATCH/package

        local image
        image=$(_image_from_lockfile $SCRATCH/bundle.lock.yaml)

        for package_fpath in ./packaging/package*.yaml; do
                ytt --ignore-unknown-comments \
                        -f ./packaging/values.yaml \
                        -f $package_fpath \
                        --data-value image=$image \
                        --data-value version=$RELEASE_VERSION > \
                        $SCRATCH/package/"$(basename $package_fpath)"
        done

}


populate_release_dir() {
        mkdir -p $RELEASE_DIR
        cp -r $SCRATCH/package/* $RELEASE_DIR
        cp -r $SCRATCH/bundle.tar $RELEASE_DIR

        ls $RELEASE_DIR
}


_image_from_lockfile() {
        local lockfile=$1

        awk -F"image: " '{if ($2) print $2;}' $lockfile
}


main "$@"
