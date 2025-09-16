            1. Khách hàng & hồ sơ vay
-- Số KH đang vay:
SELECT COUNT(DISTINCT customer_id) AS active_borrowers
FROM bank_loan_accounts
WHERE status <> 'closed'
-- Tuổi trung bình của khách hàng vay personal loan và mortgage loan
SELECT 
    b.loan_type,
    AVG(DATEDIFF(YEAR, a.dob, GETDATE())) AS avg_age
FROM bank_customers a
JOIN bank_loan_accounts b
     ON a.customer_id = b.customer_id
WHERE b.loan_type IN ('personal', 'mortgage')
  AND b.status <> 'closed'
GROUP BY b.loan_type
-- Khách hàng vay nhiều khoản nhất, tổng dư nợ bao nhiêu?
SELECT TOP 1
    a.customer_id,
    a.full_name,
    COUNT(b.loan_id) AS loan_count,
    SUM(b.loan_amount) AS total_outstanding
FROM bank_customers a
JOIN bank_loan_accounts b
     ON a.customer_id = b.customer_id
WHERE b.status <> 'closed'
GROUP BY a.customer_id, a.full_name
ORDER BY loan_count DESC, total_outstanding DESC;

