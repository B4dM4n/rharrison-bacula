# == Define: bacula::client::job
#
# Install a config file describing a <code>bacula-fd</code> client on the director.
#
# === Parameters
#
# [*client_schedule*]
#   The schedule for backups to be performed.
# [*director_server*]
#   The FQDN of the director server the client will connect to.
# [*fileset*]
#   The file set used by the client for backups
# [*pool*]
#   The pool used by the client for backups
# [*pool_diff*]
#   The pool to use for differential backups. Setting this to <code>false</code> will prevent configuring a specific pool for
#   differential backups. Defaults to <code>"${pool}.differential"</code>.
# [*pool_full*]
#   The pool to use for full backups. Setting this to <code>false</code> will prevent configuring a specific pool for full backups.
#   Defaults to <code>"${pool}.full"</code>.
# [*pool_incr*]
#   The pool to use for incremental backups. Setting this to <code>false</code> will prevent configuring a specific pool for
#   incremental backups. Defaults to <code>"${pool}.incremental"</code>.
# [*rerun_failed_levels*]
#   If this directive is set to <code>'yes'</code> (default <code>'no'</code>), and Bacula detects that a previous job at a higher
#   level (i.e. Full or Differential) has failed, the current job level will be upgraded to the higher level. This is particularly
#   useful for Laptops where they may often be unreachable, and if a prior Full save has failed, you wish the very next backup to be
#   a Full save rather than whatever level it is started as. There are several points that must be taken into account when using
#   this directive: first, a failed job is defined as one that has not terminated normally, which includes any running job of the
#   same name (you need to ensure that two jobs of the same name do not run simultaneously); secondly, the Ignore FileSet Changes
#   directive is not considered when checking for failed levels, which means that any FileSet change will trigger a rerun.
# [*restore_where*]
#   The default path to restore files to defined in the restore job for this client.
# [*run_scripts*]
#   An array of hashes containing the parameters for any
#   {RunScripts}[http://www.bacula.org/5.0.x-manuals/en/main/main/Configuring_Director.html#6971] to include in the backup job
#   definition. For each hash in the array a <code>RunScript</code> directive block will be inserted with the <code>key = value</code>
#   settings from the hash.  Note: The <code>RunsWhen</code> key is required.
# [*storage_server*]
#   The storage server hosting the pool this client will backup to
#
# === Examples
#
#   bacula::client::job { 'client1.example.com:default' :
#     client_schedule   => 'WeeklyCycle',
#     db_backend        => 'mysql',
#     director_password => 'directorpassword',
#     director_server   => 'bacula.example.com',
#     fileset           => 'Basic:noHome',
#     pool              => 'otherpool',
#     storage_server    => 'bacula.example.com',
#   }
#
# === Copyright
#
# Copyright 2012 Russell Harrison
#
# === License
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
define bacula::client::job (
  $client_name         = $::fqdn,
  $client_schedule     = 'WeeklyCycle',
  $director_server     = undef,
  $fileset             = 'Basic:noHome',
  $pool                = 'default',
  $pool_diff           = undef,
  $pool_full           = undef,
  $pool_incr           = undef,
  $rerun_failed_levels = 'no',
  $restore_where       = '/var/tmp/bacula-restores',
  $run_scripts         = undef,
  $storage_server      = undef
) {
  include ::bacula::params

  $job_name = "${client_name}:${name}"

  if !is_domain_name($client_name) {
    fail "Name for client ${client_name} must be a fully qualified domain name"
  }

  case $director_server {
    undef   : {
      $director_server_real = $::bacula::director::director_server ? {
        undef   => $::bacula::params::director_server_default,
        default => $::bacula::director::director_server,
      }
    }
    default : {
      $director_server_real = $director_server
    }
  }

  if !is_domain_name($director_server_real) {
    fail "director_server=${director_server_real} must be a fully qualified domain name"
  }

  validate_absolute_path($restore_where)

  $pool_diff_real = $pool_diff ? {
    undef   => "${pool}.differential",
    default => $pool_diff,
  }

  $pool_full_real = $pool_full ? {
    undef   => "${pool}.full",
    default => $pool_full,
  }

  $pool_incr_real = $pool_incr ? {
    undef   => "${pool}.incremental",
    default => $pool_incr,
  }

  if !($rerun_failed_levels in ['yes', 'no']) {
    fail("rerun_failed_levels = ${rerun_failed_levels} must be either 'yes' or 'no'")
  }

  if $run_scripts {
    case type($run_scripts) {
      'array' : {
        # TODO figure out how to validate each item in the array is a hash.
        $run_scripts_real = $run_scripts
      }
      'hash'  : {
        $run_scripts_real = [$run_scripts]
      }
      default : {
        fail("run_scripts = ${run_scripts} must be an array of hashes or a hash")
      }
    }
  }

  case $storage_server {
    undef   : {
      $storage_server_real = $::bacula::director::storage_server ? {
        undef   => $::bacula::params::storage_server_default,
        default => $::bacula::director::storage_server,
      }
    }
    default : {
      $storage_server_real = $storage_server
    }
  }

  if !is_domain_name($storage_server_real) {
    fail "storage_server=${storage_server_real} must be a fully qualified domain name"
  }

  file { "/etc/bacula/bacula-dir.d/${job_name}.conf":
    ensure  => file,
    owner   => 'bacula',
    group   => 'bacula',
    mode    => '0640',
    content => template('bacula/client_job.erb'),
    before  => Service['bacula-dir'],
    notify  => Exec['bacula-dir reload'],
  }
}
