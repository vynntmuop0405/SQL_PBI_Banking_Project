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

            6. RỦI RO & NỢ XẤU
-- Tỷ lệ dư nợ quá hạn trên 30 ngày so với tổng dư nợ
WITH total_outstanding AS (
    SELECT SUM(loan_amount) AS total_loan
    FROM bank_loan_accounts
    WHERE status IN ('active','overdue')
),
overdue_30d AS (
    SELECT SUM(loan_amount) AS overdue_loan
    FROM bank_loan_accounts 
    WHERE status = 'overdue'
      AND DATEDIFF(DAY, due_date, GETDATE()) > 30
)
SELECT 
    CAST(a.overdue_loan AS DECIMAL(18,2)) / b.total_loan * 100 AS pct_overdue_30d
FROM overdue_30d a
CROSS JOIN total_outstanding b
-- Phân tích nợ xấu theo nhóm tuổi khách hàng (ví dụ <30, 30–50, >50).
WITH customer_age AS (
    SELECT 
        c.customer_id,
        DATEDIFF(YEAR, c.dob, GETDATE()) AS age
    FROM bank_customers c
),
loan_with_age AS (
    SELECT 
        l.loan_id,
        l.loan_amount,
        l.status,
        ca.age
    FROM bank_loan_accounts l
    JOIN customer_age ca ON l.customer_id = ca.customer_id
)
SELECT 
    CASE 
        WHEN age < 30 THEN '<30'
        WHEN age BETWEEN 30 AND 50 THEN '30-50'
        ELSE '>50'
    END AS age_group,
    SUM(CASE WHEN status = 'overdue' THEN loan_amount ELSE 0 END) AS overdue_amount,
    SUM(loan_amount) AS total_amount,
    CAST(SUM(CASE WHEN status = 'overdue' THEN loan_amount ELSE 0 END) * 100.0 
         / SUM(loan_amount) AS DECIMAL(5,2)) AS pct_overdue
FROM loan_with_age
GROUP BY CASE 
             WHEN age < 30 THEN '<30'
             WHEN age BETWEEN 30 AND 50 THEN '30-50'
             ELSE '>50'
         END
-- Nhóm loan_type nào có tỷ lệ quá hạn cao nhất?
SELECT 
    loan_type,
    SUM(CASE WHEN status = 'overdue' THEN loan_amount ELSE 0 END) AS overdue_amount,
    SUM(loan_amount) AS total_amount,
    CAST(SUM(CASE WHEN status = 'overdue' THEN loan_amount ELSE 0 END) * 100.0 
         / SUM(loan_amount) AS DECIMAL(5,2)) AS pct_overdue
FROM bank_loan_accounts
GROUP BY loan_type
ORDER BY 4 DESC

            4. HIỆU QUẢ TÀI CHÍNH (BANKING KPI)
-- Thu nhập lãi ròng (Interest Income – Penalty Loss) theo từng tháng
WITH monthly_interest AS (
    SELECT 
        YEAR(transaction_date) AS year,
        MONTH(transaction_date) AS tran_date,
        SUM(amount) AS total_interest
    FROM bank_transactions
    WHERE transaction_type = 'interest'
    GROUP BY YEAR(transaction_date), MONTH(transaction_date)
),
monthly_penalty AS (
    SELECT 
        YEAR(applied_date) AS year,
        MONTH(applied_date) AS tran_date,
        SUM(penalty_amount) AS total_penalty
    FROM bank_penalties
    GROUP BY YEAR(applied_date), MONTH(applied_date)
)
SELECT 
    a.year,
    a.tran_date,
    a.total_interest - ISNULL(b.total_penalty,0) AS net_interest_income
FROM monthly_interest a
LEFT JOIN monthly_penalty b
       ON a.year = b.year AND a.tran_date = b.tran_date
ORDER BY a.year, a.tran_date
-- Tỷ suất lợi nhuận từ lãi vay (%) theo từng loại khoản vay
WITH loan_interest AS (
    SELECT 
        a.loan_type,
        SUM(b.amount) AS total_interest
    FROM bank_loan_accounts a
    JOIN bank_transactions b 
         ON a.loan_id = b.loan_id
    WHERE b.transaction_type = 'interest'
    GROUP BY a.loan_type
),
loan_principal AS (
    SELECT 
        loan_type,
        SUM(loan_amount) AS total_principal
    FROM bank_loan_accounts
    GROUP BY loan_type
)
SELECT 
    a.loan_type,
    a.total_interest,
    b.total_principal,
    CAST(a.total_interest * 100.0 / b.total_principal AS DECIMAL(5,2)) AS profit_margin_pct
FROM loan_interest a
JOIN loan_principal b ON a.loan_type = b.loan_type
-- Top 5 khách hàng mang lại nhiều lợi nhuận nhất
WITH customer_interest AS (
    SELECT 
        a.customer_id,
        a.full_name,
        SUM(c.amount) AS total_interest
    FROM bank_customers a
    JOIN bank_loan_accounts b ON a.customer_id = b.customer_id
    JOIN bank_transactions c ON b.loan_id = c.loan_id
    WHERE c.transaction_type = 'interest'
    GROUP BY a.customer_id, a.full_name
),
customer_penalty AS (
    SELECT 
        a.customer_id,
        SUM(c.penalty_amount) AS total_penalty
    FROM bank_customers a
    JOIN bank_loan_accounts b ON a.customer_id = b.customer_id
    JOIN bank_penalties c ON b.loan_id = c.loan_id
    GROUP BY a.customer_id
)
SELECT TOP 5 
    a.customer_id,
    a.full_name,
    a.total_interest - ISNULL(b.total_penalty,0) AS net_profit
FROM customer_interest a
LEFT JOIN customer_penalty b ON a.customer_id = b.customer_id
ORDER BY net_profit DESC
-- Nếu ngân hàng giảm 1% lãi suất cho toàn bộ khoản vay mortgage loan, doanh thu lãi giảm bao nhiêu %
WITH mortgage_interest AS (
    SELECT SUM(b.amount) AS total_interest
    FROM bank_loan_accounts a
    JOIN bank_transactions b ON a.loan_id = b.loan_id
    WHERE a.loan_type = 'mortgage'
      AND b.transaction_type = 'interest'
),
mortgage_principal AS (
    SELECT SUM(loan_amount) AS total_principal
    FROM loan_accounts
    WHERE loan_type = 'mortgage'
)
SELECT 
    a.total_interest,
    b.total_principal * 0.01 AS estimated_interest_loss,
    CAST((b.total_principal * 0.01) * 100.0 / a.total_interest AS DECIMAL(5,2)) AS pct_loss
FROM mortgage_interest a
CROSS JOIN mortgage_principal b


