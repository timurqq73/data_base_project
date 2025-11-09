-- =====================================================
-- Проект: База данных интернет-магазина "ProteinPower"
-- Скрипт: Сложные аналитические запросы
-- Описание: Аналитические запросы для бизнес-отчетности
-- =====================================================

-- =====================================================
-- Запрос 1: Финансовый отчет по брендам
-- Суммарная выручка по каждому бренду за последний месяц
-- =====================================================

SELECT 
    b.name AS brand_name,
    b.country AS brand_country,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    SUM(oi.quantity) AS total_products_sold,
    SUM(oi.quantity * oi.unit_price) AS total_revenue,
    ROUND(AVG(oi.unit_price), 2) AS average_price,
    MIN(oi.unit_price) AS min_price,
    MAX(oi.unit_price) AS max_price
FROM 
    brands b
    INNER JOIN products p ON b.brand_id = p.brand_id
    INNER JOIN order_items oi ON p.product_id = oi.product_id
    INNER JOIN orders o ON oi.order_id = o.order_id
WHERE 
    o.order_date >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '1 month')
    AND o.order_date < DATE_TRUNC('month', CURRENT_DATE)
    AND o.status != 'cancelled'
GROUP BY 
    b.brand_id, b.name, b.country
ORDER BY 
    total_revenue DESC;

-- =====================================================
-- Запрос 2: Топ-5 самых продаваемых товаров
-- Рейтинг товаров по количеству проданных единиц
-- =====================================================

SELECT 
    p.product_id,
    p.name AS product_name,
    b.name AS brand_name,
    c.name AS category_name,
    SUM(oi.quantity) AS total_quantity_sold,
    COUNT(DISTINCT oi.order_id) AS number_of_orders,
    SUM(oi.quantity * oi.unit_price) AS total_revenue,
    ROUND(AVG(oi.unit_price), 2) AS average_sale_price,
    COALESCE(ROUND(AVG(r.rating), 2), 0) AS average_rating,
    COUNT(r.review_id) AS number_of_reviews
FROM 
    products p
    INNER JOIN brands b ON p.brand_id = b.brand_id
    INNER JOIN categories c ON p.category_id = c.category_id
    INNER JOIN order_items oi ON p.product_id = oi.product_id
    INNER JOIN orders o ON oi.order_id = o.order_id
    LEFT JOIN reviews r ON p.product_id = r.product_id
WHERE 
    o.status != 'cancelled'
GROUP BY 
    p.product_id, p.name, b.name, c.name
ORDER BY 
    total_quantity_sold DESC
LIMIT 5;

-- =====================================================
-- Запрос 3: VIP-клиенты
-- Клиенты с общей суммой заказов > 5000 руб.
-- =====================================================

SELECT 
    c.customer_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    c.email,
    c.phone,
    c.registration_date,
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(o.total_amount) AS total_spent,
    ROUND(AVG(o.total_amount), 2) AS average_order_amount,
    MAX(o.order_date) AS last_order_date,
    MIN(o.order_date) AS first_order_date,
    COUNT(DISTINCT oi.product_id) AS unique_products_purchased,
    COUNT(DISTINCT a.city) AS cities_delivered
FROM 
    customers c
    INNER JOIN orders o ON c.customer_id = o.customer_id
    INNER JOIN order_items oi ON o.order_id = oi.order_id
    INNER JOIN addresses a ON o.shipping_address_id = a.address_id
WHERE 
    o.status != 'cancelled'
GROUP BY 
    c.customer_id, c.first_name, c.last_name, c.email, c.phone, c.registration_date
HAVING 
    SUM(o.total_amount) > 5000
ORDER BY 
    total_spent DESC;

-- =====================================================
-- Запрос 4: Анализ поставщиков
-- Поставщики, чьи товары имеют средний рейтинг < 4.0
-- =====================================================

SELECT 
    s.supplier_id,
    s.company_name,
    s.contact_person,
    s.email,
    s.phone,
    COUNT(DISTINCT p.product_id) AS total_products,
    SUM(p.stock_quantity) AS total_stock,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    SUM(oi.quantity) AS total_products_sold,
    SUM(oi.quantity * oi.unit_price) AS total_revenue,
    COALESCE(ROUND(AVG(r.rating), 2), 0) AS average_rating,
    COUNT(r.review_id) AS number_of_reviews,
    CASE 
        WHEN COALESCE(AVG(r.rating), 0) < 4.0 THEN 'Требует внимания'
        WHEN COALESCE(AVG(r.rating), 0) >= 4.5 THEN 'Отлично'
        ELSE 'Хорошо'
    END AS rating_status
FROM 
    suppliers s
    INNER JOIN products p ON s.supplier_id = p.supplier_id
    LEFT JOIN order_items oi ON p.product_id = oi.product_id
    LEFT JOIN orders o ON oi.order_id = o.order_id AND o.status != 'cancelled'
    LEFT JOIN reviews r ON p.product_id = r.product_id
GROUP BY 
    s.supplier_id, s.company_name, s.contact_person, s.email, s.phone
HAVING 
    COALESCE(AVG(r.rating), 0) < 4.0 OR COUNT(r.review_id) = 0
ORDER BY 
    average_rating ASC, total_products DESC;

-- =====================================================
-- Запрос 5: Анализ продаж по категориям
-- Детальный отчет по продажам в разрезе категорий
-- =====================================================

SELECT 
    c.category_id,
    c.name AS category_name,
    COUNT(DISTINCT p.product_id) AS products_in_category,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    SUM(oi.quantity) AS total_quantity_sold,
    SUM(oi.quantity * oi.unit_price) AS total_revenue,
    ROUND(SUM(oi.quantity * oi.unit_price) / NULLIF(SUM(oi.quantity), 0), 2) AS average_price_per_unit,
    ROUND(AVG(r.rating), 2) AS average_rating,
    SUM(p.stock_quantity) AS total_stock_quantity,
    ROUND(
        (SUM(oi.quantity)::NUMERIC / NULLIF(SUM(p.stock_quantity + oi.quantity), 0)) * 100, 
        2
    ) AS sales_to_stock_ratio
FROM 
    categories c
    INNER JOIN products p ON c.category_id = p.category_id
    LEFT JOIN order_items oi ON p.product_id = oi.product_id
    LEFT JOIN orders o ON oi.order_id = o.order_id AND o.status != 'cancelled'
    LEFT JOIN reviews r ON p.product_id = r.product_id
GROUP BY 
    c.category_id, c.name
ORDER BY 
    total_revenue DESC;

-- =====================================================
-- Запрос 6: Анализ доставок
-- Статистика по доставкам по службам доставки
-- =====================================================

SELECT 
    d.carrier AS delivery_service,
    COUNT(d.delivery_id) AS total_deliveries,
    COUNT(CASE WHEN d.actual_delivery_date IS NOT NULL THEN 1 END) AS completed_deliveries,
    COUNT(CASE WHEN d.actual_delivery_date IS NULL THEN 1 END) AS pending_deliveries,
    COUNT(CASE WHEN d.actual_delivery_date <= d.delivery_date THEN 1 END) AS on_time_deliveries,
    COUNT(CASE WHEN d.actual_delivery_date > d.delivery_date THEN 1 END) AS late_deliveries,
    ROUND(
        AVG(CASE 
            WHEN d.actual_delivery_date IS NOT NULL 
            THEN EXTRACT(EPOCH FROM (d.actual_delivery_date - d.delivery_date)) / 86400
            ELSE NULL 
        END), 
        2
    ) AS average_delay_days,
    ROUND(
        (COUNT(CASE WHEN d.actual_delivery_date IS NOT NULL THEN 1 END)::NUMERIC / 
         NULLIF(COUNT(d.delivery_id), 0)) * 100, 
        2
    ) AS completion_rate_percent,
    ROUND(
        (COUNT(CASE WHEN d.actual_delivery_date <= d.delivery_date THEN 1 END)::NUMERIC / 
         NULLIF(COUNT(CASE WHEN d.actual_delivery_date IS NOT NULL THEN 1 END), 0)) * 100, 
        2
    ) AS on_time_rate_percent
FROM 
    deliveries d
GROUP BY 
    d.carrier
ORDER BY 
    total_deliveries DESC;

-- =====================================================
-- Запрос 7: Динамика продаж по месяцам
-- Анализ продаж по месяцам с разбивкой по статусам заказов
-- =====================================================

SELECT 
    DATE_TRUNC('month', o.order_date) AS month,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(DISTINCT o.customer_id) AS unique_customers,
    SUM(o.total_amount) AS total_revenue,
    ROUND(AVG(o.total_amount), 2) AS average_order_amount,
    COUNT(DISTINCT CASE WHEN o.status = 'delivered' THEN o.order_id END) AS delivered_orders,
    COUNT(DISTINCT CASE WHEN o.status = 'shipped' THEN o.order_id END) AS shipped_orders,
    COUNT(DISTINCT CASE WHEN o.status = 'processing' THEN o.order_id END) AS processing_orders,
    COUNT(DISTINCT CASE WHEN o.status = 'pending' THEN o.order_id END) AS pending_orders,
    COUNT(DISTINCT CASE WHEN o.status = 'cancelled' THEN o.order_id END) AS cancelled_orders,
    SUM(CASE WHEN o.status = 'delivered' THEN o.total_amount ELSE 0 END) AS delivered_revenue
FROM 
    orders o
GROUP BY 
    DATE_TRUNC('month', o.order_date)
ORDER BY 
    month DESC;

-- =====================================================
-- Запрос 8: Товары с низким остатком на складе
-- Товары, требующие пополнения запасов
-- =====================================================

SELECT 
    p.product_id,
    p.name AS product_name,
    b.name AS brand_name,
    c.name AS category_name,
    p.stock_quantity,
    p.price,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    SUM(oi.quantity) AS total_sold,
    ROUND(AVG(oi.quantity), 2) AS average_order_quantity,
    COALESCE(ROUND(AVG(r.rating), 2), 0) AS average_rating,
    CASE 
        WHEN p.stock_quantity = 0 THEN 'Нет в наличии'
        WHEN p.stock_quantity < 10 THEN 'Критический остаток'
        WHEN p.stock_quantity < 30 THEN 'Низкий остаток'
        ELSE 'В норме'
    END AS stock_status,
    s.company_name AS supplier_name
FROM 
    products p
    INNER JOIN brands b ON p.brand_id = b.brand_id
    INNER JOIN categories c ON p.category_id = c.category_id
    INNER JOIN suppliers s ON p.supplier_id = s.supplier_id
    LEFT JOIN order_items oi ON p.product_id = oi.product_id
    LEFT JOIN orders o ON oi.order_id = o.order_id AND o.status != 'cancelled'
    LEFT JOIN reviews r ON p.product_id = r.product_id
GROUP BY 
    p.product_id, p.name, b.name, c.name, p.stock_quantity, p.price, s.company_name
HAVING 
    p.stock_quantity < 50
ORDER BY 
    p.stock_quantity ASC, total_sold DESC;

-- =====================================================
-- Конец скрипта сложных запросов
-- =====================================================

