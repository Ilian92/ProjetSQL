-- EXERCICE 1 ##################################
-- Trigger store_offer_updates
CREATE OR REPLACE FUNCTION store_offer_updates()
RETURNS trigger AS
$$
BEGIN
    IF OLD.price IS DISTINCT FROM NEW.price THEN
        INSERT INTO offers_history (offer_code, old_price, new_price)
        VALUES (OLD.code, OLD.price, NEW.price);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER t_store_offer_updates
AFTER UPDATE OF price ON offer
FOR EACH ROW
EXECUTE FUNCTION store_offer_updates();

-- EXERCICE 2 ##################################
-- Trigger store_status_updates
CREATE OR REPLACE FUNCTION store_status_updates()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.status IS DISTINCT FROM NEW.status THEN
        INSERT INTO status_history (user_email, sub_code, old_status, new_status)
        VALUES (OLD.email, OLD.code, OLD.status, NEW.status);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER t_store_status_updates
AFTER UPDATE OF status ON subscription
FOR EACH ROW
EXECUTE FUNCTION store_status_updates();

-- EXERCICE 3 ##################################
-- Vue view_offer_updates
CREATE OR REPLACE VIEW view_offer_updates AS
SELECT 
    offer_code,
    modified_at::TIMESTAMP WITHOUT TIME ZONE AS modification_date,
    old_price,
    new_price
FROM offers_history
ORDER BY modified_at;

-- EXERCICE 4 ##################################
-- Vue view_status_updates
CREATE OR REPLACE VIEW view_status_updates AS
SELECT 
    user_email,
    sub_code,
    modified_at::TIMESTAMP WITHOUT TIME ZONE AS modification_date,
    old_status,
    new_status
FROM status_history
ORDER BY modified_at;