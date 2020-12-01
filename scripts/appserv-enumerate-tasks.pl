use Bio::KBase::AppService::Client;
use Getopt::Long::Descriptive;
use strict;
use Data::Dumper;

my($opt, $usage) = describe_options("%c %o",
				    ["url|u=s", "Service URL"],
				    ["offset=i", "Starting offset"],
				    ["limit=i", "Number to return"],
				    ["verbose|v", "Show verbose output from service"],
				    ["help|h", "Show this help message"]);

print($usage->text), exit if $opt->help;
print($usage->text), exit 1 if (@ARGV != 0);

my $client = Bio::KBase::AppService::Client->new($opt->url);

my $limit = 25;
my $offset = 0;

my @tasks;

if (defined($opt->offset) && defined($opt->limit))
{
    my $tasks = $client->enumerate_tasks($opt->offset, $opt->limit);
    show($tasks);
}
else
{
    while (1)
    {
	my $tasks = $client->enumerate_tasks($offset, $opt->limit // $limit);
	
	last unless @$tasks;
	
	$offset += $limit;

	show($tasks);
    }
}

sub show
{
    my($tasks) = @_;
    
    for my $task (@$tasks)
    {
	print join("\t", $task->{id}, $task->{app}, $task->{workspace}, $task->{status}, $task->{submit_time}, $task->{completed_time}), "\n";
    }
    
    if ($opt->verbose)
    {
	print Dumper($tasks);
    }
}

