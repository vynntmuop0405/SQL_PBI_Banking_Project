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
WITH loan_repayment_status AS (
    SELECT 
        loan_id,
        MAX(CAST(is_late AS INT)) AS has_late  -- ép BIT -> INT
    FROM bank_repayments
    GROUP BY loan_id
)
SELECT 
    CAST(SUM(CASE WHEN has_late = 0 THEN 1 ELSE 0 END) * 100.0 
         / COUNT(*) AS DECIMAL(5,2)) AS pct_on_time_loans
FROM loan_repayment_status
-- Tỷ lệ khoản vay bị trễ hạn ≥ 1 lần trong quá trình trả?
WITH loan_repayment_status AS (
    SELECT 
        loan_id,
        MAX(CAST(is_late AS INT)) AS has_late
    FROM bank_repayments
    GROUP BY loan_id
)
SELECT 
    CAST(SUM(CASE WHEN has_late = 1 THEN 1 ELSE 0 END) * 100.0 
         / COUNT(*) AS DECIMAL(5,2)) AS pct_loans_with_late
FROM loan_repayment_status
-- Khách hàng nào có nhiều lần trễ hạn nhất? Tổng tiền phạt đã nộp bao nhiêu?
SELECT TOP 1
    a.customer_id,
    a.full_name,
    COUNT(c.repayment_id) AS late_count,
    ISNULL(SUM(d.penalty_amount), 0) AS total_penalty_paid
FROM bank_customers a
JOIN bank_loan_accounts b 
     ON a.customer_id = b.customer_id
JOIN bank_repayments c 
     ON b.loan_id = c.loan_id
LEFT JOIN bank_penalties d 
     ON c.repayment_id = d.repayment_id
WHERE c.is_late = 1
GROUP BY a.customer_id, a.full_name
ORDER BY late_count DESC, total_penalty_paid DESC
-- Trung bình thời gian trễ hạn (days late) là bao nhiêu?
SELECT 
    AVG(DATEDIFF(DAY, b.due_date, a.repayment_date)) AS avg_days_late
FROM bank_repayments a
JOIN bank_loan_schedule b 
     ON a.loan_id = b.loan_id 
    AND a.repayment_date >= b.due_date
WHERE a.is_late = 1

             5. PHÍ PHẠT VÀ TẤT TOÁN TRƯỚC HẠN
-- Tổng số tiền phạt thu được trong 12 tháng qua là bao nhiêu?
WITH penalty_last_12_months AS (
    SELECT 
        amount
    FROM bank_transactions
    WHERE transaction_type = 'penalty'
      AND transaction_date >= DATEADD(MONTH, -12, CAST(GETDATE() AS DATE))
)
SELECT SUM(amount) AS total_penalty_last_12_months
FROM penalty_last_12_months
-- Trong nhóm khách hàng tất toán trước hạn: trung bình họ đã trả được bao nhiêu % gốc trước khi tất toán?
WITH early_closed_loans AS (
    SELECT 
        a.loan_id,
        a.loan_amount,
        SUM(b.repayment_amount) AS total_principal_paid
    FROM bank_loan_accounts a
    JOIN bank_repayments b 
         ON a.loan_id = b.loan_id
    WHERE a.status = 'prepaid'
    GROUP BY a.loan_id, a.loan_amount
)
SELECT 
    AVG(CAST(total_principal_paid AS DECIMAL(18,2)) 
        / loan_amount * 100) AS avg_pct_principal_repaid
FROM early_closed_loans


