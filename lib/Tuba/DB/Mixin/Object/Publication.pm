package Tuba::DB::Object::Publication;
# Tuba::DB::Mixin::Object::Publication;

use Pg::hstore qw/hstore_decode/;
use Tuba::Log;

use strict;
use File::Temp;
use Path::Class qw/file/;
use Mojo::ByteStream qw/b/;

sub stringify {
    my $self = shift;
    my $label;
    if (my $obj = $self->to_object) {
        $label = $obj->stringify;
    } else {
        $label = join '/', map $self->$_, $self->meta->primary_key_column_names;
    }
    return $self->publication_type.' : '.$label;
}

sub to_object {
    my $self = shift;
    my $orm = Tuba::DB::Objects->table2class;
    my $type = $self->publication_type_obj or die "no type for ".$self->id;
    my $obj_class = $orm->{$type->table}->{obj}
        or die "no object class for ".$type->table;
    my @pkcols = $obj_class->meta->primary_key_columns;
    my $pkvals = hstore_decode($self->fk);
    my $obj = $obj_class->new(%$pkvals);
    $obj->load(speculative => 1) or return;
    return $obj;
}

sub children {
    my $self = shift;

    return Tuba::DB::Object::Publication::Manager->get_objects(
        query => [ parent_id => $self->id ],
        limit => 100,
    );
}

sub get_parents {
    # Get objects which are parents of this one.
    # Returns an array of hashrefs : { relationship => 'foo', publication => $pub_object }
    my $self = shift;
    my $class = ref($self) || $self;
    my $dbh = $self->db->dbh;
    my $sth = $dbh->prepare(<<'SQL');
select p.*, m.relationship, m.note from publication p
    inner join publication_map m on m.parent=p.id
    where m.child = ?
SQL
    $sth->execute($self->id) or die $dbh->errstr;
    my $rows = $sth->fetchall_arrayref({});
    my @parents;
    for my $row (@$rows) {
        my %pub;
        @pub{qw/id publication_type fk/} = @$row{qw/id publication_type fk/};
        push @parents, { relationship => $row->{relationship}, note => $row->{note}, publication => $class->new(%pub) };
    };
    return @parents;
}

sub upload_file {
    my $pub = shift;
    my %args = @_;
    my ($c,$upload) = @args{qw/c upload/};
    my $file = $upload;
    unless ($file && $file->size) {
        $pub->error("Missing or empty file.");
        return;
    }

    my $image_dir = $c->config('image_upload_dir') or do { logger->error("no image_upload_dir configured"); die "configuration error"; };
    -d $image_dir or do { logger->error("no such dir : $image_dir"); die "configuration error"; };

    my $md5 = b($file->slurp)->md5_sum;
    my $md5_dir = join '/', substr($md5,0,2), substr($md5,2,2), substr($md5,4);

    my $filename = $file->filename;
    $filename =~ s/ /_/g;
    $filename =~ tr[a-zA-Z0-9_.-][]dc;
    my $name = join '/', $md5_dir, $filename;
    my $f = file("$image_dir/$name");
    $f->dir->mkpath;
    $file->move_to("$f") or die $!;
    my $obj = Tuba::DB::Object::File->new(file => $name);
    $pub->add_files($obj);
    $pub->save(audit_user => $c->user);
    $obj->meta->error_mode('return');
    $obj->save(audit_user => $c->user) or do {
        $pub->error($obj->error);
        return 0;
    };

    return 1;
}

sub uri {
    my $s = shift;
    my $c = shift;
    my $opts = shift;
    my $route_name = $opts->{tab} || 'show';
    $route_name .= '_publication';

    return $c->url_for($route_name, { publication_identifier => $s->id } );
}

1;

