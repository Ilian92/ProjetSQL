-- fonction add_transport_type
CREATE OR REPLACE FUNCTION add_transport_type(new_code VARCHAR(3), new_name VARCHAR(32), new_capacity INT, new_avg_interval INT )
RETURNS BOOLEAN AS
$$
BEGIN

IF new_capacity <= 0 THEN
RAISE NOTICE 'Capacity must be a positive integer';
RETURN FALSE;

END IF;

IF new_avg_interval <= 0 THEN
RAISE NOTICE 'Average interval must be a positive integer';
RETURN FALSE;
END IF;

IF EXISTS (SELECT code FROM transport_type WHERE code = new_code) THEN
RAISE NOTICE 'Transport type "%" already exists', new_code;
RETURN FALSE;
END IF;

INSERT INTO transport_type (code, name, capacity, avg_interval) VALUES (new_code, new_name, new_capacity, new_avg_interval);
RETURN TRUE;


EXCEPTION
WHEN OTHERS THEN
RAISE NOTICE 'An error occurred while creating the transport type "%" : %', new_code, SQLERRM;
RETURN FALSE;
END;
$$
LANGUAGE plpgsql;

-- Exemple d'utilisation de add_transport_type
SELECT add_transport_type('BUS', 'Bus', 50, 10);
SELECT add_transport_type('MTR', 'Metro', 250, 5);
SELECT add_transport_type('TRM', 'Tramway', 100, 8);

-- fonction add_zone

CREATE OR REPLACE FUNCTION add_zone(new_name VARCHAR(32), new_price FLOAT)
RETURNS BOOLEAN AS
$$
DECLARE
round_price FLOAT := ROUND(new_price::NUMERIC, 2)::FLOAT;
BEGIN
IF new_price <= 0 THEN
RAISE NOTICE 'Price must be a positive number';
RETURN FALSE;
END IF;

IF EXISTS (SELECT name FROM zone WHERE name = new_name) THEN
RAISE NOTICE 'Zone "%" already exists', new_name;
RETURN FALSE;
END IF;

INSERT INTO zone (name, price) VALUES (new_name, round_price);
RETURN TRUE;

EXCEPTION
WHEN OTHERS THEN
RAISE NOTICE 'An error occurred while creating the zone "%" : %', new_name, SQLERRM;
RETURN FALSE;
END;
$$
LANGUAGE plpgsql;

-- Exemple d'utilisation de add_zone
SELECT add_zone('Centre', 2.50);
SELECT add_zone('Périphérie', 3.20);
SELECT add_zone('Banlieue', 4.10);

-- fonction add_station

CREATE OR REPLACE FUNCTION  add_station(new_id INT, new_name VARCHAR(64), new_town VARCHAR(32), new_zone INT, new_type VARCHAR(3))
RETURNS BOOLEAN AS
$$
BEGIN
IF NOT EXISTS (SELECT code FROM transport_type WHERE code = new_type) THEN
RAISE NOTICE 'Transport type "%" does not exist', new_type;
RETURN FALSE;
END IF;

IF NOT EXISTS (SELECT id FROM zone WHERE id = new_zone) THEN
RAISE NOTICE 'Zone "%" does not exist', new_zone;
RETURN FALSE;
END IF;

IF EXISTS (SELECT id FROM station WHERE id = new_id) THEN
RAISE NOTICE 'Station "%" already exists', new_id;
RETURN FALSE;
END IF;


INSERT INTO station (id, name, town, zone, type) VALUES (new_id, new_name, new_town, new_zone, new_type);
RETURN TRUE;


EXCEPTION
WHEN OTHERS THEN
RAISE NOTICE 'An error occurred while creating the station "%" : %', new_id, SQLERRM;
RETURN FALSE;
END;
$$
LANGUAGE plpgsql;

-- Exemple d'utilisation de add_station
SELECT add_station(1, 'Gare de Lyon', 'Paris', 1, 'MTR');
SELECT add_station(2, 'République', 'Paris', 1, 'BUS');
SELECT add_station(3, 'Nation', 'Paris', 2, 'TRM');
SELECT add_station(4, 'Diderot', 'Cergy', 1, 'MTR');

-- fonction add_line

CREATE OR REPLACE FUNCTION  add_line(new_code VARCHAR(3), new_transport_type VARCHAR(3))
RETURNS BOOLEAN AS
$$
BEGIN
IF NOT EXISTS (SELECT code FROM transport_type WHERE code = new_transport_type) THEN
RAISE NOTICE 'Transport type does not exist';
RETURN FALSE;
END IF;

IF EXISTS (SELECT code FROM line WHERE code = new_code) THEN
RAISE NOTICE 'Line "%" already exists', new_code;
RETURN FALSE;
END IF;

INSERT INTO line (code, transport_id) VALUES (new_code, new_transport_type);
RETURN TRUE;

EXCEPTION
WHEN OTHERS THEN
RAISE NOTICE 'An error occurred while creating the line "%" : %', new_code, SQLERRM;
RETURN FALSE;

END;
$$
LANGUAGE plpgsql;

-- Exemple d'utilisation de add_line
SELECT add_line('M1', 'MTR');
SELECT add_line('B12', 'BUS');
SELECT add_line('T3', 'TRM');

-- fonction add_station_to_line

CREATE OR REPLACE FUNCTION add_station_to_line(new_line VARCHAR(3), new_station INT, new_pos INT)
RETURNS BOOLEAN AS
$$
BEGIN
IF NOT EXISTS(SELECT code FROM line WHERE code = new_line) THEN
RAISE NOTICE 'Line "%" does not exist', new_line;
RETURN FALSE;
END IF;
IF NOT EXISTS(SELECT id FROM station WHERE id = new_station) THEN
RAISE NOTICE 'Station "%" does not exist' , new_station;
RETURN FALSE;
END IF;
IF new_pos < 0 THEN
RAISE NOTICE 'Position must be greater than 0';
RETURN FALSE;
END IF;
IF EXISTS (SELECT pos FROM station_to_line WHERE  pos = new_pos) THEN 
RAISE NOTICE 'Position already exists';
RETURN FALSE;
END IF;
IF (SELECT transport_id FROM line WHERE code = new_line) != (SELECT transport_id FROM station WHERE id = new_station) THEN
RAISE NOTICE 'Transport type does not match';
RETURN FALSE;
END IF;
IF EXISTS (SELECT station FROM station_to_line WHERE station = new_station AND line = new_line) THEN
RAISE NOTICE 'Station to line relation already exists';
RETURN FALSE;
END IF;


INSERT INTO station_to_line (line, station, pos) VALUES (new_line, new_station, new_pos);
RETURN TRUE;

EXCEPTION
WHEN OTHERS THEN
RAISE NOTICE 'An error occurred while creating the station to line relation : %', SQLERRM;
RETURN FALSE;
END;
$$
LANGUAGE plpgsql;

-- Exemple d'utilisation de add_station_to_line
SELECT add_station_to_line('M1', 1, 1);
SELECT add_station_to_line('M1', 2, 2);
SELECT add_station_to_line('B12', 3, 1);

-- vue capacité 50 - 300 passagers
CREATE OR REPLACE VIEW view_transport_50_300_users AS 
SELECT DISTINCT name AS transport FROM transport_type WHERE capacity >= 50 AND capacity <= 300;

-- vue stations Paris

CREATE OR REPLACE VIEW views_stations_from_paris AS
SELECT name AS station FROM station WHERE town = 'Paris';

-- vue stations par zone

CREATE OR REPLACE VIEW view_stations_zones AS
SELECT station.name AS station,
    station.zone
   FROM (station
     JOIN zone ON station.zone = zone.id)
  ORDER BY station.zone, station.name;

-- vue nombre de stations par type de transport

CREATE OR REPLACE VIEW view_nb_station_type AS
SELECT transport_type.name AS type, COUNT(station.id) AS stations
   FROM (station
     JOIN transport_type ON station.type = transport_type.code)
  GROUP BY transport_type.name
  ORDER BY stations DESC;

-- vue durée de ligne

CREATE OR REPLACE VIEW view_line_duration AS
SELECT transport_type.name AS type, line.code AS line, COUNT(station_to_line.station) * transport_type.avg_interval AS minutes
   FROM line
     JOIN transport_type ON line.transport_id = transport_type.code
     JOIN station_to_line ON line.code = station_to_line.line
  GROUP BY transport_type.name, line.code, transport_type.avg_interval
  ORDER BY transport_type.name ASC, line.code ASC;

-- vue capacité par station

CREATE OR REPLACE VIEW view_station_capacity AS
SELECT station.name AS station, capacity AS capacity
FROM station
JOIN transport_type ON (station.type = transport_type.code)
WHERE station.name ILIKE 'A%'
ORDER BY station.name ASC, capacity ASC;

--Procédures liste stations d'une ligne



