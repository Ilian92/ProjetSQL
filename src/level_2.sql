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
RETURNS BOOLEAN AS $$
BEGIN
    -- Insérer la nouvelle personne
    INSERT INTO person (firstname, lastname, email, phone, address, town, zipcode)
    VALUES (new_firstname, new_lastname, new_email, new_phone, new_address, new_town, new_zipcode);
    RETURN FOUND;
EXCEPTION
    -- Vérifier si l'email est déjà utilisé
    WHEN unique_violation THEN
        RAISE NOTICE 'Cet email a déjà été utilisé, veuillez en choisir un autre.';
        RETURN FALSE;
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

--Création de zones
SELECT add_zone('zone1', 11);
SELECT add_zone('zone2', 12);
SELECT add_zone('zone3', 13);
SELECT add_zone('zone4', 14);
-- Test de la fonction add_offer
SELECT add_offer('00001', 'Forfait Jeune', 14.99, 1, 2, 3);

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
    WHEN OTHERS THEN
        RAISE NOTICE 'Mauvaise utilisation de la fonction add_subscription.';
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- Test de la fonction add_subscription
SELECT add_subscription(1, 'ilian@gmail.com', '00001');

-- EXERCICE 4 ##################################
-- Création de la fonction update_status
-- POSTIT: Rajouter une date de status pour savoir quand le status a été modifié
CREATE OR REPLACE FUNCTION update_status(
    new_num INT,
    new_status VARCHAR(20)
)
RETURNS BOOLEAN AS $$
BEGIN
    -- Vérifier si le nouveau statut est valide
    IF new_status NOT IN (
        'Registered', 'Pending', 'Incomplete'
    ) THEN
        RAISE NOTICE 'Statut invalide. Les statuts valides sont: Registered, Pending, Incomplete.';
        RETURN FALSE;
    -- Vérifier si l'abonnement existe
    ELSIF NOT EXISTS (
        SELECT *
        FROM subscription
        WHERE new_num = num
    ) THEN
        RAISE NOTICE 'L''abonnement n''existe pas.';
        RETURN FALSE;
    END IF;
    -- Mettre à jour le statut de l'abonnement
    UPDATE subscription
    SET status = new_status
    WHERE new_num = num;
    RETURN TRUE;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Mauvaise utilisation de la fonction update_status.';
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- Test de la fonction update_status
SELECT update_status(1, 'Pending');

-- EXERCICE 5 ##################################
-- Création de la fonction update_offer_price
CREATE OR REPLACE FUNCTION update_offer_price(
    offer_code VARCHAR(5),
    new_price FLOAT
)
RETURNS BOOLEAN AS $$
BEGIN
    -- Vérifier si l'offre existe
    IF NOT EXISTS (
        SELECT *
        FROM offer
        WHERE offer_code = code
    ) THEN
        RAISE NOTICE 'L''offre n''existe pas.';
        RETURN FALSE;
    -- Vérifier si le nouveau prix est positif et non nul
    ELSIF new_price <= 0 THEN
        RAISE NOTICE 'Le prix doit être positif et non nul.';
        RETURN FALSE;
    -- Mettre à jour le prix de l'offre
    ELSE
        UPDATE offer
        SET price = new_price
        WHERE offer_code = code;
        RETURN TRUE;
    END IF;
    EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Mauvaise utilisation de la fonction update_offer_price.';
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- Test de la fonction update_offer_price
SELECT update_offer_price('00001', 19.99);

-- EXERCICE 6 ################################
-- Création de la vue view_user_small_name
CREATE OR REPLACE VIEW view_user_small_name AS
SELECT firstname, lastname
FROM person
WHERE LENGTH(lastname) <= 4
ORDER BY lastname, firstname;

-- Test de la vue view_user_small_name
SELECT add_person('ilian','test','test@gmail.com','0612345678','10 Rue de la loutre','Levallois','92300');
SELECT * FROM view_user_small_name;

-- EXERCICE 7 ################################
-- Création de la vue view_user_subscription
CREATE OR REPLACE VIEW view_user_subscription AS
SELECT DISTINCT
    CONCAT(person.firstname, ' ', person.lastname) AS user,
    offer.name AS offer
FROM person
INNER JOIN subscription ON person.email = subscription.email
INNER JOIN offer ON subscription.code = offer.code
ORDER BY CONCAT(person.firstname, ' ', person.lastname), offer.name;

-- Test de la vue view_user_subscription
SELECT * FROM view_user_subscription;

-- EXERCICE 8 ####################################
-- Création de la vue view_unloved_offers
CREATE OR REPLACE VIEW view_unloved_offers AS
SELECT offer.name
FROM offer
LEFT JOIN subscription ON offer.code = subscription.code
WHERE subscription.code IS NULL
ORDER BY offer.name;

-- Test de la vue view_unloved_offers
SELECT * FROM view_unloved_offers;

-- EXERCICE 9 ###################################
-- Création de la vue view_pending_subscriptions
CREATE OR REPLACE VIEW view_pending_subscriptions AS
SELECT person.lastname, person.firstname
FROM person
INNER JOIN subscription ON person.email = subscription.email
WHERE subscription.status = 'Pending'
ORDER BY subscription.date_sub;

-- Test de la vue view_pending_subscriptions
SELECT * FROM view_pending_subscriptions;

-- EXERCICE 10 ###################################
-- Création de la vue view_old_subscription
CREATE OR REPLACE VIEW view_old_subscription AS
SELECT
    person.lastname,
    person.firstname,
    offer.name AS subscription,
    subscription.status
FROM person
INNER JOIN subscription ON person.email = subscription.email
INNER JOIN offer ON subscription.code = offer.code
WHERE (subscription.status = 'Incomplete' OR subscription.status = 'Pending')
  AND subscription.date_sub <= CURRENT_DATE - INTERVAL '1 year'
ORDER BY CONCAT(person.firstname, ' ', person.lastname), offer.name;
-- POSTIT: Modifier la vérification de la date quand une colonne date_status_update sera ajoutée

-- Test de la vue view_old_subscription
UPDATE subscription SET date_sub = '2022_12_07' WHERE email = 'ilian@gmail.com';
SELECT * FROM view_old_subscription;

-- EXERCICE 11 ##################################
-- Création de la procédure list_station_near_user
CREATE OR REPLACE FUNCTION list_station_near_user(user_email VARCHAR(128))
RETURNS SETOF VARCHAR(64) AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT LOWER(station.name)::VARCHAR(64) AS station_name
    FROM station
    INNER JOIN person ON station.town = person.town
    WHERE person.email = user_email
    ORDER BY LOWER(station.name)::VARCHAR(64);
END;
$$ LANGUAGE plpgsql;

-- Test de la procédure list_station_near_user
SELECT add_transport_type('001', 'bus', 100, 10);
SELECT add_station(1,'test2','Paris',1,'001');
SELECT add_station(2,'test2','Paris',1,'001');
SELECT add_station(3,'TEST3','Paris',1,'001');
SELECT add_station(4,'quatrièmeTest','Paris',1,'001');
SELECT * FROM list_station_near_user('ilian@gmail.com');