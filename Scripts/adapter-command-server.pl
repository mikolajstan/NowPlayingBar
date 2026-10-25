#!/usr/bin/perl
#
# Long-lived helper for NowPlayingBar's playback commands.
#
# mediaremote-adapter.pl loads the framework again for every `send`/`seek`,
# which adds a noticeable delay to each click. This script loads it once and
# then runs one command per line read from stdin:
#
#   send <MRCommand id>      e.g. "send 4" (next track)
#   seek <microseconds>      e.g. "seek 42000000"
#
# Usage: adapter-command-server.pl FRAMEWORK_PATH
#
# It calls the same `*_env` entry points the vendored script uses, so the
# framework itself is unchanged. Lines are validated here because the framework
# exits the process on bad input; if it exits anyway the app starts a new one.

use strict;
use warnings;
use DynaLoader;
use File::Spec;
use File::Basename;

sub fail {
  my ($error) = @_;
  print STDERR "$error\n";
  exit 1;
}

my $framework_path = shift @ARGV or fail "Framework path not provided";
my $name = File::Basename::basename($framework_path);
fail "Provided path is not a framework: $framework_path"
  unless $name =~ s/\.framework$//;

my $framework = File::Spec->catfile($framework_path, $name);
my $handle = DynaLoader::dl_load_file($framework, 0)
  or fail "Failed to load framework: $framework";

foreach my $function ("send", "seek") {
  my $symbol = DynaLoader::dl_find_symbol($handle, "adapter_${function}_env")
    or fail "Symbol 'adapter_${function}_env' not found in $framework";
  DynaLoader::dl_install_xsub("main::$function", $symbol);
}

# Commands accepted by adapter_send (see src/adapter/send.m)
my %accepted_commands = map { $_ => 1 } (0 .. 13);

$| = 1;

while (my $line = <STDIN>) {
  chomp $line;
  if ($line =~ /^send (\d+)$/ && $accepted_commands{$1}) {
    $ENV{"MEDIAREMOTEADAPTER_PARAM_adapter_send_0_command"} = $1;
    no strict "refs";
    &{"main::send"}();
  }
  elsif ($line =~ /^seek (\d+)$/) {
    $ENV{"MEDIAREMOTEADAPTER_PARAM_adapter_seek_0_position"} = $1;
    no strict "refs";
    &{"main::seek"}();
  }
  else {
    print STDERR "Ignoring invalid command: $line\n";
  }
}
