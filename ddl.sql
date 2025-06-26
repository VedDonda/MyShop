CREATE TABLE pincodes (
    pincode VARCHAR(10) PRIMARY KEY,
    area TEXT NOT NULL,
    city TEXT NOT NULL,
    state TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP
);

CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    name TEXT NOT NULL CHECK (name ~ '^[A-Za-z\s]+$'),
    email TEXT NOT NULL UNIQUE CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
    password TEXT NOT NULL,
    phone VARCHAR(10) CHECK (phone ~ '^[6-9][0-9]{9}$'),
    date_of_birth DATE CHECK (date_of_birth <= CURRENT_DATE),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP,
    deleted_at TIMESTAMP
);

CREATE INDEX idx_users_email ON users(email);

CREATE TABLE addresses (
    address_id SERIAL PRIMARY KEY,
    user_id INT REFERENCES users(user_id) ON DELETE CASCADE ON UPDATE CASCADE,
    address TEXT NOT NULL,
    pincode VARCHAR(10) NOT NULL REFERENCES pincodes(pincode) ON DELETE RESTRICT ON UPDATE RESTRICT,
    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP
);

CREATE INDEX idx_addresses_user_id ON addresses(user_id);
CREATE INDEX idx_addresses_pincode ON addresses(pincode);
CREATE UNIQUE INDEX idx_unique_default_address ON addresses(user_id) WHERE is_default = TRUE;

CREATE TABLE customers (
    user_id INT PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE ON UPDATE CASCADE,
    customer_type TEXT CHECK (customer_type IN ('regular', 'premium', 'vip')) DEFAULT 'regular',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP
);

CREATE TABLE delivery_persons (
    user_id INT PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE ON UPDATE CASCADE,
    availability BOOLEAN NOT NULL DEFAULT TRUE,
    service_pincode VARCHAR(10) REFERENCES pincodes(pincode) ON DELETE RESTRICT ON UPDATE RESTRICT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP
);

CREATE TABLE shops (
    shop_id SERIAL PRIMARY KEY,
    user_id INT NOT NULL UNIQUE REFERENCES users(user_id) ON DELETE CASCADE ON UPDATE CASCADE,
    shop_name TEXT NOT NULL,
    gst_number VARCHAR(15) UNIQUE CHECK (gst_number ~ '^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$'),
    address_id INT NOT NULL REFERENCES addresses(address_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP,
    deleted_at TIMESTAMP
);

CREATE INDEX idx_shops_user_id ON shops(user_id);
CREATE INDEX idx_shops_address_id ON shops(address_id);

CREATE TABLE categories (
    category_id SERIAL PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP
);

CREATE TABLE products (
    product_id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    price NUMERIC(10,2) NOT NULL CHECK (price >= 0),
    category_id INT REFERENCES categories(category_id) ON DELETE SET NULL ON UPDATE CASCADE,
    added_date DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP,
    deleted_at TIMESTAMP
);

CREATE INDEX idx_products_category_id ON products(category_id);

CREATE TABLE shop_product_stock (
    shop_id INT NOT NULL REFERENCES shops(shop_id) ON DELETE CASCADE ON UPDATE CASCADE,
    product_id INT NOT NULL REFERENCES products(product_id) ON DELETE CASCADE ON UPDATE CASCADE,
    stock INTEGER NOT NULL CHECK (stock >= 0),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP,
    PRIMARY KEY (shop_id, product_id)
);

CREATE INDEX idx_shop_product_stock_shop_id ON shop_product_stock(shop_id);
CREATE INDEX idx_shop_product_stock_product_id ON shop_product_stock(product_id);

CREATE TABLE category_discounts (
    discount_id SERIAL PRIMARY KEY,
    category_id INT NOT NULL REFERENCES categories(category_id) ON DELETE CASCADE ON UPDATE CASCADE,
    discount_percent NUMERIC(5,2) NOT NULL CHECK (discount_percent >= 0 AND discount_percent <= 100),
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    CHECK (end_date >= start_date),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP
);

CREATE TABLE product_discounts (
    discount_id SERIAL PRIMARY KEY,
    product_id INT NOT NULL REFERENCES products(product_id) ON DELETE CASCADE ON UPDATE CASCADE,
    discount_percent NUMERIC(5,2) NOT NULL CHECK (discount_percent >= 0 AND discount_percent <= 100),
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    CHECK (end_date >= start_date),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP
);

CREATE INDEX idx_category_discounts_category_id ON category_discounts(category_id);
CREATE INDEX idx_product_discounts_product_id ON product_discounts(product_id);

CREATE TABLE orders (
    order_id SERIAL PRIMARY KEY,
    customer_id INT NOT NULL REFERENCES customers(user_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    shop_id INT NOT NULL REFERENCES shops(shop_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    delivery_person_id INT REFERENCES delivery_persons(user_id) ON DELETE SET NULL ON UPDATE CASCADE,
    shipping_address_id INT NOT NULL REFERENCES addresses(address_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    order_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status TEXT NOT NULL CHECK (status IN ('pending', 'shipped', 'delivered', 'cancelled')),
    total_amount NUMERIC(10,2) NOT NULL CHECK (total_amount >= 0),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP,
    deleted_at TIMESTAMP
);

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

CREATE TRIGGER restrict_order_updates_trigger
BEFORE UPDATE ON orders
FOR EACH ROW
EXECUTE FUNCTION restrict_order_updates();

CREATE INDEX idx_orders_customer_id ON orders(customer_id);
CREATE INDEX idx_orders_shop_id ON orders(shop_id);
CREATE INDEX idx_orders_delivery_person_id ON orders(delivery_person_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_shipping_address_id ON orders(shipping_address_id);

CREATE TABLE order_items (
    order_id INT NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE ON UPDATE CASCADE,
    product_id INT NOT NULL REFERENCES products(product_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(10,2) NOT NULL CHECK (unit_price >= 0),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP,
    PRIMARY KEY (order_id, product_id)
);

CREATE OR REPLACE FUNCTION prevent_order_items_update()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Updates to order_items are not allowed after creation.';
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER prevent_order_items_update_trigger
BEFORE UPDATE ON order_items
FOR EACH ROW
EXECUTE FUNCTION prevent_order_items_update();

CREATE INDEX idx_order_items_order_id ON order_items(order_id);
CREATE INDEX idx_order_items_product_id ON order_items(product_id);

CREATE TABLE shop_revenue (
    revenue_id SERIAL PRIMARY KEY,
    shop_id INT NOT NULL REFERENCES shops(shop_id) ON DELETE CASCADE ON UPDATE CASCADE,
    order_id INT NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE ON UPDATE CASCADE,
    amount NUMERIC(10,2) NOT NULL CHECK (amount >= 0),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP
);

CREATE TABLE delivery_revenue (
    revenue_id SERIAL PRIMARY KEY,
    delivery_person_id INT NOT NULL REFERENCES delivery_persons(user_id) ON DELETE CASCADE ON UPDATE CASCADE,
    order_id INT NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE ON UPDATE CASCADE,
    commission NUMERIC(10,2) NOT NULL CHECK (commission >= 0),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP
);

CREATE TABLE payments (
    payment_id SERIAL PRIMARY KEY,
    order_id INT NOT NULL REFERENCES orders(order_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    payment_method TEXT NOT NULL CHECK (payment_method IN ('card', 'cash', 'upi', 'wallet')),
    payment_status TEXT NOT NULL CHECK (payment_status IN ('success', 'failed', 'pending')),
    transaction_id VARCHAR(50) UNIQUE,
    paid_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP
);

CREATE INDEX idx_payments_order_id ON payments(order_id);
CREATE INDEX idx_payments_payment_status ON payments(payment_status);

CREATE TABLE product_reviews (
    review_id SERIAL PRIMARY KEY,
    customer_id INT NOT NULL REFERENCES customers(user_id) ON DELETE CASCADE ON UPDATE CASCADE,
    product_id INT NOT NULL REFERENCES products(product_id) ON DELETE CASCADE ON UPDATE CASCADE,
    rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
    review_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    comment TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP,
    CONSTRAINT unique_review_per_customer_product UNIQUE (customer_id, product_id)
);

CREATE INDEX idx_product_reviews_customer_id ON product_reviews(customer_id);
CREATE INDEX idx_product_reviews_product_id ON product_reviews(product_id);

CREATE TABLE cart_items (
    customer_id INT NOT NULL REFERENCES customers(user_id) ON DELETE CASCADE ON UPDATE CASCADE,
    product_id INT NOT NULL REFERENCES products(product_id) ON DELETE CASCADE ON UPDATE CASCADE,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(10,2) NOT NULL CHECK (unit_price >= 0),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP,
    PRIMARY KEY (customer_id, product_id)
);

CREATE INDEX idx_cart_items_customer_id ON cart_items(customer_id);
CREATE INDEX idx_cart_items_product_id ON cart_items(product_id);

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

CREATE TRIGGER set_order_item_price_trigger
BEFORE INSERT ON order_items
FOR EACH ROW
EXECUTE FUNCTION set_order_item_price();

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

CREATE TRIGGER set_cart_item_price_trigger
BEFORE INSERT ON cart_items
FOR EACH ROW
EXECUTE FUNCTION set_cart_item_price();

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

CREATE TRIGGER validate_order_total_trigger
BEFORE INSERT ON orders
FOR EACH ROW
EXECUTE FUNCTION validate_order_total();

CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

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