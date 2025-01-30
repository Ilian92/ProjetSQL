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

    IF time_end <= time_start THEN
        RAISE NOTICE 'Journey end time must be after start time';
        RETURN FALSE;
    END IF;

     IF EXISTS (
        SELECT 1 
        FROM journey
        WHERE journey.email = add_journey.email 
        AND journey.time_start = add_journey.time_start
        AND journey.time_end = add_journey.time_end
        AND journey.station_start = add_journey.station_start
        AND journey.station_end = add_journey.station_end
    ) THEN
        RAISE NOTICE 'Journey already exists';
        RETURN FALSE;
    END IF;
    
    IF EXISTS (
        SELECT 1 
        FROM journey
        WHERE journey.email = add_journey.email 
        AND (
            (add_journey.time_start >= journey.time_start AND add_journey.time_start < journey.time_end) OR -- Début pendant un autre voyage
            (add_journey.time_end > journey.time_start AND add_journey.time_end <= journey.time_end) OR -- Fin pendant un autre voyage
            (add_journey.time_start <= journey.time_start AND add_journey.time_end >= journey.time_end) -- Englobe un autre voyage
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


CREATE OR REPLACE FUNCTION add_bill(
    user_email VARCHAR(128),
    bill_year INT,
    bill_month INT
)
RETURNS BOOLEAN AS $$
DECLARE
    total_amount NUMERIC(10,2) := 0;
    zone_price_sum NUMERIC(10,2) := 0;
    min_zone INT;
    max_zone INT;
    has_subscription BOOLEAN := FALSE;
    sub_zone_from INT;
    sub_zone_to INT;
    sub_price NUMERIC(10,2) := 0;
    discount_percentage INT := 0;
    discount_amount NUMERIC(10,2) := 0;
BEGIN
    -- Vérifier si l'utilisateur existe
    IF NOT EXISTS (SELECT 1 FROM person WHERE person.email = user_email) THEN
        RAISE NOTICE 'User not found';
        RETURN FALSE;
    END IF;

    -- Vérifier si le mois est terminé 
    IF bill_month = EXTRACT(MONTH FROM CURRENT_DATE) AND bill_year = EXTRACT(YEAR FROM CURRENT_DATE) THEN
        RAISE NOTICE 'Cannot create bill for the current month';
        RETURN FALSE;
    END IF;

    -- Vérifier si une facture existe déjà pour cet utilisateur, cette année et ce mois
    IF EXISTS (
        SELECT 1 FROM bill 
        WHERE email = user_email 
        AND year = bill_year 
        AND "month" = bill_month
    ) THEN
        RAISE EXCEPTION 'Bill already exists for this user, year, and month';
    END IF;

    -- Vérifier si l'utilisateur a un abonnement actif
    SELECT TRUE, offer.zone_from, offer.zone_to, offer.price
    INTO has_subscription, sub_zone_from, sub_zone_to, sub_price
    FROM subscription
    JOIN offer ON subscription.code = offer.code
    WHERE subscription.email = user_email
    AND subscription.status = 'Registered'
    AND EXTRACT(YEAR FROM subscription.date_sub) = bill_year
    AND EXTRACT(MONTH FROM subscription.date_sub) = bill_month;

    -- Calcul du coût des trajets
    FOR min_zone, max_zone IN
        SELECT 
            LEAST(s1.zone, s2.zone) AS min_zone,
            GREATEST(s1.zone, s2.zone) AS max_zone
        FROM journey j
        JOIN station s1 ON j.station_start = s1.id
        JOIN station s2 ON j.station_end = s2.id
        WHERE j.email = user_email
        AND EXTRACT(YEAR FROM j.time_start) = bill_year
        AND EXTRACT(MONTH FROM j.time_start) = bill_month
    LOOP
        -- Si l'utilisateur a un abonnement couvrant les zones, coût = 0
        IF has_subscription THEN
            IF min_zone >= sub_zone_from AND max_zone <= sub_zone_to THEN
                zone_price_sum := 0;
            ELSE
                -- Calculer le prix du trajet
                SELECT SUM(price) INTO zone_price_sum 
                FROM zone 
                WHERE id BETWEEN min_zone AND max_zone 
                AND (id < sub_zone_from OR id > sub_zone_to);
            END IF;
        ELSE
            -- Calcul du prix du trajet sans abonnement
            SELECT SUM(price) INTO zone_price_sum 
            FROM zone 
            WHERE id BETWEEN min_zone AND max_zone;
        END IF;

        -- Ajouter le prix du trajet au montant total
        total_amount := total_amount + COALESCE(zone_price_sum, 0);
    END LOOP;

    -- Vérifier la réduction de l'employé
    SELECT s.discount INTO discount_percentage
    FROM contract c
    JOIN service s ON c.service = s.name
    WHERE c.email = user_email
    AND c.date_beginning <= DATE_TRUNC('month', CURRENT_DATE)
    AND (c.end_contract IS NULL OR c.end_contract >= DATE_TRUNC('month', CURRENT_DATE));

    -- Appliquer la réduction si l'employé est éligible
    IF discount_percentage > 0 THEN
        discount_amount := total_amount * discount_percentage / 100;
        total_amount := total_amount - discount_amount;
    END IF;

    -- Arrondir le montant total à 2 décimales
    total_amount := ROUND(total_amount, 2);

    -- Si le montant est nul, ne pas ajouter la facture
    IF total_amount = 0 THEN
        RETURN TRUE;
    END IF;

    -- Insérer la facture
    INSERT INTO bill (email, year, "month", total_amount)
    VALUES (user_email, bill_year, bill_month, total_amount);

    RETURN TRUE;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'An error occurred while creating the bill: %', SQLERRM;
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql;


    
