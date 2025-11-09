-- =====================================================
-- Проект: База данных интернет-магазина "ProteinPower"
-- Скрипт: Представления и материализованные представления
-- Описание: Создание представлений для упрощения работы с данными
-- =====================================================

-- Удаление существующих представлений (если есть)
DROP MATERIALIZED VIEW IF EXISTS monthly_sales_report_mv CASCADE;
DROP VIEW IF EXISTS monthly_sales_report CASCADE;
DROP VIEW IF EXISTS customer_order_history CASCADE;
DROP VIEW IF EXISTS product_ratings_summary CASCADE;
DROP VIEW IF EXISTS supplier_performance CASCADE;

-- =====================================================
-- Представление 1: monthly_sales_report
-- Ежемесячный отчет по продажам
-- =====================================================

CREATE VIEW monthly_sales_report AS
SELECT 
    DATE_TRUNC('month', o.order_date) AS month,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(DISTINCT o.customer_id) AS unique_customers,
    COUNT(DISTINCT oi.product_id) AS unique_products_sold,
    SUM(oi.quantity) AS total_products_sold,
    SUM(o.total_amount) AS total_revenue,
    ROUND(AVG(o.total_amount), 2) AS average_order_amount,
    SUM(CASE WHEN o.status = 'delivered' THEN o.total_amount ELSE 0 END) AS delivered_revenue,
    SUM(CASE WHEN o.status = 'delivered' THEN 1 ELSE 0 END) AS delivered_orders,
    SUM(CASE WHEN o.status = 'cancelled' THEN o.total_amount ELSE 0 END) AS cancelled_revenue,
    SUM(CASE WHEN o.status = 'cancelled' THEN 1 ELSE 0 END) AS cancelled_orders,
    ROUND(
        (SUM(CASE WHEN o.status = 'delivered' THEN o.total_amount ELSE 0 END)::NUMERIC / 
         NULLIF(SUM(o.total_amount), 0)) * 100, 
        2
    ) AS delivery_rate_percent
FROM 
    orders o
    LEFT JOIN order_items oi ON o.order_id = oi.order_id
WHERE 
    o.status != 'cancelled' OR o.status = 'cancelled'
GROUP BY 
    DATE_TRUNC('month', o.order_date)
ORDER BY 
    month DESC;

COMMENT ON VIEW monthly_sales_report IS 'Ежемесячный отчет по продажам с детальной статистикой';

-- =====================================================
-- Представление 2: customer_order_history
-- История заказов клиентов
-- =====================================================

CREATE VIEW customer_order_history AS
SELECT 
    c.customer_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    c.email,
    c.phone,
    c.registration_date,
    o.order_id,
    o.order_date,
    o.total_amount,
    o.status,
    COUNT(oi.order_item_id) AS items_count,
    SUM(oi.quantity) AS total_items_quantity,
    STRING_AGG(DISTINCT p.name, ', ' ORDER BY p.name) AS products_list,
    a.city AS delivery_city,
    a.street || ', ' || a.house_number || 
        CASE WHEN a.apartment IS NOT NULL THEN ', кв. ' || a.apartment ELSE '' END AS delivery_address,
    d.delivery_date,
    d.actual_delivery_date,
    d.carrier,
    d.tracking_number,
    CASE 
        WHEN d.actual_delivery_date IS NOT NULL AND d.actual_delivery_date <= d.delivery_date THEN 'В срок'
        WHEN d.actual_delivery_date IS NOT NULL AND d.actual_delivery_date > d.delivery_date THEN 'С опозданием'
        WHEN d.actual_delivery_date IS NULL AND d.delivery_date < CURRENT_DATE THEN 'Просрочена'
        ELSE 'В процессе'
    END AS delivery_status
FROM 
    customers c
    INNER JOIN orders o ON c.customer_id = o.customer_id
    LEFT JOIN order_items oi ON o.order_id = oi.order_id
    LEFT JOIN products p ON oi.product_id = p.product_id
    LEFT JOIN addresses a ON o.shipping_address_id = a.address_id
    LEFT JOIN deliveries d ON o.order_id = d.order_id
GROUP BY 
    c.customer_id, c.first_name, c.last_name, c.email, c.phone, c.registration_date,
    o.order_id, o.order_date, o.total_amount, o.status,
    a.city, a.street, a.house_number, a.apartment,
    d.delivery_date, d.actual_delivery_date, d.carrier, d.tracking_number
ORDER BY 
    c.customer_id, o.order_date DESC;

COMMENT ON VIEW customer_order_history IS 'Полная история заказов клиентов с деталями доставки';

-- =====================================================
-- Представление 3: product_ratings_summary
-- Сводка по рейтингам товаров
-- =====================================================

CREATE VIEW product_ratings_summary AS
SELECT 
    p.product_id,
    p.name AS product_name,
    b.name AS brand_name,
    c.name AS category_name,
    p.price,
    p.stock_quantity,
    COUNT(r.review_id) AS total_reviews,
    ROUND(AVG(r.rating), 2) AS average_rating,
    COUNT(CASE WHEN r.rating = 5 THEN 1 END) AS five_star_reviews,
    COUNT(CASE WHEN r.rating = 4 THEN 1 END) AS four_star_reviews,
    COUNT(CASE WHEN r.rating = 3 THEN 1 END) AS three_star_reviews,
    COUNT(CASE WHEN r.rating = 2 THEN 1 END) AS two_star_reviews,
    COUNT(CASE WHEN r.rating = 1 THEN 1 END) AS one_star_reviews,
    ROUND(
        (COUNT(CASE WHEN r.rating >= 4 THEN 1 END)::NUMERIC / 
         NULLIF(COUNT(r.review_id), 0)) * 100, 
        2
    ) AS positive_reviews_percent,
    MIN(r.created_at) AS first_review_date,
    MAX(r.created_at) AS last_review_date,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    SUM(oi.quantity) AS total_sold,
    CASE 
        WHEN COUNT(r.review_id) = 0 THEN 'Нет отзывов'
        WHEN AVG(r.rating) >= 4.5 THEN 'Отлично'
        WHEN AVG(r.rating) >= 4.0 THEN 'Хорошо'
        WHEN AVG(r.rating) >= 3.0 THEN 'Удовлетворительно'
        ELSE 'Требует улучшения'
    END AS rating_category
FROM 
    products p
    INNER JOIN brands b ON p.brand_id = b.brand_id
    INNER JOIN categories c ON p.category_id = c.category_id
    LEFT JOIN reviews r ON p.product_id = r.product_id
    LEFT JOIN order_items oi ON p.product_id = oi.product_id
    LEFT JOIN orders o ON oi.order_id = o.order_id AND o.status != 'cancelled'
GROUP BY 
    p.product_id, p.name, b.name, c.name, p.price, p.stock_quantity
ORDER BY 
    average_rating DESC NULLS LAST, total_reviews DESC;

COMMENT ON VIEW product_ratings_summary IS 'Сводная информация по рейтингам и отзывам товаров';

-- =====================================================
-- Представление 4: supplier_performance
-- Эффективность работы поставщиков
-- =====================================================

CREATE VIEW supplier_performance AS
SELECT 
    s.supplier_id,
    s.company_name,
    s.contact_person,
    s.email,
    s.phone,
    COUNT(DISTINCT p.product_id) AS total_products,
    SUM(p.stock_quantity) AS total_stock_quantity,
    SUM(p.stock_quantity * p.price) AS total_stock_value,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    SUM(oi.quantity) AS total_products_sold,
    SUM(oi.quantity * oi.unit_price) AS total_revenue,
    ROUND(AVG(oi.unit_price), 2) AS average_sale_price,
    ROUND(
        (SUM(oi.quantity)::NUMERIC / 
         NULLIF(SUM(p.stock_quantity + oi.quantity), 0)) * 100, 
        2
    ) AS sales_turnover_rate,
    COALESCE(ROUND(AVG(r.rating), 2), 0) AS average_product_rating,
    COUNT(r.review_id) AS total_reviews,
    COUNT(DISTINCT b.brand_id) AS brands_represented,
    COUNT(DISTINCT c.category_id) AS categories_represented,
    MIN(o.order_date) AS first_order_date,
    MAX(o.order_date) AS last_order_date,
    CASE 
        WHEN COALESCE(AVG(r.rating), 0) >= 4.5 AND SUM(oi.quantity) > 100 THEN 'Отличный'
        WHEN COALESCE(AVG(r.rating), 0) >= 4.0 AND SUM(oi.quantity) > 50 THEN 'Хороший'
        WHEN COALESCE(AVG(r.rating), 0) < 3.5 OR SUM(oi.quantity) < 10 THEN 'Требует внимания'
        ELSE 'Средний'
    END AS performance_category
FROM 
    suppliers s
    INNER JOIN products p ON s.supplier_id = p.supplier_id
    INNER JOIN brands b ON p.brand_id = b.brand_id
    INNER JOIN categories c ON p.category_id = c.category_id
    LEFT JOIN order_items oi ON p.product_id = oi.product_id
    LEFT JOIN orders o ON oi.order_id = o.order_id AND o.status != 'cancelled'
    LEFT JOIN reviews r ON p.product_id = r.product_id
GROUP BY 
    s.supplier_id, s.company_name, s.contact_person, s.email, s.phone
ORDER BY 
    total_revenue DESC, average_product_rating DESC;

COMMENT ON VIEW supplier_performance IS 'Анализ эффективности работы поставщиков';

-- =====================================================
-- Материализованное представление: monthly_sales_report_mv
-- Ежемесячный отчет по продажам (материализованное)
-- Используется для быстрого доступа к агрегированным данным
-- =====================================================

CREATE MATERIALIZED VIEW monthly_sales_report_mv AS
SELECT 
    DATE_TRUNC('month', o.order_date) AS month,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(DISTINCT o.customer_id) AS unique_customers,
    COUNT(DISTINCT oi.product_id) AS unique_products_sold,
    SUM(oi.quantity) AS total_products_sold,
    SUM(o.total_amount) AS total_revenue,
    ROUND(AVG(o.total_amount), 2) AS average_order_amount,
    SUM(CASE WHEN o.status = 'delivered' THEN o.total_amount ELSE 0 END) AS delivered_revenue,
    SUM(CASE WHEN o.status = 'delivered' THEN 1 ELSE 0 END) AS delivered_orders,
    SUM(CASE WHEN o.status = 'cancelled' THEN o.total_amount ELSE 0 END) AS cancelled_revenue,
    SUM(CASE WHEN o.status = 'cancelled' THEN 1 ELSE 0 END) AS cancelled_orders,
    ROUND(
        (SUM(CASE WHEN o.status = 'delivered' THEN o.total_amount ELSE 0 END)::NUMERIC / 
         NULLIF(SUM(o.total_amount), 0)) * 100, 
        2
    ) AS delivery_rate_percent
FROM 
    orders o
    LEFT JOIN order_items oi ON o.order_id = oi.order_id
WHERE 
    o.status != 'cancelled' OR o.status = 'cancelled'
GROUP BY 
    DATE_TRUNC('month', o.order_date);

-- Создание индекса для материализованного представления
CREATE UNIQUE INDEX ON monthly_sales_report_mv (month);

COMMENT ON MATERIALIZED VIEW monthly_sales_report_mv IS 'Материализованное представление ежемесячного отчета по продажам для быстрого доступа';

-- =====================================================
-- Функция для обновления материализованного представления
-- =====================================================

CREATE OR REPLACE FUNCTION refresh_monthly_sales_report()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY monthly_sales_report_mv;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION refresh_monthly_sales_report() IS 'Функция для обновления материализованного представления monthly_sales_report_mv';

-- =====================================================
-- Дополнительные полезные представления
-- =====================================================

-- Представление: Текущие заказы в обработке
CREATE VIEW active_orders AS
SELECT 
    o.order_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    c.email AS customer_email,
    o.order_date,
    o.total_amount,
    o.status,
    a.city || ', ' || a.street || ', ' || a.house_number AS delivery_address,
    d.carrier,
    d.delivery_date,
    d.tracking_number,
    COUNT(oi.order_item_id) AS items_count
FROM 
    orders o
    INNER JOIN customers c ON o.customer_id = c.customer_id
    INNER JOIN addresses a ON o.shipping_address_id = a.address_id
    LEFT JOIN deliveries d ON o.order_id = d.order_id
    LEFT JOIN order_items oi ON o.order_id = oi.order_id
WHERE 
    o.status IN ('pending', 'processing', 'shipped')
GROUP BY 
    o.order_id, c.first_name, c.last_name, c.email, o.order_date, 
    o.total_amount, o.status, a.city, a.street, a.house_number,
    d.carrier, d.delivery_date, d.tracking_number
ORDER BY 
    o.order_date DESC;

COMMENT ON VIEW active_orders IS 'Активные заказы в процессе обработки и доставки';

-- Представление: Топ товаров по продажам
CREATE VIEW top_selling_products AS
SELECT 
    p.product_id,
    p.name AS product_name,
    b.name AS brand_name,
    c.name AS category_name,
    p.price,
    SUM(oi.quantity) AS total_sold,
    COUNT(DISTINCT oi.order_id) AS order_count,
    SUM(oi.quantity * oi.unit_price) AS total_revenue,
    ROUND(AVG(r.rating), 2) AS average_rating,
    p.stock_quantity,
    CASE 
        WHEN p.stock_quantity < 10 THEN TRUE 
        ELSE FALSE 
    END AS low_stock
FROM 
    products p
    INNER JOIN brands b ON p.brand_id = b.brand_id
    INNER JOIN categories c ON p.category_id = c.category_id
    LEFT JOIN order_items oi ON p.product_id = oi.product_id
    LEFT JOIN orders o ON oi.order_id = o.order_id AND o.status != 'cancelled'
    LEFT JOIN reviews r ON p.product_id = r.product_id
GROUP BY 
    p.product_id, p.name, b.name, c.name, p.price, p.stock_quantity
HAVING 
    SUM(oi.quantity) > 0 OR SUM(oi.quantity) IS NULL
ORDER BY 
    total_sold DESC NULLS LAST
LIMIT 20;

COMMENT ON VIEW top_selling_products IS 'Топ-20 самых продаваемых товаров';

-- =====================================================
-- Конец скрипта представлений
-- =====================================================

