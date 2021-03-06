DROP VIEW IF exists t_avg CASCADE; ---- calculate total average temperature
CREATE VIEW t_avg AS
SELECT 
    AVG(value) AS t_avg,
	meta_id
FROM data d
JOIN metadata m on m.id=d.meta_id WHERE term_id='11'
GROUP BY meta_id
ORDER BY meta_id ASC;

DROP VIEW IF exists t_night CASCADE; ---- calculate average night temperature
CREATE VIEW t_night AS
SELECT 
  meta_id,
  avg(value) AS t_night
FROM data
WHERE 
  DATE_PART('hour', tstamp) < 6 
  OR DATE_PART('hour', tstamp) >= 18
GROUP BY meta_id;

DROP VIEW IF exists t_day CASCADE; ---- calculate average day temperature
CREATE VIEW t_day AS
SELECT 
  meta_id,
  avg(value) AS t_day
FROM data
WHERE 
  DATE_PART('hour', tstamp) >= 6 
  AND DATE_PART('hour', tstamp) < 18
GROUP BY meta_id;

DROP VIEW IF EXISTS closestations CASCADE; ---- calculate closest stations from previous years 2019 and 2020 for each HOBO from 2021
CREATE VIEW closestations AS
SELECT 
	id,
	device_id,
	(SELECT m9.id FROM metadata m9
	WHERE term_id='9' ORDER BY ST_Distance(m9.location,m.location) ASC LIMIT 1) AS closest_2020,
	(SELECT m7.id FROM metadata m7
	 WHERE term_id='7' ORDER BY ST_Distance(m7.location,m.location) ASC LIMIT 1) AS closest_2019
FROM metadata m
WHERE term_id='11';
	
DROP VIEW IF EXISTS data_norm CASCADE; ---- create view with continuous id and comparable value
CREATE VIEW data_norm AS
SELECT 
	count(*) OVER (PARTITION BY meta_id ORDER BY tstamp ASC) as measurement_index,
	*,
	value - avg(value) OVER (PARTITION BY meta_id, variable_id) AS norm,
FROM data;	

DROP VIEW IF EXISTS correlation CASCADE; ---- correlate the values from this term to the 19 and 20 term join them
CREATE VIEW correlation AS
SELECT 
	dn.meta_id,
	corr(dn.norm, dn20.norm) AS Corr_2020,
	corr(dn.norm, dn19.norm) AS Corr_2019
FROM data_norm dn
JOIN closestations cs ON dn.meta_id=cs.id
JOIN data_norm dn20 ON cs.closest_2020=dn20.meta_id AND dn.measurement_index=dn20.measurement_index
JOIN data_norm dn19 ON cs.closest_2019=dn19.meta_id AND dn.measurement_index=dn19.measurement_index
WHERE dn.meta_id IN
	(SELECT id FROM metadata m
	WHERE  term_id='11')
GROUP BY dn.meta_id
ORDER BY dn.meta_id	;


DROP TABLE IF exists indices CASCADE; ---- Join all views to one and create a table
CREATE TABLE indices AS
SELECT 
	m.device_id,
	a.meta_id,
    t_avg,
	t_day,
	t_night,
	t_day-t_night AS t_diff,
	c.Corr_2019,
	c.Corr_2020
FROM t_avg a
JOIN metadata m on m.id=a.meta_id 
JOIN t_day d on d.meta_id=a.meta_id 
JOIN t_night n on n.meta_id=a.meta_id 
FULL JOIN correlation c on c.meta_id=a.meta_id
GROUP BY a.meta_id, a.t_avg, d.t_day, n.t_night, m.device_id, c.Corr_2020, c.Corr_2019
ORDER BY device_id ASC;
SELECT * FROM indices
