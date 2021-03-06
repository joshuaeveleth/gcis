create table platform_type (
    identifier varchar not null primary key
);

insert into platform_type values ('spacecraft');
insert into platform_type values ('aircraft');

drop table if exists platform cascade;
create table platform (
    identifier varchar not null primary key,
    name varchar not null,
    description varchar,
    url varchar,
    platform_type_identifier varchar references platform_type (identifier),
    CHECK (identifier similar to '[a-z0-9_-]+')
);

comment on table platform is 'A platform is an entity to which instruments may be attached.';

create table instrument (
    identifier varchar not null primary key,
    name varchar not null,
    description varchar,
    CHECK (identifier similar to '[a-z0-9_-]+')
);

comment on table instrument is 'An instrument is a class of devices that may perform measurements, and may have sensors';

/* Affixing an instrument to a platform creates an instrument instance. */
create table instrument_instance (
    platform_identifier varchar not null references platform(identifier) on update cascade on delete cascade,
    instrument_identifier varchar not null references instrument(identifier) on update cascade on delete cascade,
    location varchar,
    primary key (platform_identifier, instrument_identifier)
);

comment on table instrument_instance is 'An instrument instance is an instrument on a platform.';

/* An instrument instance may be associated with a dataset. */
create table instrument_measurement (
    platform_identifier varchar not null references platform(identifier) on update cascade on delete cascade,
    instrument_identifier varchar not null references instrument(identifier) on update cascade on delete cascade,
    dataset_identifier varchar not null references dataset(identifier) on update cascade on delete cascade,
      foreign key (instrument_identifier, platform_identifier)
            references instrument_instance (instrument_identifier, platform_identifier) on delete cascade on update cascade,
      primary key (platform_identifier, instrument_identifier, dataset_identifier)
);

comment on table instrument_measurement is 'A dataset may be associated with an instrument instance via an instrument measurement.';

select audit.audit_table('platform');
select audit.audit_table('instrument');
select audit.audit_table('instrument_instance');
select audit.audit_table('instrument_measurement');
