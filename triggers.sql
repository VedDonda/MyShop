CREATE TRIGGER set_order_item_price_trigger
BEFORE INSERT ON order_items
FOR EACH ROW
EXECUTE FUNCTION set_order_item_price();

CREATE TRIGGER set_cart_item_price_trigger
BEFORE INSERT ON cart_items
FOR EACH ROW
EXECUTE FUNCTION set_cart_item_price();

CREATE TRIGGER validate_order_total_trigger
BEFORE INSERT ON orders
FOR EACH ROW
EXECUTE FUNCTION validate_order_total();

CREATE TRIGGER restrict_order_updates_trigger
BEFORE UPDATE ON orders
FOR EACH ROW
EXECUTE FUNCTION restrict_order_updates();

CREATE TRIGGER prevent_order_items_update_trigger
BEFORE UPDATE ON order_items
FOR EACH ROW
EXECUTE FUNCTION prevent_order_items_update();

DO $$
DECLARE
    t text;
BEGIN
    FOR t IN
        SELECT table_name 
        FROM information_schema.columns 
        WHERE column_name = 'updated_at'
        AND table_name IN (
            'pincodes', 'users', 'customers', 'delivery_persons', 'shops', 
            'orders', 'categories', 'products', 'category_discounts', 
            'product_discounts', 'shop_revenue', 'delivery_revenue', 
            'payments', 'product_reviews', 'cart_items', 'order_items', 
            'addresses', 'shop_product_stock'
        )
    LOOP
        EXECUTE format('
            CREATE TRIGGER update_%1$s_timestamp
            BEFORE UPDATE ON %1$s
            FOR EACH ROW
            EXECUTE FUNCTION update_timestamp();
        ', t);
    END LOOP;
END;
$$;