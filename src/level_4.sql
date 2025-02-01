-- NIVEAU 4 ##################################
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
        RAISE NOTICE 'Utilisateur introuvable';
        RETURN FALSE;
    END IF;

    IF (time_end - time_start) > INTERVAL '24 hours' THEN
        RAISE NOTICE 'Le trajet ne peut pas durer plus de 24 heures';
        RETURN FALSE;
    END IF;

    IF time_end <= time_start THEN
        RAISE NOTICE 'La fin du trajet doit être après le début du trajet';
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
        RAISE NOTICE 'Ce trajet existe déjà';
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
        RAISE NOTICE 'Ce trajet chevauche un autre trajet';
        RETURN FALSE;
    END IF;

    INSERT INTO journey (email, time_start, time_end, station_start, station_end)
    VALUES (add_journey.email, add_journey.time_start, add_journey.time_end, add_journey.station_start, add_journey.station_end);

    RETURN TRUE;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Une erreur s’est produite lors de l’ajout du trajet: %', SQLERRM;
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- Création de la fonction add_bill

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
    IF NOT EXISTS (SELECT 1 FROM person WHERE person.email = user_email) THEN
        RAISE NOTICE 'Utilisatuer introuvable';
        RETURN FALSE;
    END IF;

    IF bill_month = EXTRACT(MONTH FROM CURRENT_DATE) AND bill_year = EXTRACT(YEAR FROM CURRENT_DATE) THEN
        RAISE NOTICE 'La facture ne peut pas être générée pour le mois en cours';
        RETURN FALSE;
    END IF;

    IF EXISTS (
        SELECT 1 FROM bill 
        WHERE email = user_email 
        AND year = bill_year 
        AND "month" = bill_month
    ) THEN
        RAISE EXCEPTION 'La facture existe déjà pour cet utilisateur, cette année et ce mois';
    END IF;

    SELECT TRUE, offer.zone_from, offer.zone_to, offer.price
    INTO has_subscription, sub_zone_from, sub_zone_to, sub_price
    FROM subscription
    JOIN offer ON subscription.code = offer.code
    WHERE subscription.email = user_email
    AND subscription.status = 'Registered'
    AND EXTRACT(YEAR FROM subscription.date_sub) = bill_year
    AND EXTRACT(MONTH FROM subscription.date_sub) = bill_month;

    -- Afficher les infos de l'abonnement
    IF has_subscription THEN
        RAISE NOTICE 'Abonnement trouvé : zones couvertes de % à %, prix = %', sub_zone_from, sub_zone_to, sub_price;
    ELSE
        RAISE NOTICE 'Aucun abonnement trouvé pour cet utilisateur.';
    END IF;

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
        RAISE NOTICE 'Trajet : min_zone = %, max_zone = %', min_zone, max_zone;

        IF has_subscription THEN
            IF min_zone >= sub_zone_from AND max_zone <= sub_zone_to THEN
                zone_price_sum := 0;
                RAISE NOTICE 'Prix du trajet avec abonnement : 0.00';
            ELSE
                SELECT SUM(price) INTO zone_price_sum 
                FROM zone 
                WHERE id BETWEEN min_zone AND max_zone 
                AND (id < sub_zone_from OR id > sub_zone_to);
                RAISE NOTICE 'Prix du trajet avec abonnement : %', zone_price_sum;
            END IF;
        ELSE
            SELECT SUM(price) INTO zone_price_sum 
            FROM zone 
            WHERE id BETWEEN min_zone AND max_zone;
            RAISE NOTICE 'Prix du trajet sans abonnement : %', zone_price_sum;
        END IF;

        total_amount := total_amount + COALESCE(zone_price_sum, 0);

        RAISE NOTICE 'Total temporaire après ajout du trajet : %', total_amount;
    END LOOP;

    IF has_subscription THEN
        total_amount := total_amount + sub_price;
        RAISE NOTICE 'Prix de l''abonnement ajouté : %', sub_price;
    END IF;

    SELECT s.discount INTO discount_percentage
    FROM contract c
    JOIN service s ON c.service = s.name
    WHERE c.email = user_email
    AND c.date_beginning <= DATE_TRUNC('month', CURRENT_DATE)
    AND (c.end_contract IS NULL OR c.end_contract >= DATE_TRUNC('month', CURRENT_DATE));

    IF discount_percentage > 0 THEN
        discount_amount := total_amount * discount_percentage / 100;
        total_amount := total_amount - discount_amount;

        RAISE NOTICE 'Réduction employé appliquée : %', discount_percentage;
        RAISE NOTICE 'Montant de la réduction : %', discount_amount;
        RAISE NOTICE 'Total après réduction : %', total_amount;
    END IF;

    total_amount := ROUND(total_amount, 2);

    IF total_amount = 0 THEN
        RETURN TRUE;
    END IF;

    INSERT INTO bill (email, year, "month", total_amount)
    VALUES (user_email, bill_year, bill_month, total_amount);

    RAISE NOTICE 'Montant final de la facture : %', total_amount;

    RETURN TRUE;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Une erreur s’est produite lors de la facturation: %', SQLERRM;
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql;


-- Création de la fonction pay_bill

CREATE OR REPLACE FUNCTION pay_bill(email VARCHAR(128), year INT, month INT) RETURNS BOOLEAN AS $$
DECLARE
    bill_paid VARCHAR(20);
    total_amount NUMERIC;
BEGIN
    DECLARE
    bill_paid VARCHAR(20);
    total_amount NUMERIC;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM person WHERE person.email = pay_bill.email) THEN
        RAISE NOTICE 'Utilissateur "%" introuvable', pay_bill.email;
        RETURN FALSE;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM bill WHERE bill.email = pay_bill.email AND bill.year = pay_bill.year AND bill.month = pay_bill.month) 
    THEN
        PERFORM add_bill(pay_bill.email, pay_bill.year, pay_bill.month);
    END IF;

    SELECT bill.total_amount, bill.status INTO total_amount, bill_paid
    FROM bill
    WHERE bill.email = pay_bill.email 
    AND bill.year = pay_bill.year 
    AND bill.month = pay_bill.month;

    IF total_amount = 0 THEN
        RAISE NOTICE 'Le montant total de la facture est nul.';
        RETURN FALSE;
    END IF;

    IF bill_paid = 'paid' THEN
        RAISE NOTICE 'La facture a déjà été payée.';
        RETURN TRUE;
    END IF;

    UPDATE bill
    SET status = 'paid'
    WHERE bill.email = pay_bill.email 
    AND bill.year = pay_bill.year 
    AND bill.month = pay_bill.month;

    RETURN TRUE;

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Erreur : %', SQLERRM;
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- Création de la fonction generate_bill

CREATE OR REPLACE FUNCTION generate_bill(
    bill_year INT,
    bill_month INT
)
RETURNS BOOLEAN AS $$
DECLARE
    user_email VARCHAR(128);
BEGIN
    IF bill_month = EXTRACT(MONTH FROM CURRENT_DATE) AND bill_year = EXTRACT(YEAR FROM CURRENT_DATE) THEN
        RAISE NOTICE 'Impossible de générer une facture pour le mois en cours';
        RETURN FALSE;
    END IF;

    FOR user_email IN
        SELECT email FROM person
    LOOP
        PERFORM add_bill(user_email, bill_year, bill_month);
    END LOOP;

    RETURN TRUE;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Une erreur s’est produite lors de la generation des factures : %', SQLERRM;
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- Création de la fonction view_all_bills

CREATE OR REPLACE VIEW view_all_bills AS
SELECT person.lastname, person.firstname, bill.id AS bill_number, bill.total_amount AS bill_amount
    FROM person
    JOIN bill ON person.email = bill.email;
ORDER BY bill.id ASC;

-- Création de la fonction view_bill_per_month

CREATE OR REPLACE VIEW view_bill_per_month AS
SELECT bill.year, bill.month, COUNT(bill.id) AS bill, SUM(bill.total_amount) AS total
    FROM bill
    GROUP BY bill.year, bill.month
    ORDER BY bill.year ASC, bill.month ASC;

-- Création de la fonction view_average_entries_station

CREATE OR REPLACE VIEW view_average_entries_station AS
SELECT tt.name AS type, s.name AS station, ROUND(AVG(entries_per_day.entries), 2) AS entries
    FROM station s
    JOIN transport_type tt ON s.type = tt.code
    JOIN (
        SELECT journey.station_start,
        COUNT(journey.email) AS entries,
        DATE_TRUNC('day', journey.time_start) AS time_start
        FROM journey
        GROUP BY journey.station_start, DATE_TRUNC('day', journey.time_start)
    ) AS entries_per_day ON s.id = entries_per_day.station_start
    GROUP BY tt.name, s.name
    ORDER BY tt.name ASC, s.name ASC;

-- Création de la fonction view_current_non_paid_bills 

CREATE OR REPLACE VIEW view_current_non_paid_bills AS
SELECT person.lastname, person.firstname, bill.id AS bill_number, bill.total_amount AS bill_amount
    FROM person
    JOIN bill ON person.email = bill.email
    WHERE bill.status IS NULL OR bill.status != 'paid'
    ORDER BY person.lastname ASC, person.firstname ASC, bill.id ASC;
