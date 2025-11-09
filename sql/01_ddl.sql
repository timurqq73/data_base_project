-- =====================================================
-- Проект: База данных интернет-магазина "ProteinPower"
-- Скрипт: DDL (Data Definition Language)
-- Описание: Создание структуры базы данных
-- =====================================================

-- Удаление таблиц в обратном порядке зависимостей (если существуют)
DROP TABLE IF EXISTS reviews CASCADE;
DROP TABLE IF EXISTS deliveries CASCADE;
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS addresses CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS suppliers CASCADE;
DROP TABLE IF EXISTS brands CASCADE;
DROP TABLE IF EXISTS categories CASCADE;

-- =====================================================
-- 1. Таблица: categories (Категории товаров)
-- =====================================================
CREATE TABLE categories (
    category_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    CONSTRAINT categories_name_check CHECK (LENGTH(name) > 0)
);

COMMENT ON TABLE categories IS 'Категории товаров спортивного питания';
COMMENT ON COLUMN categories.category_id IS 'Уникальный идентификатор категории';
COMMENT ON COLUMN categories.name IS 'Название категории';

-- =====================================================
-- 2. Таблица: brands (Бренды)
-- =====================================================
CREATE TABLE brands (
    brand_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    country VARCHAR(100) NOT NULL,
    CONSTRAINT brands_name_check CHECK (LENGTH(name) > 0),
    CONSTRAINT brands_country_check CHECK (LENGTH(country) > 0)
);

COMMENT ON TABLE brands IS 'Бренды спортивного питания';
COMMENT ON COLUMN brands.brand_id IS 'Уникальный идентификатор бренда';
COMMENT ON COLUMN brands.name IS 'Название бренда';
COMMENT ON COLUMN brands.country IS 'Страна-производитель';

-- =====================================================
-- 3. Таблица: suppliers (Поставщики)
-- =====================================================
CREATE TABLE suppliers (
    supplier_id SERIAL PRIMARY KEY,
    company_name VARCHAR(200) NOT NULL,
    contact_person VARCHAR(100),
    phone VARCHAR(20),
    email VARCHAR(100) UNIQUE NOT NULL,
    CONSTRAINT suppliers_email_check CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}$'),
    CONSTRAINT suppliers_company_name_check CHECK (LENGTH(company_name) > 0)
);

COMMENT ON TABLE suppliers IS 'Поставщики товаров';
COMMENT ON COLUMN suppliers.supplier_id IS 'Уникальный идентификатор поставщика';
COMMENT ON COLUMN suppliers.company_name IS 'Название компании-поставщика';
COMMENT ON COLUMN suppliers.contact_person IS 'Контактное лицо';
COMMENT ON COLUMN suppliers.phone IS 'Телефон для связи';
COMMENT ON COLUMN suppliers.email IS 'Email адрес (уникальный)';

-- =====================================================
-- 4. Таблица: products (Товары)
-- =====================================================
CREATE TABLE products (
    product_id SERIAL PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    description TEXT,
    price DECIMAL(10, 2) NOT NULL,
    weight_kg DECIMAL(6, 3) NOT NULL,
    stock_quantity INTEGER NOT NULL DEFAULT 0,
    category_id INTEGER NOT NULL,
    brand_id INTEGER NOT NULL,
    supplier_id INTEGER NOT NULL,
    CONSTRAINT products_price_check CHECK (price > 0),
    CONSTRAINT products_weight_check CHECK (weight_kg > 0),
    CONSTRAINT products_stock_check CHECK (stock_quantity >= 0),
    CONSTRAINT products_category_fk FOREIGN KEY (category_id) 
        REFERENCES categories(category_id) ON DELETE RESTRICT,
    CONSTRAINT products_brand_fk FOREIGN KEY (brand_id) 
        REFERENCES brands(brand_id) ON DELETE RESTRICT,
    CONSTRAINT products_supplier_fk FOREIGN KEY (supplier_id) 
        REFERENCES suppliers(supplier_id) ON DELETE RESTRICT
);

COMMENT ON TABLE products IS 'Товары спортивного питания';
COMMENT ON COLUMN products.product_id IS 'Уникальный идентификатор товара';
COMMENT ON COLUMN products.name IS 'Название товара';
COMMENT ON COLUMN products.description IS 'Описание товара';
COMMENT ON COLUMN products.price IS 'Цена товара (руб.)';
COMMENT ON COLUMN products.weight_kg IS 'Вес упаковки (кг)';
COMMENT ON COLUMN products.stock_quantity IS 'Остаток на складе';
COMMENT ON COLUMN products.category_id IS 'Идентификатор категории';
COMMENT ON COLUMN products.brand_id IS 'Идентификатор бренда';
COMMENT ON COLUMN products.supplier_id IS 'Идентификатор поставщика';

-- =====================================================
-- 5. Таблица: customers (Клиенты)
-- =====================================================
CREATE TABLE customers (
    customer_id SERIAL PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    phone VARCHAR(20),
    registration_date DATE NOT NULL DEFAULT CURRENT_DATE,
    CONSTRAINT customers_email_check CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}$'),
    CONSTRAINT customers_first_name_check CHECK (LENGTH(first_name) > 0),
    CONSTRAINT customers_last_name_check CHECK (LENGTH(last_name) > 0)
);

COMMENT ON TABLE customers IS 'Клиенты интернет-магазина';
COMMENT ON COLUMN customers.customer_id IS 'Уникальный идентификатор клиента';
COMMENT ON COLUMN customers.first_name IS 'Имя клиента';
COMMENT ON COLUMN customers.last_name IS 'Фамилия клиента';
COMMENT ON COLUMN customers.email IS 'Email адрес (уникальный)';
COMMENT ON COLUMN customers.phone IS 'Телефон клиента';
COMMENT ON COLUMN customers.registration_date IS 'Дата регистрации';

-- =====================================================
-- 6. Таблица: addresses (Адреса доставки)
-- =====================================================
CREATE TABLE addresses (
    address_id SERIAL PRIMARY KEY,
    customer_id INTEGER NOT NULL,
    city VARCHAR(100) NOT NULL,
    street VARCHAR(200) NOT NULL,
    house_number VARCHAR(20) NOT NULL,
    apartment VARCHAR(20),
    postal_code VARCHAR(20),
    CONSTRAINT addresses_customer_fk FOREIGN KEY (customer_id) 
        REFERENCES customers(customer_id) ON DELETE CASCADE,
    CONSTRAINT addresses_city_check CHECK (LENGTH(city) > 0),
    CONSTRAINT addresses_street_check CHECK (LENGTH(street) > 0),
    CONSTRAINT addresses_house_number_check CHECK (LENGTH(house_number) > 0)
);

COMMENT ON TABLE addresses IS 'Адреса доставки клиентов';
COMMENT ON COLUMN addresses.address_id IS 'Уникальный идентификатор адреса';
COMMENT ON COLUMN addresses.customer_id IS 'Идентификатор клиента';
COMMENT ON COLUMN addresses.city IS 'Город';
COMMENT ON COLUMN addresses.street IS 'Улица';
COMMENT ON COLUMN addresses.house_number IS 'Номер дома';
COMMENT ON COLUMN addresses.apartment IS 'Номер квартиры';
COMMENT ON COLUMN addresses.postal_code IS 'Почтовый индекс';

-- =====================================================
-- 7. Таблица: orders (Заказы)
-- =====================================================
CREATE TABLE orders (
    order_id SERIAL PRIMARY KEY,
    customer_id INTEGER NOT NULL,
    order_date DATE NOT NULL DEFAULT CURRENT_DATE,
    total_amount DECIMAL(10, 2) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'pending',
    shipping_address_id INTEGER NOT NULL,
    CONSTRAINT orders_total_amount_check CHECK (total_amount >= 0),
    CONSTRAINT orders_status_check CHECK (status IN ('pending', 'processing', 'shipped', 'delivered', 'cancelled')),
    CONSTRAINT orders_customer_fk FOREIGN KEY (customer_id) 
        REFERENCES customers(customer_id) ON DELETE RESTRICT,
    CONSTRAINT orders_address_fk FOREIGN KEY (shipping_address_id) 
        REFERENCES addresses(address_id) ON DELETE RESTRICT
);

COMMENT ON TABLE orders IS 'Заказы клиентов';
COMMENT ON COLUMN orders.order_id IS 'Уникальный идентификатор заказа';
COMMENT ON COLUMN orders.customer_id IS 'Идентификатор клиента';
COMMENT ON COLUMN orders.order_date IS 'Дата заказа';
COMMENT ON COLUMN orders.total_amount IS 'Общая сумма заказа (руб.)';
COMMENT ON COLUMN orders.status IS 'Статус заказа (pending, processing, shipped, delivered, cancelled)';
COMMENT ON COLUMN orders.shipping_address_id IS 'Идентификатор адреса доставки';

-- =====================================================
-- 8. Таблица: order_items (Позиции заказа)
-- =====================================================
CREATE TABLE order_items (
    order_item_id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL,
    product_id INTEGER NOT NULL,
    quantity INTEGER NOT NULL,
    unit_price DECIMAL(10, 2) NOT NULL,
    CONSTRAINT order_items_quantity_check CHECK (quantity > 0),
    CONSTRAINT order_items_unit_price_check CHECK (unit_price > 0),
    CONSTRAINT order_items_order_fk FOREIGN KEY (order_id) 
        REFERENCES orders(order_id) ON DELETE CASCADE,
    CONSTRAINT order_items_product_fk FOREIGN KEY (product_id) 
        REFERENCES products(product_id) ON DELETE RESTRICT
);

COMMENT ON TABLE order_items IS 'Позиции заказа';
COMMENT ON COLUMN order_items.order_item_id IS 'Уникальный идентификатор позиции заказа';
COMMENT ON COLUMN order_items.order_id IS 'Идентификатор заказа';
COMMENT ON COLUMN order_items.product_id IS 'Идентификатор товара';
COMMENT ON COLUMN order_items.quantity IS 'Количество товара';
COMMENT ON COLUMN order_items.unit_price IS 'Цена за единицу на момент заказа (руб.)';

-- =====================================================
-- 9. Таблица: deliveries (Доставки)
-- =====================================================
CREATE TABLE deliveries (
    delivery_id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL UNIQUE,
    delivery_date DATE NOT NULL,
    actual_delivery_date DATE,
    tracking_number VARCHAR(100),
    carrier VARCHAR(100) NOT NULL,
    CONSTRAINT deliveries_order_fk FOREIGN KEY (order_id) 
        REFERENCES orders(order_id) ON DELETE CASCADE,
    CONSTRAINT deliveries_carrier_check CHECK (LENGTH(carrier) > 0),
    CONSTRAINT deliveries_date_check CHECK (actual_delivery_date IS NULL OR actual_delivery_date >= delivery_date)
);

COMMENT ON TABLE deliveries IS 'Доставки заказов';
COMMENT ON COLUMN deliveries.delivery_id IS 'Уникальный идентификатор доставки';
COMMENT ON COLUMN deliveries.order_id IS 'Идентификатор заказа (уникальный)';
COMMENT ON COLUMN deliveries.delivery_date IS 'Планируемая дата доставки';
COMMENT ON COLUMN deliveries.actual_delivery_date IS 'Фактическая дата доставки';
COMMENT ON COLUMN deliveries.tracking_number IS 'Трек-номер для отслеживания';
COMMENT ON COLUMN deliveries.carrier IS 'Служба доставки';

-- =====================================================
-- 10. Таблица: reviews (Отзывы)
-- =====================================================
CREATE TABLE reviews (
    review_id SERIAL PRIMARY KEY,
    product_id INTEGER NOT NULL,
    customer_id INTEGER NOT NULL,
    rating INTEGER NOT NULL,
    comment TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT reviews_rating_check CHECK (rating >= 1 AND rating <= 5),
    CONSTRAINT reviews_product_fk FOREIGN KEY (product_id) 
        REFERENCES products(product_id) ON DELETE CASCADE,
    CONSTRAINT reviews_customer_fk FOREIGN KEY (customer_id) 
        REFERENCES customers(customer_id) ON DELETE CASCADE,
    CONSTRAINT reviews_unique_check UNIQUE (product_id, customer_id)
);

COMMENT ON TABLE reviews IS 'Отзывы клиентов на товары';
COMMENT ON COLUMN reviews.review_id IS 'Уникальный идентификатор отзыва';
COMMENT ON COLUMN reviews.product_id IS 'Идентификатор товара';
COMMENT ON COLUMN reviews.customer_id IS 'Идентификатор клиента';
COMMENT ON COLUMN reviews.rating IS 'Оценка товара (1-5)';
COMMENT ON COLUMN reviews.comment IS 'Текст отзыва';
COMMENT ON COLUMN reviews.created_at IS 'Дата и время создания отзыва';

-- =====================================================
-- Создание индексов для улучшения производительности
-- =====================================================

-- Индексы для внешних ключей
CREATE INDEX idx_products_category_id ON products(category_id);
CREATE INDEX idx_products_brand_id ON products(brand_id);
CREATE INDEX idx_products_supplier_id ON products(supplier_id);
CREATE INDEX idx_addresses_customer_id ON addresses(customer_id);
CREATE INDEX idx_orders_customer_id ON orders(customer_id);
CREATE INDEX idx_orders_shipping_address_id ON orders(shipping_address_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_order_date ON orders(order_date);
CREATE INDEX idx_order_items_order_id ON order_items(order_id);
CREATE INDEX idx_order_items_product_id ON order_items(product_id);
CREATE INDEX idx_deliveries_order_id ON deliveries(order_id);
CREATE INDEX idx_reviews_product_id ON reviews(product_id);
CREATE INDEX idx_reviews_customer_id ON reviews(customer_id);

-- Индексы для часто используемых поисков
CREATE INDEX idx_products_name ON products(name);
CREATE INDEX idx_customers_email ON customers(email);
CREATE INDEX idx_customers_last_name ON customers(last_name);
CREATE INDEX idx_suppliers_email ON suppliers(email);

-- =====================================================
-- Конец скрипта DDL
-- =====================================================

