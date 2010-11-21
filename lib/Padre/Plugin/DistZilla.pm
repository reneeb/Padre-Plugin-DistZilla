package Padre::Plugin::DistZilla;

use 5.008;

use strict;
use warnings;

use Padre::Constant   ();
use Padre::Plugin     ();
use Padre::Wx         ();
use Padre::Wx::Dialog ();

use Wx qw(:everything);
use Wx::Event qw(:everything);

use Dist::Zilla;
use File::Which qw(which);
use File::HomeDir;
use Path::Class;
use Try::Tiny;

our @ISA = qw(Padre::Plugin);

our $VERSION = '0.04';

sub plugin_name { return 'DistZilla' }

sub padre_interfaces {
    'Padre::Plugin' => 0.70,
}

sub menu_plugins_simple {
    my $self = shift;

    return $self->plugin_name => [
        'start'     => sub { $self->start },
        'release'   => sub { $self->release },
        #'configure' => sub { $self->configure },
    ]
}
sub configure {
    my ($self,$params) = @_;
    
    my $main = $self->main;

    # create dialog
    my $dialog = Wx::Dialog->new(
        $main,
        -1,
        'Dist::Zilla - Configuration',
        [ -1, -1 ],
        [ 560, 330 ],
        Wx::wxDEFAULT_FRAME_STYLE,
    );
    
    my $rows = 5;
}

sub _is_configured {
    my $self = shift;
    
    return 1;
    
    return $self->{_dzil_conf} if $self->{_dzil_conf};
    
    my $dzil_config = $self->{_dzil_config} = {};
    my $config_dir  = Dist::Zilla::Util->_global_config_root;
    my $config_base = $config_dir->file('config');

    # require Dist::Zilla::MVP::Assembler::GlobalConfig;
    # require Dist::Zilla::MVP::Section;
    # 
    # # TODO: ein eigenes Chrome-
    # require Dist::Zilla::Chrome::Term;
    # 
    # my $assembler = Dist::Zilla::MVP::Assembler::GlobalConfig->new({
        # chrome => Dist::Zilla::Chrome::Term->new,
        # stash_registry => $stash_registry,
        # section_class  => 'Dist::Zilla::MVP::Section', # make this DZMA default
    # });
  # 
    # try {
        # my $reader = Dist::Zilla::MVP::Reader::Finder->new({
          # if_none => sub {
            # return $_[2]->{assembler}->sequence
          # },
        # });
# 
        # my $seq = $reader->read_config($config_base, { assembler => $assembler });
    # } catch {};
}

sub release {
}

sub start {
    my $self = shift;
    
    unless ( $self->_is_configured ) {
        $self->configure( { message => 1 } );
    }
    
    my $parent = $self->main;
    
    my $layout = _get_layout();
    my $dialog = Padre::Wx::Dialog->new(
        parent => $parent,
        title  => Wx::gettext('Start Module with Dist::Zilla'),
        layout => $layout,
        width  => [ 200, 300 ],
        bottom => 10,
    );
    
    Wx::Event::EVT_BUTTON( $dialog, $dialog->{_widgets_}->{_directory_}, \&_on_pick_dir );
    
    my $return = $dialog->ShowModal;
    
    my $data = $dialog->get_data;
  
    if ( $return == Wx::wxID_OK ) {
        require File::pushd;
        
        my $data = $dialog->get_data;
        
        my $dir = $data->{_directory_name_};
        return if !-d $dir;
        
        my $module = $data->{_module_name_};
        return if $module !~ m{ \A [A-Za-z]\w+(?:::\w+)* \z }xms;
        
        my $return = File::pushd::pushd( $dir );
                
        my $prog = which( 'dzil' );
        return if !$prog;
        
        my $profile     = $data->{_profile_choice_};
        my $profile_arg = '';
        $profile_arg    = "-p $profile" if $profile;
        
        $self->main->run_command( "$prog new $profile_arg $module" );
    }
}

sub _get_layout {
    my @profiles = _get_profiles();
    
    my @layout = (
        [   [ 'Wx::StaticText', undef,           Wx::gettext('Module Name:') ],
            [ 'Wx::TextCtrl',   '_module_name_', '' ],
        ],
        [   [ 'Wx::StaticText', undef, Wx::gettext('DistZilla Profiles:') ],
            [ 'Wx::ComboBox', '_profile_choice_', '', \@profiles ],
        ],
        [   [ 'Wx::StaticText', undef, Wx::gettext('Parent Directory:') ],
            [ 'Wx::TextCtrl', '_directory_name_', '' ],
            [ 'Wx::Button', '_directory_', Wx::gettext('Select Directory') ],
        ],
        [   [ 'Wx::Button', '_ok_',     Wx::wxID_OK ],
            [ 'Wx::Button', '_cancel_', Wx::wxID_CANCEL ],
        ],
    );
    return \@layout;
}

sub _on_pick_dir {
	my ( $dialog, $event ) = @_;

	my $main = Padre->ide->wx->main;

	my $dir_dialog = Wx::DirDialog->new(
		$main,
		Wx::gettext("Select directory"),
		'.'
	);
	if ( $dir_dialog->ShowModal == Wx::wxID_CANCEL ) {
		return;
	}
	$dialog->{_widgets_}->{_directory_name_}->SetValue( $dir_dialog->GetPath );

	return;
}

sub _get_profiles {
    my $home = File::HomeDir->my_home;
 
    my $dir    = Path::Class::Dir->new( $home );
    my $subdir = $dir->subdir( '.dzil', 'profiles' );
    
    return if !-d "$subdir";
    
    my @children = $subdir->children;
    my @dirs     = grep{ $_->isa( 'Path::Class::Dir' ) }@children;
    my @names    = map { $_->dir_list( -1 ) }@dirs;
    
    return @names;
}

1;

# ABSTRACT: A plugin for Padre to create modules with Dist::Zilla

=head1 SYNOPSIS

