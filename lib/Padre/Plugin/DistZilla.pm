package Padre::Plugin::DistZilla;

use 5.008;

use strict;
use warnings;

use Padre::Constant ();
use Padre::Plugin   ();
use Padre::Wx       ();

use Wx qw(:everything);
use Wx::Event qw(:everything);

use Dist::Zilla;
use File::Which qw(which);
use Try::Tiny;

our @ISA = qw(Padre::Plugin);

our $VERSION = '0.03';

sub plugin_name { return 'DistZilla' }

sub padre_interface { 'Padre::Plugin' => 0.70 }

sub menu_plugins_simple {
    my $self = shift;

    return $self->plugin_name => [
        'start'     => sub { $self->start },
        'release'   => sub { $self->release },
        'configure' => sub { $self->configure },
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
    
    return $self->{_dzil_conf} if $self->{_dzil_conf};
    
    my $dzil_config = $self->{_dzil_config} = {};
    my $config_dir  = Dist::Zilla::Util->_global_config_root;
    my $config_base = $config_dir->file('config');

    require Dist::Zilla::MVP::Assembler::GlobalConfig;
    require Dist::Zilla::MVP::Section;
    
    # TODO: ein eigenes Chrome-
    require Dist::Zilla::Chrome::Term;
    
    my $assembler = Dist::Zilla::MVP::Assembler::GlobalConfig->new({
        chrome => Dist::Zilla::Chrome::Term->new,
        stash_registry => $stash_registry,
        section_class  => 'Dist::Zilla::MVP::Section', # make this DZMA default
    });
  
    try {
        my $reader = Dist::Zilla::MVP::Reader::Finder->new({
          if_none => sub {
            return $_[2]->{assembler}->sequence
          },
        });

        my $seq = $reader->read_config($config_base, { assembler => $assembler });
    } catch {};
}

sub release {
}

sub start {
    my $self = shift;
    
    unless ( $self->_is_configured ) {
        $self->configure( { message => 1 } );
    }

    # create dialog
    my $dialog = Wx::Dialog->new(
        $self->main,
        -1,
        'Dist::Zilla',
        [ -1, -1 ],
        [ 560, 330 ],
        Wx::wxDEFAULT_FRAME_STYLE,
    );
    
    # directory tree
    my $tree = Wx::DirPickerCtrl->new(
        $dialog, 
        -1,
        '.',
        Wx::gettext('Pick parent directory'),
        [400,250],
    );
    
    # input field for module name
    my $name_input = Wx::TextCtrl->new(
        $dialog,
        -1,
        '',
        Wx::wxDefaultPosition,
        Wx::wxDefaultSize,
        Wx::wxTE_PROCESS_ENTER | Wx::wxSIMPLE_BORDER,
    );
        
    my $main_sizer = Wx::GridBagSizer->new( 3, 0 );
        
    my $size   = Wx::Button::GetDefaultSize;
    my $ok_btn = Wx::Button->new( $dialog, Wx::wxID_OK, '', Wx::wxDefaultPosition, $size );
    
    my $sizerv = Wx::BoxSizer->new(Wx::wxVERTICAL);
    my $sizerh = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
    $sizerv->Add( $name_input,    0, Wx::wxALL | Wx::wxEXPAND );
    $sizerv->Add( $tree,       1, Wx::wxALL | Wx::wxEXPAND );
    $sizerv->Add( $ok_btn,        0, Wx::wxALL | Wx::wxEXPAND );
    $sizerh->Add( $sizerv,        1, Wx::wxALL | Wx::wxEXPAND );

    # Fits panel layout
    $dialog->SetSizerAndFit($sizerh);
	
    $name_input->SetFocus;

    $dialog->SetSizer( $main_sizer );

    my $return = $dialog->ShowModal;
    
    if ( $return == Wx::wxID_OK ) {
        require File::pushd;
        
        my $dir = $tree->GetSelectedPath();
        return if !-d $dir;
        
        my $module = $name_input->GetValue();
        return if $module !~ m{ \A [A-Za-z]\w+(?:::\w+)* \z }xms;
        
        my $return = File::pushd::pushd( $dir );
                
        my $prog = which( 'dzil' );
        return if !$prog;
        
        $self->main->run_command( "$prog new $module" );
    }
}

1;

# ABSTRACT: A plugin for Padre to create modules with Dist::Zilla

=head1 SYNOPSIS

