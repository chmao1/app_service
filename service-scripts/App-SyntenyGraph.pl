#
# The FastQ Utils application.
#

use Bio::KBase::AppService::AppScript;
use Bio::KBase::AppService::AppConfig;

use strict;
use Data::Dumper;
use File::Basename;
use File::Slurp;
use LWP::UserAgent;
use JSON::XS;
use IPC::Run qw(run);
use Cwd;
use Clone;

my $script = Bio::KBase::AppService::AppScript->new(\&process_synteny);

my $rc = $script->run(\@ARGV);

exit $rc;

sub process_synteny
{
    my($app, $app_def, $raw_params, $params) = @_;

    print "Proc synteny graph ", Dumper($app_def, $raw_params, $params);

    my $token = $app->token();
    my $output_folder = $app->result_folder();

    #
    # Create an output directory under the current dir. App service is meant to invoke
    # the app script in a working directory; we create a folder here to encapsulate
    # the job output.
    #
    # We also create a staging directory for the input files from the workspace.
    #

    my $cwd = getcwd();
    my $work_dir = "$cwd/work";
    my $stage_dir = "$cwd/stage";

    -d $work_dir or mkdir $work_dir or die "Cannot mkdir $work_dir: $!";
    -d $stage_dir or mkdir $stage_dir or die "Cannot mkdir $stage_dir: $!";

    my $data_api = Bio::KBase::AppService::AppConfig->data_api_url;
    my $dat = { data_api => $data_api };
    my $sstring = encode_json($dat);

    #
    # Read parameters and discover input files that need to be staged.
    #
    # Make a clone so we can maintain a list of refs to the paths to be
    # rewritten.
    #
    my %in_files;

    my $params_to_app = Clone::clone($params);
    my @to_stage;

    #for my $read_tuple (@{$params_to_app->{paired_end_libs}})
              
    my $staged = {};
    
    #
    # Write job description.
    #
    my $jdesc = "$cwd/jobdesc.json";
    open(JDESC, ">", $jdesc) or die "Cannot write $jdesc: $!";
    print JDESC JSON::XS->new->pretty(1)->encode($params_to_app);
    close(JDESC);
    my $gdesc = "$cwd/input_genomes.txt";
    open(GENOMEIDS, ">", $gdesc) or die "Cannot write $gdesc: $!";
    print GENOMEIDS join ',', @{$params_to_app->{genome_ids}};
    close(GENOMEIDS);
    #python fam_to_graph.py --layout --output data/BrucellaInversion/test_psgraph.gexf --patric_pgfam
    #/home/asw3xp/projects/git_repos/cid_work/pangenome_graphs/fam_to_graph.py
    #my @cmd = ("fam_to_graph.py", "--ksize", $params_to_app->{ksize}, "--diversity", $params_to_app->{diversity},\
    my @cmd = ("python", "fam_to_graph.py", "--ksize", $params_to_app->{ksize}, "--diversity", $params_to_app->{diversity},"--alpha", $params_to_app->{alpha}, "--layout", "--context", $params_to_app->{context}, "--output", "$work_dir/ps_graph.gexf", "--patric_genomes", $gdesc);

    warn Dumper(\@cmd, $params_to_app);
    
    my $ok = run(\@cmd);
    if (!$ok)
    {
	die "Command failed: @cmd\n";
    }


    my @output_suffixes = ([qr/\.gexf$/, "gexf"],
			   [qr/\.txt$/, "txt"]);

    my $outfile;
    opendir(D, $work_dir) or die "Cannot opendir $work_dir: $!";
    my @files = sort { $a cmp $b } grep { -f "$work_dir/$_" } readdir(D);

    my $output=1;
    for my $file (@files)
    {
	for my $suf (@output_suffixes)
	{
	    if ($file =~ $suf->[0])
	    {
 	    	$output=0;
		my $path = "$output_folder/$file";
		my $type = $suf->[1];
		
		$app->workspace->save_file_to_file("$work_dir/$file", {}, "$output_folder/$file", $type, 1,
					       (-s "$work_dir/$file" > 10_000 ? 1 : 0), # use shock for larger files
					       $token);
	    }
	}
    }

    #
    # Clean up staged input files.
    #
    while (my($orig, $staged_file) = each %$staged)
    {
	unlink($staged_file) or warn "Unable to unlink $staged_file: $!";
    }

    return $output;
}
