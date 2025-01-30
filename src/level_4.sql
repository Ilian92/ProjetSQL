-- EXERCICE 4 ##################################
-- Création de la fonction add_journey

CREATE OR REPLACE FUNCTION add_journey(
    email VARCHAR(128),
    time_start TIMESTAMP,
    time_end TIMESTAMP,
    station_start INT,
    station_end INT
)
RETURNS BOOLEAN AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM person WHERE person.email = add_journey.email) THEN
        RAISE NOTICE 'User not found';
        RETURN FALSE;
    END IF;

    IF (time_end - time_start) > INTERVAL '24 hours' THEN
        RAISE NOTICE 'Journey duration exceeds 24 hours';
        RETURN FALSE;
    END IF;

    IF EXISTS (
        SELECT 1 
        FROM journey
        WHERE journey.email = add_journey.email 
        AND (
            (add_journey.time_start BETWEEN journey.time_start AND journey.time_end)
            OR (add_journey.time_end BETWEEN journey.time_start AND journey.time_end)
            OR (add_journey.time_start <= journey.time_start AND add_journey.time_end >= journey.time_end)
        )
    ) THEN
        RAISE NOTICE 'Journey conflicts with another journey';
        RETURN FALSE;
    END IF;

    INSERT INTO journey (email, time_start, time_end, station_start, station_end)
    VALUES (add_journey.email, add_journey.time_start, add_journey.time_end, add_journey.station_start, add_journey.station_end);

    RETURN TRUE;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'An error occurred while creating the journey: %', SQLERRM;
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql;


