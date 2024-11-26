CREATE FUNCTION add_transport_type(new_code VARCHAR(3), new_name VARCHAR(32), new_capacity INT, new_avg_interval INT )
RETURNS BOOLEAN AS
$$
BEGIN

IF new_capacity <= 0 THEN
RAISE EXCEPTION 'Capacity must be greater than 0';
END IF;

IF new_avg_interval <= 0 THEN
RAISE EXCEPTION 'Average interval must be greater than 0';
END IF;

IF NOT EXISTS (SELECT code FROM transport_type WHERE code = new_code) THEN
INSERT INTO transport_type (code, name, capacity, avg_interval) VALUES (new_code, new_name, new_capacity, new_avg_interval);
RETURN TRUE;
ELSE 
RETURN FALSE;
END IF;
END;
$$
LANGUAGE plpgsql;

CREATE FUNCTION add_zone(new_name VARCHAR(32), new_price FLOAT)
RETURNS BOOLEAN AS
$$
DECLARE
round_price FLOAT := ROUND(new_price::NUMERIC, 2)::FLOAT;
BEGIN
IF NOT EXISTS(SELECT name FROM zone WHERE name = new_name) THEN
INSERT INTO zone (name, price) VALUES (new_name, round_price);
RETURN TRUE;
ELSE 
RETURN FALSE;
END IF;
END;
$$
LANGUAGE plpgsql;

CREATE FUNCTION add_station(new_id INT, new_name VARCHAR(64), new_town VARCHAR(32), new_zone INT, new_type VARCHAR(3))
RETURNS BOOLEAN AS
$$
BEGIN
IF NOT EXISTS (SELECT code FROM transport_type WHERE code = new_type) THEN
RAISE EXCEPTION 'Transport type does not exist';
END IF;
IF NOT EXISTS (SELECT id FROM zone WHERE id = new_zone) THEN
RAISE EXCEPTION 'Zone does not exist';
END IF;
IF NOT EXISTS(SELECT id FROM station WHERE id = new_id) THEN
INSERT INTO station (id, name, town, zone, type) VALUES (new_id, new_name, new_town, new_zone, new_type);
RETURN TRUE;
ELSE 
RETURN FALSE;
END IF;
END;
$$
LANGUAGE plpgsql;

CREATE FUNCTION add_line(new_code VARCHAR(3), new_transport_type VARCHAR(3))
RETURNS BOOLEAN AS
$$
BEGIN
IF NOT EXISTS (SELECT code FROM transport_type WHERE code = new_transport_type) THEN
RAISE EXCEPTION 'Transport type does not exist';
END IF;
IF NOT EXISTS(SELECT code FROM line WHERE code = new_code) THEN
INSERT INTO line (code, transport_id) VALUES (new_code, new_transport_type);
RETURN TRUE;
ELSE 
RETURN FALSE;
END IF;
END;
$$
LANGUAGE plpgsql;



CREATE FUNCTION add_station_to_line(new_line VARCHAR(3), new_station INT, new_pos INT)
RETURNS BOOLEAN AS
$$
BEGIN
IF NOT EXISTS(SELECT code FROM line WHERE code = new_line) THEN
RAISE EXCEPTION 'Line does not exist';
END IF;
IF NOT EXISTS(SELECT id FROM station WHERE id = new_station) THEN
RAISE EXCEPTION 'Station does not exist';
END IF;
IF new_pos < 0 THEN
RAISE EXCEPTION 'Position must be greater than 0';
END IF;
IF EXISTS (SELECT pos FROM station_to_line WHERE  pos = new_pos) THEN 
RAISE EXCEPTION 'Position already exists';
END IF;
IF (SELECT transport_id FROM line WHERE code = new_line) != (SELECT transport_id FROM station WHERE id = new_station) THEN
RAISE EXCEPTION 'Transport type does not match';
END IF;

IF NOT EXISTS(SELECT station FROM station_to_line WHERE station = new_station) THEN
INSERT INTO station_to_line (line, station, pos) VALUES (new_line, new_station, new_pos);
RETURN TRUE;
ELSE 
RETURN FALSE;
END IF;
END;
$$
LANGUAGE plpgsql;