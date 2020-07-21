--version to parse directly from json 
 select * from
	(
	select
		to_timestamp((row_to_json::jsonb->'extra'->>'fetchTime')::int) AT TIME ZONE 'Europe/Amsterdam' as fetch_time,
		row_to_json::jsonb->'extra'->>'locationCode' as location_code,
		(row_to_json::jsonb->'extra'->>'rentalBikes')::int as rental_bikes,
		st_setsrid(st_point((row_to_json::jsonb->>'lng')::numeric,(row_to_json::jsonb->>'lat')::numeric),4326) as geom
	from
	(
		select 
			row_to_json(jsonb_each(body::jsonb->'locaties'))::jsonb->'value' as row_to_json
		from
		(
			select (get).* from http_client.get('http://fiets.openov.nl/locaties.json' )
		)a
	)b 
)c 
;

--a more robust version which uses json from raw table

--initial setup only: 
create table ovfiets_raw(download_time timestamp, json_raw jsonb);
create table ovfiets_availability(fetch_time timestamp WITH TIME ZONE,location_code text,rental_bikes int,geom geometry(Point,4326));


-- fetch full json from api into raw table
insert into ovfiets_raw
select
now(), --current timestamp
body::jsonb
from
(select (get).*
 from http_client.get('http://fiets.openov.nl/locaties.json' ))a
 ;
 
-- if you like a quick check: table ovfiets_raw;
 
-- parse bike availability and insert into availabilitytable
insert into ovfiets_availability
select * from
	(
	select
		to_timestamp((row_to_json::jsonb->'extra'->>'fetchTime')::int) AT TIME ZONE 'Europe/Amsterdam' as fetch_time,
		row_to_json::jsonb->'extra'->>'locationCode' as location_code,
		(row_to_json::jsonb->'extra'->>'rentalBikes')::int as rental_bikes,
		st_setsrid(st_point((row_to_json::jsonb->>'lng')::numeric,(row_to_json::jsonb->>'lat')::numeric),4326) as geom
	from
	(
		select 
			row_to_json(jsonb_each(json_raw::jsonb->'locaties'))::jsonb->'value' as row_to_json
		from
			ovfiets_raw
	)b 
)c 
where not exists (select 1 from ovfiets_availability o where c.fetch_time = o.fetch_time and c.location_code = o.location_code)
;

-- simple query to check the new data
select * from ovfiets_availability order by location_code, fetch_time desc;
