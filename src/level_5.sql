-- EXERCICE 1 ##################################
-- Trriger store_offer_updates
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
