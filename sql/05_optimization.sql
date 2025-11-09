-- =====================================================
-- Проект: База данных интернет-магазина "ProteinPower"
-- Скрипт: Оптимизация и расширение функциональности
-- Описание: Оптимизация производительности и добавление расширенных возможностей
-- =====================================================

-- =====================================================
-- 1. Добавление JSONB колонки specifications в таблицу products
-- =====================================================

-- Добавление колонки specifications (если еще не существует)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'products' AND column_name = 'specifications'
    ) THEN
        ALTER TABLE products 
        ADD COLUMN specifications JSONB;
        
        COMMENT ON COLUMN products.specifications IS 'Дополнительные характеристики товара в формате JSON (белки, жиры, углеводы, вкусы и т.д.)';
    END IF;
END $$;

-- Обновление существующих товаров с примерами JSON данных
UPDATE products SET specifications = '{
    "protein_per_serving": 24,
    "serving_size_grams": 30,
    "calories_per_serving": 120,
    "fat_grams": 1,
    "carbs_grams": 3,
    "flavors": ["шоколад", "ваниль", "клубника"],
    "allergens": ["молочные продукты"],
    "certifications": ["GMP", "ISO"]
}'::jsonb WHERE product_id = 1;

UPDATE products SET specifications = '{
    "protein_per_serving": 21,
    "serving_size_grams": 25,
    "calories_per_serving": 103,
    "fat_grams": 1.9,
    "carbs_grams": 1,
    "flavors": ["ваниль", "шоколад"],
    "allergens": ["молочные продукты"]
}'::jsonb WHERE product_id = 2;

UPDATE products SET specifications = '{
    "protein_per_serving": 25,
    "serving_size_grams": 31,
    "calories_per_serving": 110,
    "fat_grams": 0.5,
    "carbs_grams": 1,
    "flavors": ["клубника", "шоколад"],
    "allergens": ["молочные продукты"],
    "certifications": ["GMP"]
}'::jsonb WHERE product_id = 3;

-- Создание GIN индекса для JSONB колонки
CREATE INDEX IF NOT EXISTS idx_products_specifications_gin 
ON products USING GIN (specifications);

-- =====================================================
-- 2. Дополнительные индексы для оптимизации производительности
-- =====================================================

-- Составные индексы для часто используемых запросов
CREATE INDEX IF NOT EXISTS idx_orders_customer_date 
ON orders(customer_id, order_date DESC);

CREATE INDEX IF NOT EXISTS idx_orders_status_date 
ON orders(status, order_date DESC);

CREATE INDEX IF NOT EXISTS idx_order_items_product_order 
ON order_items(product_id, order_id);

CREATE INDEX IF NOT EXISTS idx_products_category_brand 
ON products(category_id, brand_id);

CREATE INDEX IF NOT EXISTS idx_reviews_product_rating 
ON reviews(product_id, rating DESC);

CREATE INDEX IF NOT EXISTS idx_deliveries_date_status 
ON deliveries(delivery_date, actual_delivery_date) 
WHERE actual_delivery_date IS NULL;

-- Частичный индекс для активных заказов
CREATE INDEX IF NOT EXISTS idx_orders_active 
ON orders(order_date DESC) 
WHERE status IN ('pending', 'processing', 'shipped');

-- =====================================================
-- 3. Хранимая процедура для генерации тестовых заказов
-- =====================================================

CREATE OR REPLACE FUNCTION generate_test_orders(
    num_orders INTEGER DEFAULT 100,
    start_date DATE DEFAULT CURRENT_DATE - INTERVAL '1 year',
    end_date DATE DEFAULT CURRENT_DATE
)
RETURNS INTEGER AS $$
DECLARE
    order_count INTEGER := 0;
    rand_customer_id INTEGER;
    rand_product_id INTEGER;
    rand_address_id INTEGER;
    rand_quantity INTEGER;
    product_price DECIMAL(10, 2);
    order_total DECIMAL(10, 2);
    new_order_id INTEGER;
    order_date DATE;
    order_status VARCHAR(50);
    items_count INTEGER;
    i INTEGER;
    j INTEGER;
BEGIN
    FOR i IN 1..num_orders LOOP
        -- Случайная дата заказа
        order_date := start_date + (RANDOM() * (end_date - start_date))::INTEGER;
        
        -- Случайный клиент
        SELECT customer_id INTO rand_customer_id
        FROM customers
        ORDER BY RANDOM()
        LIMIT 1;
        
        -- Случайный адрес клиента
        SELECT address_id INTO rand_address_id
        FROM addresses
        WHERE customer_id = rand_customer_id
        ORDER BY RANDOM()
        LIMIT 1;
        
        -- Определение статуса на основе даты
        IF order_date < CURRENT_DATE - INTERVAL '7 days' THEN
            order_status := CASE (RANDOM() * 4)::INTEGER
                WHEN 0 THEN 'delivered'
                WHEN 1 THEN 'delivered'
                WHEN 2 THEN 'shipped'
                ELSE 'cancelled'
            END;
        ELSE
            order_status := CASE (RANDOM() * 3)::INTEGER
                WHEN 0 THEN 'pending'
                WHEN 1 THEN 'processing'
                ELSE 'shipped'
            END;
        END IF;
        
        -- Количество позиций в заказе (1-5)
        items_count := 1 + (RANDOM() * 4)::INTEGER;
        order_total := 0;
        
        -- Создание заказа
        INSERT INTO orders (customer_id, order_date, total_amount, status, shipping_address_id)
        VALUES (rand_customer_id, order_date, 0, order_status, rand_address_id)
        RETURNING order_id INTO new_order_id;
        
        -- Добавление позиций заказа
        FOR j IN 1..items_count LOOP
            -- Случайный товар
            SELECT product_id, price INTO rand_product_id, product_price
            FROM products
            WHERE stock_quantity > 0
            ORDER BY RANDOM()
            LIMIT 1;
            
            -- Случайное количество (1-3)
            rand_quantity := 1 + (RANDOM() * 2)::INTEGER;
            
            -- Добавление позиции
            INSERT INTO order_items (order_id, product_id, quantity, unit_price)
            VALUES (new_order_id, rand_product_id, rand_quantity, product_price);
            
            order_total := order_total + (product_price * rand_quantity);
        END LOOP;
        
        -- Обновление общей суммы заказа
        UPDATE orders
        SET total_amount = order_total
        WHERE order_id = new_order_id;
        
        -- Создание доставки для доставленных/отправленных заказов
        IF order_status IN ('delivered', 'shipped') THEN
            INSERT INTO deliveries (order_id, delivery_date, actual_delivery_date, tracking_number, carrier)
            VALUES (
                new_order_id,
                order_date + INTERVAL '3 days',
                CASE WHEN order_status = 'delivered' 
                     THEN order_date + INTERVAL '3 days' + (RANDOM() * 2)::INTEGER 
                     ELSE NULL END,
                'RU' || LPAD((RANDOM() * 999999999)::INTEGER::TEXT, 9, '0'),
                CASE (RANDOM() * 3)::INTEGER
                    WHEN 0 THEN 'СДЭК'
                    WHEN 1 THEN 'Почта России'
                    ELSE 'Boxberry'
                END
            );
        END IF;
        
        order_count := order_count + 1;
    END LOOP;
    
    RETURN order_count;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION generate_test_orders(INTEGER, DATE, DATE) IS 
'Генерирует указанное количество тестовых заказов в указанном диапазоне дат';

-- =====================================================
-- 4. Хранимая процедура для оформления заказа
-- =====================================================

CREATE OR REPLACE FUNCTION create_order(
    p_customer_id INTEGER,
    p_shipping_address_id INTEGER,
    p_order_items JSONB
)
RETURNS INTEGER AS $$
DECLARE
    v_order_id INTEGER;
    v_total_amount DECIMAL(10, 2) := 0;
    v_item JSONB;
    v_product_id INTEGER;
    v_quantity INTEGER;
    v_price DECIMAL(10, 2);
    v_stock INTEGER;
BEGIN
    -- Проверка существования клиента
    IF NOT EXISTS (SELECT 1 FROM customers WHERE customer_id = p_customer_id) THEN
        RAISE EXCEPTION 'Клиент с ID % не найден', p_customer_id;
    END IF;
    
    -- Проверка существования адреса
    IF NOT EXISTS (SELECT 1 FROM addresses WHERE address_id = p_shipping_address_id AND customer_id = p_customer_id) THEN
        RAISE EXCEPTION 'Адрес с ID % не найден для клиента %', p_shipping_address_id, p_customer_id;
    END IF;
    
    -- Расчет общей суммы и проверка наличия товаров
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_order_items)
    LOOP
        v_product_id := (v_item->>'product_id')::INTEGER;
        v_quantity := (v_item->>'quantity')::INTEGER;
        
        -- Проверка существования товара
        SELECT price, stock_quantity INTO v_price, v_stock
        FROM products
        WHERE product_id = v_product_id;
        
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Товар с ID % не найден', v_product_id;
        END IF;
        
        -- Проверка наличия товара на складе
        IF v_stock < v_quantity THEN
            RAISE EXCEPTION 'Недостаточно товара % на складе. Доступно: %, запрошено: %', 
                v_product_id, v_stock, v_quantity;
        END IF;
        
        v_total_amount := v_total_amount + (v_price * v_quantity);
    END LOOP;
    
    -- Создание заказа
    INSERT INTO orders (customer_id, order_date, total_amount, status, shipping_address_id)
    VALUES (p_customer_id, CURRENT_DATE, v_total_amount, 'pending', p_shipping_address_id)
    RETURNING order_id INTO v_order_id;
    
    -- Добавление позиций заказа и обновление остатков
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_order_items)
    LOOP
        v_product_id := (v_item->>'product_id')::INTEGER;
        v_quantity := (v_item->>'quantity')::INTEGER;
        
        SELECT price INTO v_price
        FROM products
        WHERE product_id = v_product_id;
        
        -- Добавление позиции заказа
        INSERT INTO order_items (order_id, product_id, quantity, unit_price)
        VALUES (v_order_id, v_product_id, v_quantity, v_price);
        
        -- Обновление остатков (будет выполнено триггером, но можно и здесь)
        UPDATE products
        SET stock_quantity = stock_quantity - v_quantity
        WHERE product_id = v_product_id;
    END LOOP;
    
    RETURN v_order_id;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION create_order(INTEGER, INTEGER, JSONB) IS 
'Создает новый заказ с проверкой наличия товаров и обновлением остатков';

-- =====================================================
-- 5. Триггеры для автоматического обновления остатков
-- =====================================================

-- Функция триггера для проверки остатков при добавлении позиции заказа
CREATE OR REPLACE FUNCTION check_stock_quantity()
RETURNS TRIGGER AS $$
DECLARE
    v_stock INTEGER;
BEGIN
    SELECT stock_quantity INTO v_stock
    FROM products
    WHERE product_id = NEW.product_id;
    
    IF v_stock < NEW.quantity THEN
        RAISE EXCEPTION 'Недостаточно товара на складе. Доступно: %, запрошено: %', 
            v_stock, NEW.quantity;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Триггер перед вставкой позиции заказа
DROP TRIGGER IF EXISTS trigger_check_stock_before_insert ON order_items;
CREATE TRIGGER trigger_check_stock_before_insert
BEFORE INSERT ON order_items
FOR EACH ROW
EXECUTE FUNCTION check_stock_quantity();

-- Функция триггера для автоматического обновления остатков
CREATE OR REPLACE FUNCTION update_stock_on_order()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        -- Уменьшение остатков при добавлении позиции заказа
        UPDATE products
        SET stock_quantity = stock_quantity - NEW.quantity
        WHERE product_id = NEW.product_id;
        
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        -- Увеличение остатков при удалении позиции заказа
        UPDATE products
        SET stock_quantity = stock_quantity + OLD.quantity
        WHERE product_id = OLD.product_id;
        
        RETURN OLD;
    ELSIF TG_OP = 'UPDATE' THEN
        -- Обновление остатков при изменении количества
        UPDATE products
        SET stock_quantity = stock_quantity + OLD.quantity - NEW.quantity
        WHERE product_id = NEW.product_id;
        
        RETURN NEW;
    END IF;
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Триггер для автоматического обновления остатков
DROP TRIGGER IF EXISTS trigger_update_stock ON order_items;
CREATE TRIGGER trigger_update_stock
AFTER INSERT OR UPDATE OR DELETE ON order_items
FOR EACH ROW
EXECUTE FUNCTION update_stock_on_order();

-- Функция триггера для автоматического пересчета общей суммы заказа
CREATE OR REPLACE FUNCTION update_order_total()
RETURNS TRIGGER AS $$
DECLARE
    v_total DECIMAL(10, 2);
BEGIN
    IF TG_OP = 'DELETE' THEN
        -- Пересчет при удалении позиции
        SELECT COALESCE(SUM(quantity * unit_price), 0) INTO v_total
        FROM order_items
        WHERE order_id = OLD.order_id;
        
        UPDATE orders
        SET total_amount = v_total
        WHERE order_id = OLD.order_id;
        
        RETURN OLD;
    ELSE
        -- Пересчет при добавлении или обновлении позиции
        SELECT COALESCE(SUM(quantity * unit_price), 0) INTO v_total
        FROM order_items
        WHERE order_id = NEW.order_id;
        
        UPDATE orders
        SET total_amount = v_total
        WHERE order_id = NEW.order_id;
        
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Триггер для автоматического пересчета общей суммы заказа
DROP TRIGGER IF EXISTS trigger_update_order_total ON order_items;
CREATE TRIGGER trigger_update_order_total
AFTER INSERT OR UPDATE OR DELETE ON order_items
FOR EACH ROW
EXECUTE FUNCTION update_order_total();

-- =====================================================
-- 6. Функции для расчета рейтингов
-- =====================================================

-- Функция для расчета среднего рейтинга товара
CREATE OR REPLACE FUNCTION get_product_rating(p_product_id INTEGER)
RETURNS DECIMAL(3, 2) AS $$
DECLARE
    v_rating DECIMAL(3, 2);
BEGIN
    SELECT COALESCE(ROUND(AVG(rating), 2), 0) INTO v_rating
    FROM reviews
    WHERE product_id = p_product_id;
    
    RETURN v_rating;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_product_rating(INTEGER) IS 
'Возвращает средний рейтинг товара по отзывам';

-- Функция для расчета рейтинга поставщика
CREATE OR REPLACE FUNCTION get_supplier_rating(p_supplier_id INTEGER)
RETURNS DECIMAL(3, 2) AS $$
DECLARE
    v_rating DECIMAL(3, 2);
BEGIN
    SELECT COALESCE(ROUND(AVG(r.rating), 2), 0) INTO v_rating
    FROM reviews r
    INNER JOIN products p ON r.product_id = p.product_id
    WHERE p.supplier_id = p_supplier_id;
    
    RETURN v_rating;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_supplier_rating(INTEGER) IS 
'Возвращает средний рейтинг товаров поставщика';

-- =====================================================
-- 7. Анализ планов выполнения запросов (примеры)
-- =====================================================

-- Функция для анализа производительности запроса
CREATE OR REPLACE FUNCTION analyze_query_performance(query_text TEXT)
RETURNS TABLE (
    plan_type TEXT,
    plan_content TEXT
) AS $$
BEGIN
    RETURN QUERY
    EXECUTE 'EXPLAIN (FORMAT JSON, ANALYZE, BUFFERS) ' || query_text;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 8. Дополнительные оптимизации
-- =====================================================

-- Обновление статистики для оптимизатора
ANALYZE categories;
ANALYZE brands;
ANALYZE suppliers;
ANALYZE products;
ANALYZE customers;
ANALYZE addresses;
ANALYZE orders;
ANALYZE order_items;
ANALYZE deliveries;
ANALYZE reviews;

-- =====================================================
-- 9. Примеры использования функций
-- =====================================================

-- Пример вызова функции генерации тестовых заказов:
-- SELECT generate_test_orders(1000, '2024-01-01'::DATE, '2024-12-31'::DATE);

-- Пример вызова функции создания заказа:
-- SELECT create_order(
--     1, -- customer_id
--     1, -- shipping_address_id
--     '[
--         {"product_id": 1, "quantity": 2},
--         {"product_id": 6, "quantity": 1}
--     ]'::jsonb
-- );

-- Пример получения рейтинга товара:
-- SELECT get_product_rating(1);

-- Пример получения рейтинга поставщика:
-- SELECT get_supplier_rating(1);

-- =====================================================
-- Конец скрипта оптимизации
-- =====================================================

