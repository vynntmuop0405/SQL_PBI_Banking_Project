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
ORDER BY loan_count DESC, total_outstanding DESC

                2. Dư nợ & dòng tiền
-- Tổng dư nợ gốc của toàn bộ hệ thống tại ngày hiện tại
SELECT SUM(loan_amount) AS total_outstanding_principal
FROM bank_loan_accounts 
WHERE status <> 'closed'
-- Phân bổ dư nợ theo loan_type (personal, mortgage, business)
SELECT 
    loan_type,
    SUM(loan_amount) AS total_outstanding_principal
FROM bank_loan_accounts
WHERE status <> 'closed'
GROUP BY loan_type
-- Top 10 khách hàng dư nợ lớn nhất
SELECT TOP 10
    a.customer_id,
    a.full_name,
    SUM(b.loan_amount) AS total_outstanding_principal
FROM bank_customers a
JOIN bank_loan_accounts b
     ON a.customer_id = b.customer_id
WHERE b.status <> 'closed'
GROUP BY a.customer_id, a.full_name
ORDER BY total_outstanding_principal DESC

            3. Lãi vay
-- Tổng lãi thu được trong năm 2024
SELECT SUM(amount) AS total_interest_2024
FROM bank_transactions
WHERE transaction_type = 'interest'
  AND YEAR(transaction_date) = 2024
-- Loan nào mang lại lãi suất cao nhất cho ngân hàng?
SELECT TOP 1
    loan_id,
    interest_rate
FROM bank_loan_accounts
ORDER BY interest_rate DESC
-- Trung bình lãi phải trả mỗi tháng của khách hàng vay personal loan
WITH monthly_interest_cte AS (
    SELECT 
        a.customer_id,
        a.full_name,
        YEAR(c.transaction_date) AS txn_year,
        MONTH(c.transaction_date) AS txn_month,
        AVG(c.amount) AS monthly_interest
    FROM bank_customers a
    JOIN bank_loan_accounts b
         ON a.customer_id = b.customer_id
    JOIN bank_transactions c
         ON b.loan_id = c.loan_id
    WHERE b.loan_type = 'personal'
      AND c.transaction_type = 'interest'
    GROUP BY a.customer_id, a.full_name, YEAR(c.transaction_date), MONTH(c.transaction_date)
)
SELECT 
    AVG(monthly_interest) AS avg_monthly_interest_personal
FROM monthly_interest_cte

            4. Trả nợ & hành vi khách hàng
-- Bao nhiêu % khoản vay được trả đúng hạn?
