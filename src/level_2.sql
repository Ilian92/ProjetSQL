-- EXERCICE 1 ##################################
-- Création de la fonction add_person
CREATE OR REPLACE FUNCTION add_person(
    new_firstname varchar(32),
    new_lastname varchar(32),
    new_email varchar(128),
    new_phone char(10),
    new_address text,
    new_town varchar(32),
    new_zipcode char(5)
)
RETURNS void AS $$
BEGIN
    -- Insérer la nouvelle personne
    INSERT INTO person (firstname, lastname, email, phone, address, town, zipcode)
    VALUES (new_firstname, new_lastname, new_email, new_phone, new_address, new_town, new_zipcode);
EXCEPTION
    -- Vérifier si l'email est déjà utilisé
    WHEN unique_violation THEN
        RAISE NOTICE 'Cet email a déjà été utilisé, veuillez en choisir un autre.';
    WHEN OTHERS THEN
        RAISE NOTICE 'Mauvaise utilisation de la fonction add_person.';
        RETURN FALSE; 
END;
$$ LANGUAGE plpgsql;

-- Test de la fonction add_person
SELECT add_person('ilian','igoudjil','ilian@gmail.com','0601020304',' 10 Rue crampté','Paris','75002');

-- EXERCICE 2 ##################################
-- Création de la fonction add_offer
CREATE OR REPLACE FUNCTION add_offer(
    new_code VARCHAR(5),
    new_name VARCHAR(32),
    new_price FLOAT,
    new_nb_month INT,
    new_zone_from INT,
    new_zone_to INT
)
RETURNS BOOLEAN AS $$
BEGIN
    -- Vérifier si les zones existent et si le nombre de mois est supérieur à 0
    IF NOT EXISTS (
        SELECT * 
        FROM zone 
        WHERE id = new_zone_from
    ) THEN
        RAISE NOTICE 'La zone de départ n''existe pas.';
        RETURN FALSE;
    ELSIF NOT EXISTS (
        SELECT * 
        FROM zone 
        WHERE id = new_zone_to
    ) THEN
        RAISE NOTICE 'La zone d''arrivée n''existe pas.';
        RETURN FALSE;
    ELSIF new_nb_month <= 0 THEN
        RAISE NOTICE 'Le nombre de mois doit être positif et non nul.';
        RETURN FALSE;
    ELSE
        -- Insérer la nouvelle offre
        INSERT INTO offer (code, name, price, nb_month, zone_from, zone_to)
        VALUES (new_code, new_name, new_price, new_nb_month, new_zone_from, new_zone_to);
        RETURN FOUND;
    END IF;
    EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Mauvaise utilisation de la fonction add_offer.';
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- Test de la fonction add_offer
SELECT add_offer('O1234', 'Forfait Jeune', 14.99, 1, 2, 3);

-- EXERCICE 3 ##################################
-- Création de la fonction add_subscription (date_sub définie automatiquement à la date de création)
CREATE OR REPLACE FUNCTION add_subscription(
    new_num INT,
    new_email VARCHAR(128),
    new_code VARCHAR(5)
    --new_date_sub DATE
)
RETURNS BOOLEAN AS $$
BEGIN
-- Vérifier si l'utilisateur a déjà un abonnement en attente ou incomplet
    IF EXISTS (
        SELECT *
        FROM subscription
        WHERE email = new_email
        AND (status = 'Pending' OR status = 'Incomplete')
    ) THEN
        RAISE NOTICE 'L''utilisateur a déjà un abonnement en attente ou incomplet.';
        RETURN FALSE;
    END IF;
    ELSIF NOT EXISTS (
        SELECT *
        FROM person
        WHERE email = new_email
    ) THEN
        RAISE NOTICE 'L''utilisateur n''existe pas.';
        RETURN FALSE;
    END IF;
    -- Insérer le nouvel abonnement
    INSERT INTO subscription (num, email, code, date_sub)
    VALUES (new_num, new_email, new_code, CURRENT_DATE/*new_date_sub*/);
    RETURN TRUE;
EXCEPTION
    WHEN unique_violation THEN
        RAISE NOTICE 'Un abonnement avec le numéro "%" existe déjà.', new_num;
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- Test de la fonction add_subscription
SELECT add_subscription(1, 'ilian@gmail.com', 'O1234');