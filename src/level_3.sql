-- EXERCICE 1 ##################################
-- Fonction add_service
CREATE OR REPLACE FUNCTION add_service(new_name VARCHAR(32), new_discount INT)
RETURNS BOOLEAN AS $$
BEGIN
    IF new_discount < 0 OR new_discount > 100 THEN
        RAISE NOTICE 'La réduction doit être comprise entre 0 et 100.';
        RETURN FALSE;
    END IF;

    IF EXISTS (SELECT name FROM service WHERE name = new_name) THEN
        RAISE NOTICE 'Le service "%" existe déjà.', new_name;
        RETURN FALSE;
    END IF;

    INSERT INTO service (name, discount) VALUES (new_name, new_discount);
    RETURN TRUE;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Erreur lors de la création du service : %', SQLERRM;
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- EXERCICE 2 ##################################
-- Fonction add_contract
CREATE OR REPLACE FUNCTION add_contract(new_login VARCHAR(20), new_email VARCHAR(128), new_date_beginning DATE, new_service VARCHAR(32))
RETURNS BOOLEAN AS $$
BEGIN
    IF NOT EXISTS (SELECT login FROM employee WHERE login = new_login) THEN
        RAISE NOTICE 'Le login "%" n''existe pas.', new_login;
        RETURN FALSE;
    END IF;

    IF NOT EXISTS (SELECT name FROM service WHERE name = new_service) THEN
        RAISE NOTICE 'Le service "%" n''existe pas.', new_service;
        RETURN FALSE;
    END IF;

    IF EXISTS (SELECT * FROM contract WHERE login = new_login AND end_contract IS NULL) THEN
        RAISE NOTICE 'L''employé "%" a déjà un contrat en cours.', new_login;
        RETURN FALSE;
    END IF;

    INSERT INTO contract (login, email, date_beginning, service) VALUES (new_login, new_email, new_date_beginning, new_service);
    RETURN TRUE;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Erreur lors de la création du contrat : %', SQLERRM;
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- EXERCICE 3 ##################################
-- Fonction end_contract
CREATE OR REPLACE FUNCTION end_contract(employee_email VARCHAR(128), end_date DATE)
RETURNS BOOLEAN AS $$
BEGIN
    IF NOT EXISTS (SELECT * FROM contract WHERE email = employee_email AND end_contract IS NULL) THEN
        RAISE NOTICE 'Aucun contrat actif pour "%" n''a été trouvé.', employee_email;
        RETURN FALSE;
    END IF;

    IF end_date < (SELECT date_beginning FROM contract WHERE email = employee_email AND end_contract IS NULL) THEN
        RAISE NOTICE 'La date de fin "%" est antérieure à la date de début du contrat.', end_date;
        RETURN FALSE;
    END IF;

    UPDATE contract
    SET end_contract = end_date
    WHERE email = employee_email AND end_contract IS NULL;

    RETURN TRUE;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Erreur lors de la mise à jour du contrat : %', SQLERRM;
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- EXERCICE 4 ##################################
-- Fonction update_service
CREATE OR REPLACE FUNCTION update_service(service_name VARCHAR(32), new_discount INT)
RETURNS BOOLEAN AS $$
BEGIN
    IF new_discount < 0 OR new_discount > 100 THEN
        RAISE NOTICE 'La réduction doit être comprise entre 0 et 100.';
        RETURN FALSE;
    END IF;

    IF NOT EXISTS (SELECT name FROM service WHERE name = service_name) THEN
        RAISE NOTICE 'Le service "%" n''existe pas.', service_name;
        RETURN FALSE;
    END IF;

    UPDATE service SET discount = new_discount WHERE name = service_name;
    RETURN TRUE;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Erreur lors de la mise à jour du service : %', SQLERRM;
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- EXERCICE 5 ##################################
-- Fonction update_employee_mail
CREATE OR REPLACE FUNCTION update_employee_mail(
    employee_login VARCHAR(20),
    new_email VARCHAR(128)
) RETURNS BOOLEAN AS $$
DECLARE
    old_email VARCHAR(128);
BEGIN
    SELECT email INTO old_email 
    FROM employee 
    WHERE login = employee_login;

    IF NOT FOUND THEN
        RAISE NOTICE 'Login "%" introuvable', employee_login;
        RETURN FALSE;
    END IF;

    IF EXISTS (SELECT 1 FROM person WHERE email = new_email) THEN
        RAISE NOTICE 'Email "%" existe déjà dans la table person', new_email;
        RETURN FALSE;
    END IF;

    UPDATE person 
    SET email = new_email 
    WHERE email = old_email;

    RETURN TRUE;

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Erreur technique : %', SQLERRM;
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- EXERCICE 6 ##################################
-- Vue view_employees
CREATE OR REPLACE VIEW view_employees AS
SELECT 
    p.lastname,
    p.firstname,
    e.login,
    s.name AS service
FROM person p
JOIN employee e ON p.email = e.email
JOIN contract c ON e.login = c.login
JOIN service s ON c.service = s.name
WHERE c.end_contract IS NULL OR c.end_contract > CURRENT_DATE
ORDER BY p.lastname, p.firstname, e.login;

-- EXERCICE 7 ##################################
-- Vue view_nb_employees_per_service
CREATE OR REPLACE VIEW view_nb_employees_per_service AS
SELECT 
    s.name AS service,
    COUNT(DISTINCT c.login) AS nb
FROM service s
LEFT JOIN contract c ON s.name = c.service 
    AND (c.end_contract IS NULL OR c.end_contract > CURRENT_DATE)
GROUP BY s.name
ORDER BY s.name;

-- EXERCICE 8 ##################################
-- Procédure list_login_employee
CREATE OR REPLACE FUNCTION list_login_employee(date_service DATE)
RETURNS SETOF VARCHAR(20) AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT login FROM contract
    WHERE date_beginning <= date_service AND (end_contract IS NULL OR end_contract >= date_service)
    ORDER BY login;
END;
$$ LANGUAGE plpgsql;

-- EXERCICE 9 ##################################
-- Procédure list_not_employee
CREATE OR REPLACE FUNCTION list_not_employee(target_date DATE)
RETURNS TABLE(
    lastname VARCHAR(32),
    firstname VARCHAR(32),
    has_worked TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.lastname,
        p.firstname,
        CASE WHEN EXISTS (
            SELECT 1 FROM contract c 
            JOIN employee e ON c.login = e.login 
            WHERE e.email = p.email
        ) THEN 'YES' ELSE 'NO' END AS has_worked
    FROM person p
    WHERE NOT EXISTS (
        SELECT 1 
        FROM contract c 
        JOIN employee e ON c.login = e.login 
        WHERE e.email = p.email 
        AND c.date_beginning <= target_date 
        AND (c.end_contract IS NULL OR c.end_contract >= target_date)
    )
    ORDER BY p.lastname, p.firstname;
END;
$$ LANGUAGE plpgsql;

-- EXERCICE 10 ##################################
-- Procédure list_subscription_history
CREATE OR REPLACE FUNCTION list_subscription_history(target_email VARCHAR(128))
RETURNS TABLE(
    type TEXT,
    name VARCHAR,
    start_date DATE,
    duration INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT * FROM (
        SELECT 
            'sub'::TEXT AS type,
            o.name::VARCHAR,
            s.date_sub::DATE AS start_date,
            ( (s.date_sub + (o.nb_month * INTERVAL '1 month'))::DATE - s.date_sub ) AS duration
        FROM subscription s
        JOIN offer o ON s.code = o.code
        WHERE s.email = target_email

        UNION ALL

        SELECT 
            'ctr'::TEXT AS type,
            c.service::VARCHAR,
            c.date_beginning::DATE AS start_date,
            CASE 
                WHEN c.end_contract IS NULL THEN NULL 
                ELSE (c.end_contract - c.date_beginning)
            END AS duration
        FROM contract c
        WHERE c.email = target_email
    ) AS combined_data
    ORDER BY start_date;
END;
$$ LANGUAGE plpgsql;