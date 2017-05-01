pkg_name=chef-client
pkg_origin=chef
pkg_maintainer="The Chef Maintainers <humans@chef.io>"
pkg_description="The Chef Client"
pkg_version=$(cat ../VERSION)
pkg_source=nosuchfile.tar.gz
pkg_filename=${pkg_dirname}.tar.gz
pkg_license=('Apache-2.0')
pkg_bin_dirs=(bin)
pkg_build_deps=(core/make core/gcc core/coreutils core/git)
pkg_deps=(core/glibc core/ruby core/libxml2 core/libxslt core/libiconv core/xz core/zlib core/bundler core/openssl core/cacerts core/libffi)
pkg_svc_user=root

do_download() {
  build_line "Fake download! Creating archive of latest repository commit."
  # source is in this repo, so we're going to create an archive from the
  # appropriate path within the repo and place the generated tarball in the
  # location expected by do_unpack
  cd $PLAN_CONTEXT/../
  git archive --prefix=${pkg_name}-${pkg_version}/ --output=$HAB_CACHE_SRC_PATH/${pkg_filename} HEAD
}

do_verify() {
  build_line "Skipping checksum verification on the archive we just created."
  return 0
}

do_prepare() {
  export OPENSSL_LIB_DIR=$(pkg_path_for openssl)/lib
  export OPENSSL_INCLUDE_DIR=$(pkg_path_for openssl)/include
  export SSL_CERT_FILE=$(pkg_path_for cacerts)/ssl/cert.pem

  build_line "Setting link for /usr/bin/env to 'coreutils'"
  [[ ! -f /usr/bin/env ]] && ln -s $(pkg_path_for coreutils)/bin/env /usr/bin/env

  return 0
}

do_build() {
  export CPPFLAGS="${CPPFLAGS} ${CFLAGS}"

  local _bundler_dir=$(pkg_path_for bundler)
  local _libxml2_dir=$(pkg_path_for libxml2)
  local _libxslt_dir=$(pkg_path_for libxslt)
  local _zlib_dir=$(pkg_path_for zlib)

  export GEM_HOME=${pkg_prefix}
  export GEM_PATH=${_bundler_dir}:${GEM_HOME}

  export NOKOGIRI_CONFIG="--use-system-libraries --with-zlib-dir=${_zlib_dir} --with-xslt-dir=${_libxslt_dir} --with-xml2-include=${_libxml2_dir}/include/libxml2 --with-xml2-lib=${_libxml2_dir}/lib"
  bundle config --local build.nokogiri '${NOKOGIRI_CONFIG}'

  bundle config --local silence_root_warning 1

  pushd chef-config > /dev/null
  bundle install --jobs "$(nproc)" --retry 5 \
    --standalone \
    --binstubs "${pkg_prefix}/bin" \
    --path "${pkg_prefix}"
  popd > /dev/null

  bundle install --jobs "$(nproc)" --retry 5 \
    --standalone --no-deployment \
    --binstubs "${pkg_prefix}/bin" \
    --path "${pkg_prefix}"
}

do_install() {
  for binstub in ${pkg_prefix}/bin/*; do
    build_line "Setting shebang for ${binstub} to 'ruby'"
    [[ -f $binstub ]] && sed -e "s#/usr/bin/env ruby#$(pkg_path_for ruby)/bin/ruby#" -i $binstub
  done

  if [[ `readlink /usr/bin/env` = "$(pkg_path_for coreutils)/bin/env" ]]; then
    build_line "Removing the symlink we created for '/usr/bin/env'"
    rm /usr/bin/env
  fi
}

# Stubs
do_strip() {
  return 0
}
