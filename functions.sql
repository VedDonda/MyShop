CREATE OR REPLACE FUNCTION calculate_discounted_price(p_product_id INT, p_base_price NUMERIC)
RETURNS NUMERIC AS $$
DECLARE
    v_discount_percent NUMERIC(5,2);
    v_category_id INT;
BEGIN
    SELECT category_id INTO v_category_id FROM products WHERE product_id = p_product_id;

    SELECT discount_percent INTO v_discount_percent
    FROM product_discounts
    WHERE product_id = p_product_id
    AND CURRENT_DATE BETWEEN start_date AND end_date
    LIMIT 1;

    IF v_discount_percent IS NOT NULL THEN
        RETURN p_base_price * (1 - v_discount_percent / 100);
    END IF;

    SELECT discount_percent INTO v_discount_percent
    FROM category_discounts
    WHERE category_id = v_category_id
    AND CURRENT_DATE BETWEEN start_date AND end_date
    LIMIT 1;

    IF v_discount_percent IS NOT NULL THEN
        RETURN p_base_price * (1 - v_discount_percent / 100);
    END IF;

    RETURN p_base_price;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION set_order_item_price()
RETURNS TRIGGER AS $$
DECLARE
    v_base_price NUMERIC(10,2);
BEGIN
    SELECT price INTO v_base_price FROM products WHERE product_id = NEW.product_id;
    
    NEW.unit_price = calculate_discounted_price(NEW.product_id, v_base_price);
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION set_cart_item_price()
RETURNS TRIGGER AS $$
DECLARE
    v_base_price NUMERIC(10,2);
BEGIN
    SELECT price INTO v_base_price FROM products WHERE product_id = NEW.product_id;
    
    NEW.unit_price = calculate_discounted_price(NEW.product_id, v_base_price);
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION validate_order_total()
RETURNS TRIGGER AS $$
DECLARE
    v_calculated_total NUMERIC(10,2);
BEGIN
    SELECT COALESCE(SUM(quantity * unit_price), 0) INTO v_calculated_total
    FROM order_items
    WHERE order_id = NEW.order_id;
    
    NEW.total_amount = v_calculated_total;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION restrict_order_updates()
RETURNS TRIGGER AS $$
BEGIN
    IF (NEW.order_id IS DISTINCT FROM OLD.order_id OR
        NEW.customer_id IS DISTINCT FROM OLD.customer_id OR
        NEW.shop_id IS DISTINCT FROM OLD.shop_id OR
        NEW.delivery_person_id IS DISTINCT FROM OLD.delivery_person_id OR
        NEW.shipping_address_id IS DISTINCT FROM OLD.shipping_address_id OR
        NEW.order_date IS DISTINCT FROM OLD.order_date OR
        NEW.total_amount IS DISTINCT FROM OLD.total_amount OR
        NEW.created_at IS DISTINCT FROM OLD.created_at OR
        NEW.deleted_at IS DISTINCT FROM OLD.deleted_at) THEN
        RAISE EXCEPTION 'You cannot update the orders table.';
    END IF;

    IF OLD.status = 'cancelled' OR OLD.status = 'delivered' THEN
        RAISE EXCEPTION 'Cannot update status from %', OLD.status;
    ELSIF OLD.status = 'pending' AND NEW.status NOT IN ('shipped', 'cancelled') THEN
        RAISE EXCEPTION 'Invalid status transition from pending to %', NEW.status;
    ELSIF OLD.status = 'shipped' AND NEW.status NOT IN ('delivered', 'cancelled') THEN
        RAISE EXCEPTION 'Invalid status transition from shipped to %', NEW.status;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION prevent_order_items_update()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Updates to order_items are not allowed after creation.';
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;