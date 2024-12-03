--création de la fonction add_person
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
    -- Vérifier si l'email existe déjà
    IF EXISTS (SELECT 1 FROM person WHERE email = new_email) THEN
        RAISE NOTICE 'Cet email a déjà été utilisé, veuillez en choisir un autre.';
    ELSE
        -- Insérer la nouvelle personne
        INSERT INTO person (firstname, lastname, email, phone, address, town, zipcode)
        VALUES (new_firstname, new_lastname, new_email, new_phone, new_address, new_town, new_zipcode);
    END IF;
END;
$$ LANGUAGE plpgsql;

-- test de la fonction add_person
SELECT add_person('ilian','igoudjil','ilian@gmail.com','0601020304',' 10 Rue crampté','Paris','75002');